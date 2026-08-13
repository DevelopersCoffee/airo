//! macOS dev-loop smoke test for Airo Mind's two engines.
//!
//! `.m4a` in, timestamped transcript out (`airo_mind_whisper`), transcript in,
//! generated text out (`airo_mind_llama`) -- both engines running the exact
//! same `Supervisor` / `SpeechEngine` / `GenerationEngine` contract the app
//! consumes, both Metal-accelerated on this machine. See `README.md` in this
//! crate for how to re-run it.
//!
//! Not shipped product code. It is a fast local feedback loop for iterating on
//! `airo_mind_whisper` / `airo_mind_llama` before the Android/iOS app builds
//! pick the same libraries up -- see milestone 26, Wave 1 exit gate.

use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use airo_mind_core::wav;
use airo_mind_llama::{
    CancelToken as LlamaCancelToken, GenerationRequest, LlamaGenerationEngine,
    ResourceBudget as LlamaBudget, Supervisor as LlamaSupervisor,
};
use airo_mind_whisper::{
    AudioInput, CancelToken as WhisperCancelToken, ResourceBudget as WhisperBudget,
    Supervisor as WhisperSupervisor, TranscriptSegment, WhisperSpeechEngine,
};

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

/// `AIRO_MIND_CLI_AUDIO`, else the first CLI arg, else the repo's own
/// synthesized fixture (`rust/fixtures/speech.m4a` -- see this crate's
/// README for how it was made).
fn audio_path() -> PathBuf {
    if let Ok(p) = env::var("AIRO_MIND_CLI_AUDIO") {
        return PathBuf::from(p);
    }
    if let Some(arg) = env::args().nth(1) {
        return PathBuf::from(arg);
    }
    manifest_dir().join("../fixtures/speech.m4a")
}

/// `AIRO_MIND_WHISPER_MODEL`, else the path the crate's own `#1397` test
/// suite already uses (`rust/airo_mind_whisper/models/ggml-tiny.en.bin`).
fn whisper_model_path() -> PathBuf {
    env::var("AIRO_MIND_WHISPER_MODEL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| manifest_dir().join("../airo_mind_whisper/models/ggml-tiny.en.bin"))
}

/// `AIRO_MIND_LLAMA_MODEL`, else the path the crate's own `#1398` test suite
/// already uses (`rust/airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf`).
fn llama_model_path() -> PathBuf {
    env::var("AIRO_MIND_LLAMA_MODEL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            manifest_dir().join("../airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf")
        })
}

/// Decodes `input` (any container `afconvert` reads -- `.m4a` included) to a
/// 16 kHz mono 16-bit PCM WAVE file at `out`.
///
/// Shells out rather than adding an in-process AAC/MP4 decoder: this binary
/// runs on a developer's Mac only, never ships, and `afconvert` is already on
/// every machine that can build this workspace. A new decoding crate here
/// would need the same Constitution §6 dependency scorecard the engine crates
/// deliberately avoid for far less benefit -- see the comment on `wav.rs`.
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

/// The prompt sent to the LLM: a chat-formatted request to summarize the ASR
/// output. Prompt shape (`<|im_start|>` / `<|im_end|>`) matches Qwen2.5's
/// instruct chat template -- the same one `generation_offline.rs`'s
/// `minutes_prompt` uses for the same model family.
fn summarize_prompt(transcript: &str) -> String {
    format!(
        "<|im_start|>system\nYou are a concise assistant. Summarize the transcript in one \
         or two sentences.<|im_end|>\n\
         <|im_start|>user\nTranscript:\n{transcript}<|im_end|>\n\
         <|im_start|>assistant\n"
    )
}

fn main() {
    let audio = audio_path();
    let whisper_model = whisper_model_path();
    let llama_model = llama_model_path();

    println!("== Airo Mind macOS dev loop ==");
    println!("audio:         {}", audio.display());
    println!("whisper model: {}", whisper_model.display());
    println!("llama model:   {}", llama_model.display());
    println!(
        "acceleration:  compiled with `metal` feature on both engines (macOS Metal + CoreML \
         per Cargo.toml); watch stderr above for ggml's own \
         `whisper_backend_init_gpu` / `ggml_metal_init` load-time log lines to confirm the \
         runtime actually picked Metal up."
    );
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

    // --- ASR ------------------------------------------------------------
    println!("\n-- loading whisper.cpp (Metal) --");
    let t0 = Instant::now();
    let speech_engine =
        WhisperSpeechEngine::load(&whisper_model, 512).expect("whisper model loads");
    println!("whisper load: {:?}", t0.elapsed());

    let mut whisper_supervisor = WhisperSupervisor::new(WhisperBudget::new(2048));
    whisper_supervisor.register_speech(Box::new(speech_engine));

    let mut segments: Vec<TranscriptSegment> = Vec::new();
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
                segments.push(segment);
                Ok(())
            },
        )
        .expect("transcription succeeds");
    println!("whisper inference: {:?}", t0.elapsed());

    println!("\n-- transcript ({} segment(s)) --", segments.len());
    for s in &segments {
        println!(
            "[{} -> {}] {}",
            format_ts(s.start_ms),
            format_ts(s.end_ms),
            s.text
        );
    }

    let transcript = segments
        .iter()
        .map(|s| s.text.trim())
        .collect::<Vec<_>>()
        .join(" ");

    if transcript.trim().is_empty() {
        eprintln!("\nwhisper produced no text -- nothing to feed the LLM, stopping here.");
        std::process::exit(1);
    }

    // --- generation -------------------------------------------------------
    println!("\n-- loading llama.cpp (Metal) --");
    let t0 = Instant::now();
    let generation_engine =
        LlamaGenerationEngine::load(&llama_model, 1024, 2048).expect("llama model loads");
    println!("llama load: {:?}", t0.elapsed());

    let mut llama_supervisor = LlamaSupervisor::new(LlamaBudget::new(4096));
    llama_supervisor.register_generation(Box::new(generation_engine));

    println!("\n-- generation --");
    let t0 = Instant::now();
    let mut generated = String::new();
    llama_supervisor
        .run_generation(
            &GenerationRequest {
                prompt: summarize_prompt(&transcript),
                max_output_tokens: 160,
            },
            &LlamaCancelToken::new(),
            &mut |chunk| {
                print!("{}", chunk.text);
                use std::io::Write;
                let _ = std::io::stdout().flush();
                generated.push_str(&chunk.text);
                Ok(())
            },
        )
        .expect("generation succeeds");
    println!("\n\nllama inference: {:?}", t0.elapsed());

    println!("\n== done ==");
    println!("transcript chars: {}", transcript.len());
    println!("generated chars:  {}", generated.len());
}
