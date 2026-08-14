//! `#1633` end-to-end proof: a real transcript chunk, through the real
//! `LlamaGenerationEngine` (`airo_mind_llama`, real model, real Metal-backed
//! inference -- not mocked), through pass 1 + pass 2, produces a
//! [`airo_mind_extract::MeetingIr`] with grounded evidence. Same pattern as
//! `airo_mind_llama`'s own `tests/generation_offline.rs`: gated on the
//! `llama` feature, needs the real GGUF model on disk (see this repo's
//! `rust/airo_mind_cli/README.md` for how to fetch it), and is not part of
//! the default `cargo test` run for exactly that reason.

#![cfg(feature = "llama")]

use std::path::PathBuf;

use airo_mind_core::CancelToken;
use airo_mind_extract::{consolidate, extract_chunk_facts, ExtractionConfig};
use airo_mind_llama::LlamaGenerationEngine;
use airo_mind_transcript::{process, ChunkConfig, Segment};

fn model() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf")
}

/// A short excerpt built from the same worked example the milestone brief
/// (`#1627`) and this crate's own doc comments use throughout: Kafka
/// consumer lag as the root cause, a pod-scaling decision, Raj owning the
/// rollout. One chunk is enough to prove the wiring end to end; the fuller
/// multi-chunk, multi-minute proof (including chunk-boundary dedup) is the
/// macOS CLI's job (`rust/airo_mind_cli`) against a real ~8 minute synthetic
/// meeting recording, not this crate's own test suite.
fn transcript_segments() -> Vec<Segment> {
    let lines = [
        "Raj said the Kafka consumer lag is the bottleneck, not the database.",
        "We looked at the query plans first, but they were completely normal.",
        "We agreed to add three more pods before Friday to fix the lag.",
        "Raj will own the pod rollout and report back Monday.",
    ];
    lines
        .iter()
        .enumerate()
        .map(|(i, text)| Segment {
            id: format!("s{i}"),
            start_ms: (i as u64) * 5_000,
            end_ms: (i as u64) * 5_000 + 4_500,
            text: text.to_string(),
        })
        .collect()
}

#[test]
fn a_real_chunk_through_a_real_model_produces_a_grounded_meeting_ir() {
    if !model().exists() {
        eprintln!(
            "skipping: no model at {} -- see rust/airo_mind_cli/README.md",
            model().display()
        );
        return;
    }

    let engine = LlamaGenerationEngine::load(&model(), 1024, 4096).expect("model loads");

    let segments = transcript_segments();
    // A single small chunk covering the whole excerpt -- chunk boundary
    // behavior itself is `#1632`'s own golden tests' job, not this one's.
    let processed = process(
        &segments,
        &ChunkConfig {
            min_len_ms: 60_000,
            max_len_ms: 120_000,
            overlap_ms: 10_000,
            pause_gap_ms: 300,
        },
    );
    assert_eq!(
        processed.chunks.len(),
        1,
        "the whole excerpt should fit in one chunk"
    );

    let cancel = CancelToken::new();
    let facts = extract_chunk_facts(
        &engine,
        &processed.chunks[0],
        &processed.segments,
        &ExtractionConfig::default(),
        &cancel,
    )
    .expect("pass 1 does not hard-fail");

    let ir = consolidate(vec![facts], None);

    let known_ids: std::collections::HashSet<String> =
        processed.segments.iter().map(|s| s.id.clone()).collect();
    assert!(
        ir.all_evidence_is_grounded(&known_ids),
        "every fact/action-item's evidence must cite ids from this transcript: {ir:#?}"
    );

    eprintln!("--- Meeting IR from a real model ---\n{ir:#?}\n---");
    // Deliberately not asserting `fact_count() > 0`: a small on-device model
    // is allowed to under-extract, and `#1633`'s own doc comments record
    // that risk honestly (see `airo_mind_cli`'s `cli_chunk_config` doc
    // comment for the measured behavior against this exact model). What
    // this test proves is the wiring and the evidence-grounding guarantee,
    // not this specific model's extraction quality -- that is `#1636`'s
    // eval harness's job.
}
