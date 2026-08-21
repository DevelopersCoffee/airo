//! Host smoke: `ReasoningEngine` over a real `LlamaGenerationEngine`.
//!
//! Skipped unless a GGUF is present — default
//! `models/qwen2.5-0.5b-instruct-q4_k_m.gguf`, or `AIRO_LLAMA_MODEL` /
//! `AIRO_MIND_LLAMA_MODEL`. Same skip rule as `generation_offline.rs`.
//! CI without weights must stay green.

#![cfg(feature = "llama")]

use std::path::PathBuf;

use airo_mind_core::CancelToken;
use airo_mind_llama::LlamaGenerationEngine;
use airo_mind_reasoning::{
    ReasoningEngine, ReasoningError, ReasoningEvent, ReasoningLevel, ReasoningRequest,
    ReasoningStage,
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

#[test]
fn reason_over_a_real_gguf_does_not_emit_a_thought_trace() {
    let model = model();
    if !model.exists() {
        eprintln!(
            "skipping: no model at {} (set AIRO_LLAMA_MODEL)",
            model.display()
        );
        return;
    }

    let engine = LlamaGenerationEngine::load(&model, 1024, 2048).expect("model loads");
    let mut request = ReasoningRequest::fixture("planning", 0.6);
    request.user_query = "Reply with the weekday name Tuesday.".into();
    request.requested_level = Some(ReasoningLevel::Light);

    let mut events = Vec::new();
    let outcome = ReasoningEngine::default().reason(
        &engine,
        &request,
        &CancelToken::new(),
        &mut |event| {
            events.push(event);
            Ok(())
        },
    );

    match outcome {
        Ok(()) => {
            assert!(matches!(events.first(), Some(ReasoningEvent::Started)));
            assert!(events.iter().any(|e| matches!(
                e,
                ReasoningEvent::StageChanged {
                    stage: ReasoningStage::ComposingAnswer
                }
            )));
            match events.last() {
                Some(ReasoningEvent::Completed { result }) => {
                    let lower = result.answer.to_ascii_lowercase();
                    assert!(
                        !lower.contains("thoughts") && !lower.contains("scratchpad"),
                        "answer must not carry a thought dump: {}",
                        result.answer
                    );
                    assert!(
                        !result.answer.trim().is_empty() || !result.tool_calls.is_empty(),
                        "completed envelope had neither an answer nor a tool call"
                    );
                    eprintln!("--- reasoning answer ---\n{}\n---", result.answer);
                }
                other => panic!("expected Completed, got {other:?}"),
            }
        }
        Err(ReasoningError::InvalidModelOutput) => {
            assert!(
                events.iter().any(|e| matches!(
                    e,
                    ReasoningEvent::StageChanged {
                        stage: ReasoningStage::Validating
                    }
                )),
                "grammar must compile and generate before validation; events={events:?}"
            );
            eprintln!(
                "tiny GGUF produced an envelope the validator rejected; stack still ran without a panic"
            );
        }
        Err(err) => panic!("unexpected reasoning error: {err:?}"),
    }
}
