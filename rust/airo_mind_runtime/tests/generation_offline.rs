//! `#1398` acceptance: transcript → minutes, offline.
//!
//! Also the first end-to-end proof: audio → transcript → minutes, all on
//! device, when both features are on.

#![cfg(feature = "llama")]

use std::path::PathBuf;

use airo_mind_runtime::{
    CancelToken, GenerationRequest, LlamaGenerationEngine, ResourceBudget, RuntimeError, Supervisor,
};

fn model() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("models/qwen2.5-0.5b-instruct-q4_k_m.gguf")
}

/// The prompt a Meeting capability would build. It lives in the TEST, not in
/// the engine — the runtime knows no domains, so meeting vocabulary must not
/// appear below the capability boundary.
fn minutes_prompt(transcript: &str) -> String {
    format!(
        "<|im_start|>system\nYou are a meeting secretary. Extract Decisions and Action Items. \
         Return Markdown only. Do not invent facts.<|im_end|>\n\
         <|im_start|>user\nTranscript:\n{transcript}<|im_end|>\n\
         <|im_start|>assistant\n"
    )
}

const TRANSCRIPT: &str = "Priya said the Kafka consumer lag is the bottleneck, not the database. \
We agreed to add three more pods before Friday. Raj will own the rollout and report back Monday.";

/// **The `#1398` exit criterion.** Transcript in, minutes out, on device.
#[test]
fn transcript_becomes_minutes_offline() {
    let model = model();
    if !model.exists() {
        eprintln!("skipping: no model at {}", model.display());
        return;
    }

    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_generation(Box::new(engine));

    // Chunks arrive as produced. Collecting is the TEST's choice; the runtime
    // never accumulates (`I7`).
    let mut minutes = String::new();
    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: minutes_prompt(TRANSCRIPT),
                max_output_tokens: 160,
            },
            &CancelToken::new(),
            &mut |chunk| {
                minutes.push_str(&chunk.text);
                Ok(())
            },
        )
        .expect("generation succeeds");

    assert!(!minutes.trim().is_empty(), "produced no minutes");

    // Asserting the output is GROUNDED in the transcript, not merely non-empty.
    // A model returning boilerplate would otherwise pass.
    let lower = minutes.to_lowercase();
    assert!(
        lower.contains("kafka") || lower.contains("pod") || lower.contains("raj"),
        "minutes are not grounded in the transcript: {minutes}"
    );

    eprintln!("--- generated minutes ---\n{minutes}\n---");
}

/// Cancellation reaches the real backend. Generation is the long half of the
/// pipeline, so this is the case a user actually hits.
#[test]
fn a_cancelled_generation_stops_and_reports_it() {
    let model = model();
    if !model.exists() {
        return;
    }
    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_generation(Box::new(engine));

    let cancel = CancelToken::new();
    let mut produced = 0usize;

    let r = supervisor.run_generation(
        &GenerationRequest {
            prompt: minutes_prompt(TRANSCRIPT),
            max_output_tokens: 200,
        },
        &cancel,
        &mut |_| {
            produced += 1;
            // Stop after the first token: the user navigated away.
            cancel.cancel();
            Ok(())
        },
    );

    assert!(matches!(
        r,
        Err(RuntimeError::Engine(
            airo_mind_runtime::EngineError::Cancelled
        ))
    ));
    assert_eq!(produced, 1, "a cancelled job must stop at the next token");
}

/// Budget refusal reaches the real engine too: a 4 GB model on a 512 MB budget
/// never allocates.
#[test]
fn a_real_engine_over_budget_is_refused_before_it_runs() {
    let model = model();
    if !model.exists() {
        return;
    }
    let engine = LlamaGenerationEngine::load(&model, 4096, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(512));
    supervisor.register_generation(Box::new(engine));

    let mut called = false;
    let r = supervisor.run_generation(
        &GenerationRequest {
            prompt: minutes_prompt(TRANSCRIPT),
            max_output_tokens: 32,
        },
        &CancelToken::new(),
        &mut |_| {
            called = true;
            Ok(())
        },
    );
    assert_eq!(
        r,
        Err(RuntimeError::OverBudget {
            needs_mb: 4096,
            budget_mb: 512
        })
    );
    assert!(!called, "refused before the engine produced anything");
}

/// **The whole pipeline, offline.** Audio → transcript → minutes.
///
/// This is the `#1397` + `#1398` join, and the first four steps of the
/// Milestone 2 user journey.
#[cfg(feature = "whisper")]
#[test]
fn audio_becomes_minutes_offline() {
    use airo_mind_runtime::{AudioInput, TranscriptSegment, WhisperSpeechEngine};

    let speech_model = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("models/ggml-tiny.en.bin");
    if !speech_model.exists() || !model().exists() {
        return;
    }

    // Minimal WAV read — duplicated from speech_offline.rs deliberately rather
    // than shared, because a test helper crate is not what moves the pipeline.
    let bytes =
        std::fs::read(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/jfk.wav"))
            .unwrap();
    let data_at = bytes
        .windows(4)
        .position(|w| w == b"data")
        .expect("wav has a data chunk")
        + 8;
    let samples: Vec<i16> = bytes[data_at..]
        .chunks_exact(2)
        .map(|p| i16::from_le_bytes([p[0], p[1]]))
        .collect();

    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_speech(Box::new(
        WhisperSpeechEngine::load(&speech_model, 512).unwrap(),
    ));
    supervisor.register_generation(Box::new(
        LlamaGenerationEngine::load(&model(), 1024, 2048).unwrap(),
    ));

    // Step 1: audio -> transcript.
    let mut segments: Vec<TranscriptSegment> = Vec::new();
    supervisor
        .run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &CancelToken::new(),
            &mut |s| {
                segments.push(s);
                Ok(())
            },
        )
        .expect("transcription succeeds");
    let transcript = segments
        .iter()
        .map(|s| s.text.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    assert!(!transcript.trim().is_empty());

    // Step 2: transcript -> minutes.
    let mut minutes = String::new();
    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: minutes_prompt(&transcript),
                max_output_tokens: 128,
            },
            &CancelToken::new(),
            &mut |c| {
                minutes.push_str(&c.text);
                Ok(())
            },
        )
        .expect("generation succeeds");

    assert!(!minutes.trim().is_empty(), "pipeline produced no minutes");
    eprintln!("--- transcript ---\n{transcript}\n--- minutes ---\n{minutes}\n---");
}
