//! macOS dev-loop smoke test for Airo Mind's full Wave 2 pipeline.
//!
//! `.m4a` in, timestamped transcript out (`airo_mind_whisper`), transcript
//! through `#1632`'s preprocessing (`airo_mind_transcript`: raw/normalized
//! text + overlapping semantic chunks), each chunk through `#1633`'s pass 1
//! extraction (`airo_mind_extract`, real generation via `airo_mind_llama` --
//! see `ExtractionConfig::use_gbnf_grammar`'s doc comment for why this is
//! not grammar-constrained yet), all chunks through pass 2 consolidation --
//! one [`airo_mind_extract::MeetingIr`] out, printed as JSON. This is milestone
//! 26's POC-1 harness ("golden MoM reproduced from existing transcript",
//! `#1641`): every stage runs the exact `Supervisor` / `SpeechEngine` /
//! `LlmBackend` contract the app consumes, both engines Metal-accelerated on
//! this machine. See `README.md` in this crate for how to re-run it.
//!
//! Not shipped product code. It is a fast local feedback loop for iterating
//! on the pipeline crates before the Android/iOS app builds pick the same
//! libraries up -- see milestone 26, Wave 2 exit gate.

use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use airo_mind_core::wav;
use airo_mind_extract::{
    consolidate, extract_chunk_facts, ChunkFacts, ExtractionConfig, MeetingIr,
};
use airo_mind_llama::{CancelToken as LlamaCancelToken, LlamaGenerationEngine};
use airo_mind_transcript::{process, ChunkConfig, Segment};
use airo_mind_whisper::{
    AudioInput, CancelToken as WhisperCancelToken, ResourceBudget as WhisperBudget,
    Supervisor as WhisperSupervisor, TranscriptSegment, WhisperSpeechEngine,
};

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

/// `AIRO_MIND_CLI_AUDIO`, else the first CLI arg, else the repo's own
/// synthesized fixture (`rust/fixtures/meeting_synthetic.m4a` -- a ~8 minute
/// multi-speaker meeting, long enough to exercise `#1632`'s chunk
/// boundaries/overlap; see this crate's README for how it was made and how
/// it differs from the older, 9-second `speech.m4a`).
fn audio_path() -> PathBuf {
    if let Ok(p) = env::var("AIRO_MIND_CLI_AUDIO") {
        return PathBuf::from(p);
    }
    if let Some(arg) = env::args().nth(1) {
        return PathBuf::from(arg);
    }
    manifest_dir().join("../fixtures/meeting_synthetic.m4a")
}

fn whisper_model_path() -> PathBuf {
    env::var("AIRO_MIND_WHISPER_MODEL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| manifest_dir().join("../airo_mind_whisper/models/ggml-tiny.en.bin"))
}

fn llama_model_path() -> PathBuf {
    env::var("AIRO_MIND_LLAMA_MODEL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            manifest_dir().join("../airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf")
        })
}

/// Decodes `input` (any container `afconvert` reads -- `.m4a` included) to a
/// 16 kHz mono 16-bit PCM WAVE file at `out`. See `README.md`'s "Why
/// `afconvert`" for why this shells out instead of adding an in-process
/// AAC/MP4 decoder.
fn decode_to_wav16k_mono(input: &Path, out: &Path) -> Result<(), String> {
    let status = Command::new("afconvert")
        .args(["-f", "WAVE", "-d", "LEI16@16000", "-c", "1"])
        .arg(input)
        .arg(out)
        .status()
        .map_err(|e| {
            format!("couldn't run `afconvert` ({e}) -- this CLI is macOS-only, see README.md")
        })?;
    if !status.success() {
        return Err(format!("afconvert exited with {status}"));
    }
    Ok(())
}

fn format_ts(ms: u64) -> String {
    let total_secs = ms / 1000;
    format!(
        "{:02}:{:02}.{:03}",
        total_secs / 60,
        total_secs % 60,
        ms % 1000
    )
}

/// Chunk sizing for this dev loop's default fixture. Two things drove this
/// away from `#1632`'s own default (`ChunkConfig::default()`, 5-10 minute
/// chunks, what production is spec'd for and what that crate's own golden
/// tests exercise):
///
/// 1. The ~8-minute synthetic meeting fixture here is shorter than a 5-10
///    minute window, so the default would produce exactly one chunk and
///    never exercise the overlap/boundary path this milestone's POC-1 gate
///    cares about.
/// 2. Empirically, against the real pinned Qwen2.5-0.5B-Instruct model,
///    excerpts anywhere near the 5-10 minute / 50+ segment range make pass 1
///    extract nothing at all -- not wrong facts, no facts, every category
///    empty -- while a 5-10 segment excerpt reliably surfaces real facts.
///    This matches the milestone brief's own flagged risk ("sub-7B models
///    can't generate meaningful summaries from a 1h conversation, 4k ctx")
///    and is a genuine capability ceiling of this Wave 2 model choice, not a
///    bug in `#1632`'s chunker or `#1633`'s extraction logic. Scaled down
///    (60-100 second chunks, 15s overlap) keeps excerpts inside what this
///    specific model can actually attend to, so this dev loop demonstrates
///    the pipeline working rather than silently returning nothing.
///
/// A stronger on-device model (1-3B class) is the real fix for (2); see this
/// crate's PR/issue comment on `#1633` for the full account.
fn cli_chunk_config() -> ChunkConfig {
    ChunkConfig {
        min_len_ms: 60_000,
        max_len_ms: 100_000,
        overlap_ms: 15_000,
        pause_gap_ms: 400,
    }
}

fn print_facts_line(label: &str, id: &str, text: &str, evidence: &[String]) {
    println!("  [{id}] {label}: {text}");
    println!("        evidence: {}", evidence.join(", "));
}

fn print_meeting_ir(ir: &MeetingIr) {
    println!("\n== Meeting IR (schema {}) ==", ir.schema_version);
    println!(
        "chunks consolidated: {}, total facts: {}",
        ir.meeting.chunk_count,
        ir.fact_count()
    );

    for d in &ir.decisions {
        print_facts_line("decision", &d.id, &d.text, &d.evidence);
    }
    for a in &ir.action_items {
        println!(
            "  [{}] action item: {} (owner: {})",
            a.id,
            a.text,
            a.owner.as_deref().unwrap_or("<none stated>")
        );
        println!("        evidence: {}", a.evidence.join(", "));
    }
    for r in &ir.risks {
        print_facts_line("risk", &r.id, &r.text, &r.evidence);
    }
    for q in &ir.questions {
        print_facts_line("question", &q.id, &q.text, &q.evidence);
    }
    for m in &ir.metrics {
        print_facts_line("metric", &m.id, &m.text, &m.evidence);
    }
    for n in &ir.next_steps {
        print_facts_line("next step", &n.id, &n.text, &n.evidence);
    }
    for o in &ir.observations {
        print_facts_line("observation", &o.id, &o.text, &o.evidence);
    }
    for t in &ir.topics {
        print_facts_line("topic", &t.id, &t.text, &t.evidence);
    }
}

fn main() {
    let audio = audio_path();
    let whisper_model = whisper_model_path();
    let llama_model = llama_model_path();

    println!("== Airo Mind macOS dev loop: transcript -> Meeting IR (#1632 + #1633) ==");
    println!("audio:         {}", audio.display());
    println!("whisper model: {}", whisper_model.display());
    println!("llama model:   {}", llama_model.display());
    println!();

    if !audio.exists() {
        eprintln!("no audio at {} -- see README.md", audio.display());
        std::process::exit(1);
    }
    if !whisper_model.exists() {
        eprintln!(
            "no whisper model at {} -- see README.md for the download command",
            whisper_model.display()
        );
        std::process::exit(1);
    }
    if !llama_model.exists() {
        eprintln!(
            "no llama model at {} -- see README.md for the download command",
            llama_model.display()
        );
        std::process::exit(1);
    }

    // --- decode -------------------------------------------------------
    let tmp_wav = env::temp_dir().join(format!("airo_mind_cli_{}.wav", std::process::id()));
    if let Err(e) = decode_to_wav16k_mono(&audio, &tmp_wav) {
        eprintln!("decode failed: {e}");
        std::process::exit(1);
    }
    let wav_bytes = std::fs::read(&tmp_wav).expect("afconvert wrote a wav file");
    let _ = std::fs::remove_file(&tmp_wav);
    let pcm = wav::decode(&wav_bytes).expect("afconvert output is a valid 16-bit PCM WAVE file");
    println!(
        "decoded: {} samples @ {} Hz, {} channel(s)",
        pcm.samples.len(),
        pcm.sample_rate_hz,
        pcm.channels
    );

    // --- ASR (#1629) ------------------------------------------------------
    println!("\n-- loading whisper.cpp (Metal) --");
    let t0 = Instant::now();
    let speech_engine =
        WhisperSpeechEngine::load(&whisper_model, 512).expect("whisper model loads");
    println!("whisper load: {:?}", t0.elapsed());

    let mut whisper_supervisor = WhisperSupervisor::new(WhisperBudget::new(2048));
    whisper_supervisor.register_speech(Box::new(speech_engine));

    let mut raw_segments: Vec<TranscriptSegment> = Vec::new();
    let t0 = Instant::now();
    whisper_supervisor
        .run_speech(
            AudioInput {
                samples: &pcm.samples,
                sample_rate_hz: pcm.sample_rate_hz,
                channels: pcm.channels,
            },
            &WhisperCancelToken::new(),
            &mut |segment| {
                raw_segments.push(segment);
                Ok(())
            },
        )
        .expect("transcription succeeds");
    println!("whisper inference: {:?}", t0.elapsed());
    println!("\n-- transcript ({} segment(s)) --", raw_segments.len());

    // `"s{index}"`, scoped to this recording -- the same id scheme
    // `airo_mind_whisper::api::meetings::transcript_segment_record` assigns
    // in the real bridge, so this dev loop's ids mean the same thing a real
    // Dart-driven run's would.
    let segments: Vec<Segment> = raw_segments
        .iter()
        .enumerate()
        .map(|(i, s)| Segment {
            id: format!("s{i}"),
            start_ms: s.start_ms,
            end_ms: s.end_ms,
            text: s.text.trim().to_string(),
        })
        .collect();
    for s in &segments {
        println!(
            "[{} {} -> {}] {}",
            s.id,
            format_ts(s.start_ms),
            format_ts(s.end_ms),
            s.text
        );
    }

    if segments.is_empty() || segments.iter().all(|s| s.text.trim().is_empty()) {
        eprintln!("\nwhisper produced no text -- nothing to process, stopping here.");
        std::process::exit(1);
    }

    // --- preprocessing (#1632) --------------------------------------------
    println!("\n-- transcript processing (raw/normalized + chunking, #1632) --");
    let processed = process(&segments, &cli_chunk_config());
    println!(
        "{} segment(s) normalized into {} chunk(s)",
        processed.segments.len(),
        processed.chunks.len()
    );
    for c in &processed.chunks {
        println!(
            "  {} [{} -> {}], {} segment(s): {:?}",
            c.id,
            format_ts(c.start_ms),
            format_ts(c.end_ms),
            c.segment_ids.len(),
            c.segment_ids
        );
    }

    // --- extraction pass 1 + pass 2 (#1633) --------------------------------
    println!("\n-- loading llama.cpp (Metal) --");
    let t0 = Instant::now();
    let generation_engine =
        LlamaGenerationEngine::load(&llama_model, 1024, 4096).expect("llama model loads");
    println!("llama load: {:?}", t0.elapsed());

    // `extract_chunk_facts` takes `&dyn LlmBackend` directly rather than
    // going through a `Supervisor`: the Supervisor's admission path is
    // designed around one logical job per call (`C6`), and this loop makes
    // many chunk-level calls against one already-loaded, already-admitted
    // engine -- the same reasoning `airo_mind_extract`'s own doc comment
    // gives for depending on the trait, not a concrete `Supervisor`-wrapped
    // engine.
    let cancel = LlamaCancelToken::new();
    let extraction_config = ExtractionConfig::default();

    println!(
        "\n-- pass 1: per-chunk extraction ({} chunk(s)) --",
        processed.chunks.len()
    );
    let mut per_chunk_facts: Vec<ChunkFacts> = Vec::new();
    for c in &processed.chunks {
        let t0 = Instant::now();
        let facts = extract_chunk_facts(
            &generation_engine,
            c,
            &processed.segments,
            &extraction_config,
            &cancel,
        )
        .expect("pass 1 extraction does not hard-fail (cancellation aside)");
        println!(
            "  {}: {} fact(s) extracted in {:?}",
            c.id,
            facts.topics.len()
                + facts.observations.len()
                + facts.decisions.len()
                + facts.action_items.len()
                + facts.metrics.len()
                + facts.risks.len()
                + facts.questions.len()
                + facts.next_steps.len(),
            t0.elapsed()
        );
        per_chunk_facts.push(facts);
    }

    println!("\n-- pass 2: consolidation --");
    let ir = consolidate(per_chunk_facts, None);
    print_meeting_ir(&ir);

    let known_ids: std::collections::HashSet<String> =
        processed.segments.iter().map(|s| s.id.clone()).collect();
    println!(
        "\nall evidence grounded to known segment ids: {}",
        ir.all_evidence_is_grounded(&known_ids)
    );

    let json = serde_json::to_string_pretty(&ir).expect("MeetingIr serializes");
    let out_path = env::temp_dir().join("airo_mind_cli_meeting_ir.json");
    std::fs::write(&out_path, &json).expect("writes meeting_ir.json");
    println!("\nfull Meeting IR JSON written to {}", out_path.display());

    println!("\n== done ==");
}
