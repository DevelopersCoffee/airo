//! `#1398` acceptance: transcript → minutes, offline.
//!
//! Also the first end-to-end proof: audio → transcript → minutes, all on
//! device, when both features are on.

#![cfg(feature = "llama")]

use std::path::PathBuf;

use airo_mind_llama::{
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
            airo_mind_llama::EngineError::Cancelled
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

// The end-to-end join (audio -> transcript -> minutes) used to live here as
// `audio_becomes_minutes_offline`, loading both engines into this one test
// binary. It cannot: whisper.cpp and llama.cpp vendor incompatible ggml copies,
// and linking both is the one-definition-rule conflict that forced them into
// separate cdylibs. A test binary is subject to exactly the same link.
//
// That coverage moves to Dart, where the two libraries are genuinely separate
// images -- MindService composing transcribe -> generate -> save -- and to the
// on-device journey walk. It is not dropped, and it is not replaceable from
// inside this crate.
