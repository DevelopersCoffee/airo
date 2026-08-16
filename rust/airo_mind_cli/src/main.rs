//! Dev-loop smoke test and POC-2 offline pipeline for Airo Mind.
//!
//! Without `--out`: legacy ASR → one-line LLM summary (Wave 1 dev loop).
//! With `--out`: preprocess → whisper → transcript::process → extract →
//! validate → generate_mom → `airo_mind_eval` gates. See `README.md`.

mod args;
mod eval_run;
mod pipeline;

use std::io::Write;
use std::time::Instant;

use airo_mind_audio::preprocess_path;
use airo_mind_llama::{
    CancelToken as LlamaCancelToken, GenerationRequest, LlamaGenerationEngine,
    ResourceBudget as LlamaBudget, Supervisor as LlamaSupervisor,
};
use airo_mind_whisper::{
    AudioInput, CancelToken as WhisperCancelToken, ResourceBudget as WhisperBudget,
    Supervisor as WhisperSupervisor, TranscriptSegment, TranscriptionOptions, WhisperSpeechEngine,
};

use args::{parse, print_help, resolve_llama_model, resolve_whisper_model, CliArgs};
use pipeline::{run_poc2, write_artifacts};

fn format_ts(ms: u64) -> String {
    let total_secs = ms / 1000;
    format!(
        "{:02}:{:02}.{:03}",
        total_secs / 60,
        total_secs % 60,
        ms % 1000
    )
}

fn summarize_prompt(transcript: &str) -> String {
    format!(
        "<|im_start|>system\nYou are a concise assistant. Summarize the transcript in one \
         or two sentences.<|im_end|>\n\
         <|im_start|>user\nTranscript:\n{transcript}<|im_end|>\n\
         <|im_start|>assistant\n"
    )
}

fn validate_models(
    audio: &std::path::Path,
    whisper_model: &std::path::Path,
    llama_model: &std::path::Path,
) {
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
}

fn run_legacy(args: &CliArgs, whisper_model: &std::path::Path, llama_model: &std::path::Path) {
    println!("== Airo Mind dev loop ==");
    println!("audio:         {}", args.audio.display());
    println!("whisper model: {}", whisper_model.display());
    println!("llama model:   {}", llama_model.display());
    println!();

    let pcm = match preprocess_path(&args.audio) {
        Ok(pcm) => pcm,
        Err(e) => {
            eprintln!("decode failed: {e}");
            std::process::exit(1);
        }
    };
    println!(
        "decoded: {} samples @ {} Hz, {} channel(s)",
        pcm.samples.len(),
        pcm.sample_rate_hz,
        pcm.channels
    );

    println!("\n-- loading whisper.cpp (Metal) --");
    let t0 = Instant::now();
    let speech_engine = WhisperSpeechEngine::load(whisper_model, 512).expect("whisper model loads");
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
            &TranscriptionOptions::default(),
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

    println!("\n-- loading llama.cpp (Metal) --");
    let t0 = Instant::now();
    let generation_engine =
        LlamaGenerationEngine::load(llama_model, 1024, 2048).expect("llama model loads");
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
                grammar: None,
            },
            &LlamaCancelToken::new(),
            &mut |chunk| {
                print!("{}", chunk.text);
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

fn run_poc2_mode(args: &CliArgs, whisper_model: &std::path::Path, llama_model: &std::path::Path) {
    let out_dir = args.out.as_ref().expect("--out required for poc2 mode");

    println!("== Airo Mind POC-2 pipeline ==");
    println!("audio:         {}", args.audio.display());
    println!("whisper model: {}", whisper_model.display());
    println!("llama model:   {}", llama_model.display());
    println!("out:           {}", out_dir.display());
    println!();

    let output = run_poc2(args, whisper_model, llama_model);
    write_artifacts(out_dir, args, &output);

    println!("wrote {}/transcript.json", out_dir.display());
    println!("wrote {}/chunks.json", out_dir.display());
    println!("wrote {}/meeting_ir.json", out_dir.display());
    println!("wrote {}/predicted_ir.json", out_dir.display());
    println!("wrote {}/mom.md", out_dir.display());
    println!("wrote {}/hypothesis_transcript.txt", out_dir.display());
    println!("pipeline: {} ms", output.processing_ms);

    if args.skip_eval {
        println!("\n== done (eval skipped) ==");
        return;
    }

    let eval = eval_run::run_eval(args, out_dir, &output);
    println!("wrote {}", eval.report_path.display());

    if eval.passed {
        println!("\nall gates passed");
        std::process::exit(0);
    } else {
        println!("\nGATE FAILURE");
        std::process::exit(1);
    }
}

fn main() {
    let args = parse();
    if args.help {
        print_help();
        return;
    }

    let whisper_model = resolve_whisper_model(args.models_dir.as_ref());
    let llama_model = resolve_llama_model(args.models_dir.as_ref());
    validate_models(&args.audio, &whisper_model, &llama_model);

    if args.out.is_some() {
        run_poc2_mode(&args, &whisper_model, &llama_model);
    } else {
        run_legacy(&args, &whisper_model, &llama_model);
    }
}
