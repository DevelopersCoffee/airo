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
    for key in ["AIRO_LLAMA_MODEL", "AIRO_MIND_LLAMA_MODEL"] {
        if let Ok(value) = std::env::var(key) {
            if !value.trim().is_empty() {
                return PathBuf::from(value);
            }
        }
    }
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
                grammar: None,
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
            grammar: None,
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
            grammar: None,
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

/// `#1628` Wave 1 acceptance: a GBNF grammar actually constrains the token
/// stream, not just compiles. A digits-only grammar is deliberately much
/// stricter than the model's natural continuation of a numeric prompt would
/// be on its own -- if the grammar were a no-op, the model would drift into
/// prose almost immediately.
#[test]
fn a_gbnf_grammar_constrains_every_generated_character() {
    let model = model();
    if !model.exists() {
        eprintln!("skipping: no model at {}", model.display());
        return;
    }

    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_generation(Box::new(engine));

    // `root` is the symbol name `LlamaGenerationEngine::generate` requires --
    // one or more ASCII digits, nothing else. A general-knowledge question
    // has no natural all-digit answer, so any conforming output here was
    // shaped by the grammar, not by the model happening to agree with it.
    //
    // This does NOT prove the grammar forces a minimum length: llama.cpp's
    // grammar sampler deliberately lets the model's own end-of-generation
    // token through even mid-grammar (confirmed empirically -- an earlier,
    // stricter version of this test requiring exactly 8 digits produced only
    // 4 before stopping), so "how much output" stays the model's call.
    // "What character set the output uses" is what the grammar owns, and
    // that is what this asserts.
    const PROMPT: &str = "<|im_start|>user\nWhat is the capital of France?<|im_end|>\n\
                           <|im_start|>assistant\n";
    let digits_only_grammar = r#"root ::= [0-9]+"#;

    let mut unconstrained = String::new();
    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: PROMPT.to_string(),
                max_output_tokens: 24,
                grammar: None,
            },
            &CancelToken::new(),
            &mut |chunk| {
                unconstrained.push_str(&chunk.text);
                Ok(())
            },
        )
        .expect("unconstrained generation succeeds");
    eprintln!("--- unconstrained output ---\n{unconstrained:?}\n---");
    assert!(
        unconstrained.chars().any(|c| !c.is_ascii_digit()),
        "test prompt needs a genuinely non-numeric natural answer to be a \
         meaningful baseline -- got {unconstrained:?}"
    );

    let mut output = String::new();
    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: PROMPT.to_string(),
                max_output_tokens: 24,
                grammar: Some(digits_only_grammar.to_string()),
            },
            &CancelToken::new(),
            &mut |chunk| {
                output.push_str(&chunk.text);
                Ok(())
            },
        )
        .expect("grammar-constrained generation succeeds");
    eprintln!("--- grammar-constrained output ---\n{output:?}\n---");

    assert!(
        !output.is_empty(),
        "the grammar-constrained call produced no output at all"
    );
    assert!(
        output.chars().all(|c| c.is_ascii_digit()),
        "grammar did not constrain the output -- got {output:?}"
    );
}

/// `#1628` Wave 1 acceptance: an invalid grammar is a normal `InvalidInput`
/// refusal, not a panic -- the same shape every other malformed-request path
/// in this engine already uses.
#[test]
fn a_grammar_missing_its_root_rule_is_refused_not_a_panic() {
    let model = model();
    if !model.exists() {
        return;
    }

    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_generation(Box::new(engine));

    let r = supervisor.run_generation(
        &GenerationRequest {
            prompt: "hello".into(),
            max_output_tokens: 8,
            // No `root` rule -- the grammar's own start symbol is missing.
            grammar: Some("digits ::= [0-9]+".into()),
        },
        &CancelToken::new(),
        &mut |_| Ok(()),
    );

    assert!(matches!(
        r,
        Err(RuntimeError::Engine(
            airo_mind_llama::EngineError::InvalidInput(_)
        ))
    ));
}

/// `#1628` Wave 1 acceptance: `RuntimeStats` reports real, non-zero
/// measurements after a real generation call -- not hardcoded placeholders.
#[test]
fn runtime_stats_are_real_after_a_generation_call() {
    let model = model();
    if !model.exists() {
        eprintln!("skipping: no model at {}", model.display());
        return;
    }

    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_generation(Box::new(engine));

    assert_eq!(
        supervisor.generation_stats(),
        Some(airo_mind_llama::RuntimeStats::default()),
        "nothing has generated yet -- stats must read as the zero state, not garbage"
    );

    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: minutes_prompt(TRANSCRIPT),
                max_output_tokens: 64,
                grammar: None,
            },
            &CancelToken::new(),
            &mut |_| Ok(()),
        )
        .expect("generation succeeds");

    let stats = supervisor
        .generation_stats()
        .expect("a generation engine is registered");

    assert!(stats.prefill_tokens > 0, "prefill tokenised nothing?");
    assert!(stats.generated_tokens > 0, "generation produced no tokens?");
    // Timing on a real backend is never provably non-zero at millisecond
    // resolution (a fast enough call could round to 0ms), but tokens/sec is
    // derived FROM those timings and generated_tokens, so a non-zero rate is
    // the strongest single proof that real instrumentation ran, not a
    // hardcoded stand-in.
    assert!(
        stats.tokens_per_second > 0.0,
        "tokens/sec was not computed from a real measurement: {stats:?}"
    );
    assert!(
        stats.peak_rss_bytes > 0,
        "peak RSS was not read from the process"
    );

    eprintln!("--- runtime stats ---\n{stats:?}\n---");
}

/// **The `#1739` regression test.** A grammar with a terminal state used to
/// abort the whole OS process one token past completion:
///
/// ```text
/// llama-grammar.cpp:940: GGML_ASSERT(!stacks.empty()) failed
/// ```
///
/// `root ::= "{" "}"` is the minimal reproduction — the crash landed on the
/// token immediately after the closing brace, every time, because generation
/// only stopped on EOG or `max_output_tokens` and both are checked *after*
/// sampling. `#1628`'s `[0-9]+` grammar never caught it: it has no terminal
/// state, so there is always a "one more digit" continuation and the stacks
/// never empty.
///
/// `max_output_tokens` is deliberately far higher than the grammar can consume.
/// If the driver did not stop at the terminal state, the run would reach the
/// assert long before the ceiling, and this test would not fail — it would take
/// the test binary down with `SIGABRT`. Surviving to the assertions IS the
/// result being asserted.
///
/// Skipped without a model, like every test in this file. That means CI does
/// not prove this; a dev-loop or device run with a real GGUF does.
#[test]
fn a_grammar_that_can_finish_does_not_abort_the_process() {
    let model = model();
    if !model.exists() {
        eprintln!("skipping: no model at {}", model.display());
        return;
    }

    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_generation(Box::new(engine));

    let mut output = String::new();
    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: "<|im_start|>user\nEmit an empty JSON object.<|im_end|>\n\
                         <|im_start|>assistant\n"
                    .to_string(),
                max_output_tokens: 64,
                grammar: Some(r#"root ::= "{" "}""#.to_string()),
            },
            &CancelToken::new(),
            &mut |chunk| {
                output.push_str(&chunk.text);
                Ok(())
            },
        )
        .expect("a terminating grammar generates and returns");

    assert_eq!(
        output.trim(),
        "{}",
        "the grammar admits exactly one string, and generation must stop at it"
    );
}

/// `#1628` Wave 1 acceptance: `unload()` exists, is callable, and does not
/// panic or leak.
#[test]
fn unload_is_callable_and_does_not_panic() {
    let model = model();
    if !model.exists() {
        return;
    }
    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    engine.unload();
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
