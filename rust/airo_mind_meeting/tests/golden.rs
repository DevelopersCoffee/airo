//! End-to-end: a reference meeting transcript through both passes, against a
//! golden IR. `#1633`.
//!
//! # Why a scripted engine and not a real model
//!
//! The engine below returns fixed JSON from `tests/fixtures/model_output/`. That
//! makes this a test of the **pipeline** — grounding, owner erasure, retry,
//! consolidation, dedup, id assignment, provenance — all of which are this
//! crate's own logic and all of which must be exactly reproducible. Whether a
//! 3B model actually extracts these facts from this transcript is a different
//! question, measured by F1 against the same fixtures in MIND-LLM-11; putting a
//! real model here would make a dedup regression indistinguishable from the
//! model having a bad day.
//!
//! The fixtures are written the way a model behaving badly would write them:
//! overlapping chunks restate the same facts in different words, one item cites
//! a segment that is not in its chunk, and one names an owner nobody in the
//! meeting mentioned. All three are things extraction has to survive.

use std::collections::BTreeMap;
use std::sync::Mutex;

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeStats,
};
use airo_mind_meeting::{
    consolidate, extract, DedupConfig, Diagnostic, ExtractionConfig, ExtractionError, Meeting,
    MeetingInput, MeetingIr,
};
use airo_mind_transcript::{ChunkConfig, ProcessedTranscript, Segment};
use serde::Deserialize;

// ---------------------------------------------------------------------------
// The reference transcript
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RefSegment {
    id: String,
    start_ms: u64,
    end_ms: u64,
    text: String,
}

#[derive(Deserialize)]
struct RefMeeting {
    segments: Vec<RefSegment>,
}

/// 20s–40s chunks with a 10s overlap. Real meetings use 5–10 minutes
/// (`ChunkConfig::default`); the reference transcript is a minute long, and
/// scaling the window down is what gives it the same *shape* — four chunks,
/// each overlapping its neighbour — at a size a reviewer can read in full.
fn reference_chunk_config() -> ChunkConfig {
    ChunkConfig {
        min_len_ms: 20_000,
        max_len_ms: 40_000,
        overlap_ms: 10_000,
        pause_gap_ms: 500,
    }
}

fn reference_transcript() -> ProcessedTranscript {
    let meeting: RefMeeting =
        serde_json::from_str(include_str!("fixtures/reference_meeting.json")).unwrap();
    let segments: Vec<Segment> = meeting
        .segments
        .into_iter()
        .map(|s| Segment {
            id: s.id,
            start_ms: s.start_ms,
            end_ms: s.end_ms,
            text: s.text,
        })
        .collect();
    airo_mind_transcript::process(&segments, &reference_chunk_config())
}

fn reference_meeting_input() -> MeetingInput {
    MeetingInput {
        id: "meeting-1633-reference".into(),
        title: Some("Signaling capacity review".into()),
        model_id: Some("model-under-test@0.0.0".into()),
    }
}

// ---------------------------------------------------------------------------
// The scripted engine
// ---------------------------------------------------------------------------

/// A `GenerationEngine` that answers from a script keyed by the first segment
/// id in the prompt.
///
/// Keyed rather than call-ordered so a change to the chunker surfaces as an
/// unmatched key ("no script for s6") instead of quietly shifting every
/// response one chunk to the left. Each key holds a queue, which is how the
/// retry path is scripted: the first entry is what the model returns on attempt
/// one, the next on attempt two.
struct ScriptedEngine {
    script: Mutex<BTreeMap<String, Vec<String>>>,
    /// Every prompt it was given, so a test can assert on what the model was
    /// actually asked.
    prompts: Mutex<Vec<String>>,
    /// Every request's `grammar`, so a test can assert whether the sampler was
    /// constrained — which `#1739` makes a safety property, not a detail.
    grammars: Mutex<Vec<Option<String>>>,
}

impl ScriptedEngine {
    fn new(script: &[(&str, &[&str])]) -> Self {
        Self {
            script: Mutex::new(
                script
                    .iter()
                    .map(|(key, responses)| {
                        (
                            (*key).to_string(),
                            responses.iter().map(|r| (*r).to_string()).collect(),
                        )
                    })
                    .collect(),
            ),
            prompts: Mutex::new(Vec::new()),
            grammars: Mutex::new(Vec::new()),
        }
    }

    /// The four reference chunks, each answering with the fixture named after
    /// it. Keys are the first segment of each chunk: `chunk-0` starts at `s0`,
    /// `chunk-1` at `s3`, `chunk-2` at `s6`, `chunk-3` at `s9`.
    fn reference() -> Self {
        Self::new(&[
            ("s0", &[include_str!("fixtures/model_output/chunk-0.json")]),
            ("s3", &[include_str!("fixtures/model_output/chunk-1.json")]),
            ("s6", &[include_str!("fixtures/model_output/chunk-2.json")]),
            ("s9", &[include_str!("fixtures/model_output/chunk-3.json")]),
        ])
    }

    fn prompts(&self) -> Vec<String> {
        self.prompts.lock().unwrap().clone()
    }

    fn grammars(&self) -> Vec<Option<String>> {
        self.grammars.lock().unwrap().clone()
    }
}

/// The `[sN]` label of the first segment shown in a prompt.
fn first_segment_id(prompt: &str) -> String {
    let start = prompt.find("\n[").expect("prompt has no segment labels") + 2;
    let end = start + prompt[start..].find(']').expect("unterminated label");
    prompt[start..end].to_string()
}

impl GenerationEngine for ScriptedEngine {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(0)
    }

    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }
        self.grammars.lock().unwrap().push(request.grammar.clone());
        self.prompts.lock().unwrap().push(request.prompt.clone());

        let key = first_segment_id(&request.prompt);
        let mut script = self.script.lock().unwrap();
        let queue = script
            .get_mut(&key)
            .unwrap_or_else(|| panic!("no scripted response for a chunk starting at `{key}`"));
        let response = if queue.len() > 1 {
            queue.remove(0)
        } else {
            queue
                .first()
                .unwrap_or_else(|| panic!("script for `{key}` is exhausted"))
                .clone()
        };
        drop(script);

        // Streamed a few characters at a time, so the collector in Pass 1 is
        // exercised the way a real token stream would exercise it rather than
        // handed one whole string.
        for piece in response.as_bytes().chunks(7) {
            sink(GenerationChunk {
                text: String::from_utf8_lossy(piece).into_owned(),
            })?;
        }
        Ok(())
    }

    fn stats(&self) -> RuntimeStats {
        RuntimeStats::default()
    }
}

/// An engine that always fails, to prove a broken backend is an error rather
/// than an empty IR that looks like a meeting where nothing was said.
struct BrokenEngine;

impl GenerationEngine for BrokenEngine {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(0)
    }
    fn generate(
        &self,
        _request: &GenerationRequest,
        _cancel: &CancelToken,
        _sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        Err(EngineError::ModelUnavailable)
    }
    fn stats(&self) -> RuntimeStats {
        RuntimeStats::default()
    }
}

fn run_reference(engine: &dyn GenerationEngine) -> airo_mind_meeting::Extraction {
    run_reference_with(engine, &ExtractionConfig::default())
}

fn run_reference_with(
    engine: &dyn GenerationEngine,
    config: &ExtractionConfig,
) -> airo_mind_meeting::Extraction {
    extract(
        engine,
        &reference_transcript(),
        &reference_meeting_input(),
        config,
        &CancelToken::new(),
    )
    .expect("reference extraction should succeed")
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// The whole point of the fixture: four chunks, each overlapping the next, so
/// the dedup cases below are cross-chunk rather than staged inside one.
#[test]
fn the_reference_transcript_chunks_into_four_overlapping_windows() {
    let transcript = reference_transcript();
    let ids: Vec<Vec<&str>> = transcript
        .chunks
        .iter()
        .map(|c| c.segment_ids.iter().map(String::as_str).collect())
        .collect();
    assert_eq!(
        ids,
        vec![
            vec!["s0", "s1", "s2", "s3", "s4"],
            vec!["s3", "s4", "s5", "s6", "s7"],
            vec!["s6", "s7", "s8", "s9", "s10"],
            vec!["s9", "s10", "s11"],
        ]
    );
}

#[test]
fn the_reference_meeting_produces_the_golden_ir() {
    let extraction = run_reference(&ScriptedEngine::reference());
    let golden: MeetingIr =
        serde_json::from_str(include_str!("fixtures/golden_ir.json")).expect("golden IR parses");

    // Compared as JSON, not as Rust values: the assertion is about the document
    // the rest of the milestone consumes, and a `Value` diff is readable.
    assert_eq!(
        serde_json::to_value(&extraction.ir).unwrap(),
        serde_json::to_value(&golden).unwrap()
    );
}

/// The acceptance criterion, on its own, with the reason it holds spelled out:
/// nobody was named in s2/s3, one chunk's model output invented "Sameer", and
/// the consolidated item is still `null`.
#[test]
fn an_action_item_the_meeting_never_assigned_stays_ownerless() {
    let extraction = run_reference(&ScriptedEngine::reference());

    let unassigned = extraction
        .ir
        .facts
        .action_items
        .iter()
        .find(|a| a.task.contains("signaling limit"))
        .expect("the signalling action survived consolidation");
    assert_eq!(
        unassigned.owner, None,
        "an ownerless action item must never acquire an owner"
    );

    assert!(
        extraction
            .diagnostics
            .contains(&Diagnostic::OwnerNotInTranscript {
                chunk_id: "chunk-3".into(),
                task: "ask the Temporal team about signaling".into(),
                owner: "Sameer".into(),
            }),
        "the invented owner should have been erased and reported: {:#?}",
        extraction.diagnostics
    );

    // ...while an owner the transcript *does* name survives untouched.
    let runbook = extraction
        .ir
        .facts
        .action_items
        .iter()
        .find(|a| a.task.contains("runbook"))
        .expect("the runbook action survived consolidation");
    assert_eq!(runbook.owner.as_deref(), Some("Dev"));
}

/// The issue's worked example, running across three real chunks.
#[test]
fn three_phrasings_across_three_chunks_consolidate_into_one_action_item() {
    let extraction = run_reference(&ScriptedEngine::reference());

    let phrasings: Vec<&str> = extraction
        .chunk_irs
        .iter()
        .flat_map(|c| c.facts.action_items.iter())
        .map(|a| a.task.as_str())
        .filter(|task| task.contains("signaling") || task.contains("signalling"))
        .collect();
    assert_eq!(
        phrasings,
        vec![
            "check the Temporal signaling limit",
            "check the Temporal signaling limit",
            "confirm the Temporal signaling capacity",
            "confirm the Temporal signaling capacity",
            "ask the Temporal team about signaling",
        ],
        "Pass 1 should extract every phrasing as it was said"
    );

    let consolidated: Vec<&str> = extraction
        .ir
        .facts
        .action_items
        .iter()
        .map(|a| a.task.as_str())
        .filter(|task| task.contains("signaling"))
        .collect();
    assert_eq!(
        consolidated,
        vec!["check the Temporal signaling limit"],
        "Pass 2 should collapse them to one"
    );

    // Every segment that contributed is still cited, in transcript order.
    assert_eq!(
        extraction.ir.facts.action_items[0].evidence,
        vec!["s3", "s6", "s9"]
    );
}

#[test]
fn an_item_citing_a_segment_outside_its_chunk_never_reaches_the_ir() {
    let extraction = run_reference(&ScriptedEngine::reference());

    assert!(
        extraction.ir.facts.observations.is_empty(),
        "the only observation in the fixtures cites `s42`, which is in no chunk"
    );
    assert!(extraction.diagnostics.iter().any(|d| matches!(
        d,
        Diagnostic::UnknownEvidenceDropped { segment_id, .. } if segment_id == "s42"
    )));
    assert!(extraction.diagnostics.iter().any(|d| matches!(
        d,
        Diagnostic::UngroundedItemDropped {
            category: "observation",
            ..
        }
    )));
}

#[test]
fn every_item_in_the_ir_cites_a_segment_the_transcript_actually_has() {
    let transcript = reference_transcript();
    let known: Vec<&str> = transcript.segments.iter().map(|s| s.id.as_str()).collect();
    let extraction = run_reference(&ScriptedEngine::reference());
    let facts = &extraction.ir.facts;

    let mut cited: Vec<(&str, &[String])> = Vec::new();
    cited.extend(
        facts
            .topics
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );
    cited.extend(
        facts
            .observations
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );
    cited.extend(
        facts
            .decisions
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );
    cited.extend(
        facts
            .action_items
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );
    cited.extend(
        facts
            .metrics
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );
    cited.extend(facts.risks.iter().map(|i| (i.id.as_str(), &i.evidence[..])));
    cited.extend(
        facts
            .questions
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );
    cited.extend(
        facts
            .next_steps
            .iter()
            .map(|i| (i.id.as_str(), &i.evidence[..])),
    );

    assert!(!cited.is_empty());
    for (id, evidence) in cited {
        assert!(!evidence.is_empty(), "`{id}` cites nothing");
        for segment in evidence {
            assert!(
                known.contains(&segment.as_str()),
                "`{id}` cites `{segment}`, which is not in the transcript"
            );
        }
    }
}

// ---------------------------------------------------------------------------
// `#1739`: no terminating grammar reaches a real sampler by default
// ---------------------------------------------------------------------------

/// The regression test for `#1739`. A GBNF grammar with a terminal state — and
/// `CHUNK_FACTS_GRAMMAR` closes with `}`, so it has one — makes llama.cpp
/// `abort()` the whole OS process one token past completion. That is not a Rust
/// panic and nothing above it can catch it, so the only assertion that means
/// anything is that the default configuration never puts such a grammar in
/// front of the sampler at all.
#[test]
fn extraction_does_not_constrain_the_sampler_by_default() {
    let engine = ScriptedEngine::reference();
    run_reference_with(&engine, &ExtractionConfig::default());

    let grammars = engine.grammars();
    assert!(!grammars.is_empty(), "no generation ran");
    assert!(
        grammars.iter().all(Option::is_none),
        "the default config attached a grammar: {grammars:?}"
    );
}

/// The other half of the same contract: the constrained path is still wired,
/// still reaches the engine, and still produces the identical IR — it is opt-in
/// pending a device confirmation of the driver fix, not deleted.
#[test]
fn the_grammar_still_reaches_the_engine_when_it_is_opted_into() {
    let engine = ScriptedEngine::reference();
    let extraction = run_reference_with(
        &engine,
        &ExtractionConfig {
            use_gbnf_grammar: true,
            ..ExtractionConfig::default()
        },
    );

    let grammars = engine.grammars();
    assert!(!grammars.is_empty(), "no generation ran");
    assert!(
        grammars
            .iter()
            .all(|g| g.as_deref() == Some(airo_mind_meeting::CHUNK_FACTS_GRAMMAR)),
        "opting in did not attach the grammar: {grammars:?}"
    );

    let golden: MeetingIr = serde_json::from_str(include_str!("fixtures/golden_ir.json")).unwrap();
    assert_eq!(
        serde_json::to_value(&extraction.ir).unwrap(),
        serde_json::to_value(&golden).unwrap(),
        "constraining the sampler must not change the IR"
    );
}

/// What the mitigation actually costs, and that it is paid. Unconstrained, the
/// model can answer with prose — the failure mode the grammar existed to make
/// impossible. The retry path has to absorb that and still land on the golden
/// IR, or "default the grammar off" is not a mitigation, it is a regression.
#[test]
fn a_chunk_answered_with_prose_is_retried_and_still_lands_on_the_golden_ir() {
    let prose = "Sure! In this part of the meeting the team talked about Kafka consumer lag \
                 and agreed to add more pods.";
    let engine = ScriptedEngine::new(&[
        (
            "s0",
            &[prose, include_str!("fixtures/model_output/chunk-0.json")],
        ),
        ("s3", &[include_str!("fixtures/model_output/chunk-1.json")]),
        ("s6", &[include_str!("fixtures/model_output/chunk-2.json")]),
        ("s9", &[include_str!("fixtures/model_output/chunk-3.json")]),
    ]);

    let extraction = run_reference_with(&engine, &ExtractionConfig::default());

    assert!(extraction.diagnostics.iter().any(|d| matches!(
        d,
        Diagnostic::UnparseableOutput { chunk_id, attempt: 1, .. } if chunk_id == "chunk-0"
    )));
    let golden: MeetingIr = serde_json::from_str(include_str!("fixtures/golden_ir.json")).unwrap();
    assert_eq!(
        serde_json::to_value(&extraction.ir).unwrap(),
        serde_json::to_value(&golden).unwrap(),
        "unconstrained generation plus retry must reach the same IR the grammar would have"
    );
}

/// Output that parses as JSON but not as `Facts` is caught by the same path:
/// `serde_json` into the IR types is the schema check, so a category of the
/// wrong shape is an unparseable attempt rather than a value that survives
/// into grounding.
#[test]
fn output_that_is_json_but_not_the_ir_schema_is_a_retryable_failure() {
    let wrong_shape = "{\"decisions\": \"we agreed to add three more pods\"}";
    let engine = ScriptedEngine::new(&[
        (
            "s0",
            &[
                wrong_shape,
                include_str!("fixtures/model_output/chunk-0.json"),
            ],
        ),
        ("s3", &[include_str!("fixtures/model_output/chunk-1.json")]),
        ("s6", &[include_str!("fixtures/model_output/chunk-2.json")]),
        ("s9", &[include_str!("fixtures/model_output/chunk-3.json")]),
    ]);

    let extraction = run_reference_with(&engine, &ExtractionConfig::default());

    assert!(extraction.diagnostics.iter().any(|d| matches!(
        d,
        Diagnostic::UnparseableOutput { chunk_id, attempt: 1, .. } if chunk_id == "chunk-0"
    )));
    let golden: MeetingIr = serde_json::from_str(include_str!("fixtures/golden_ir.json")).unwrap();
    assert_eq!(
        serde_json::to_value(&extraction.ir).unwrap(),
        serde_json::to_value(&golden).unwrap()
    );
}

/// Without the grammar, retry is the only thing standing between a bad reply
/// and an abandoned chunk — so a retry that re-sent the identical prompt would
/// be worthless against a greedy, deterministic sampler. The second attempt
/// must ask something the first did not.
#[test]
fn a_retry_asks_a_different_question_than_the_attempt_that_failed() {
    let engine = ScriptedEngine::new(&[
        (
            "s0",
            &[
                "not json at all",
                include_str!("fixtures/model_output/chunk-0.json"),
            ],
        ),
        ("s3", &[include_str!("fixtures/model_output/chunk-1.json")]),
        ("s6", &[include_str!("fixtures/model_output/chunk-2.json")]),
        ("s9", &[include_str!("fixtures/model_output/chunk-3.json")]),
    ]);

    run_reference_with(&engine, &ExtractionConfig::default());

    let prompts = engine.prompts();
    let chunk_0: Vec<&String> = prompts.iter().filter(|p| p.contains("\n[s0] ")).collect();
    assert_eq!(chunk_0.len(), 2, "chunk-0 should have been asked twice");
    assert_ne!(
        chunk_0[0], chunk_0[1],
        "the retry re-sent the prompt that just failed"
    );
    // Still the same extraction task, only a corrected reply format.
    assert!(chunk_0[1].starts_with(chunk_0[0].trim_end()));
}

/// Truncated output is the realistic grammar-era failure: the sampler cannot
/// emit an invalid object, but it can be stopped mid-object by the token
/// ceiling. That retries, and the retry's result is what lands in the IR.
#[test]
fn a_chunk_whose_first_attempt_is_truncated_is_retried_and_succeeds() {
    let truncated = "{\"topics\":[{\"title\":\"Temporal signaling li";
    let engine = ScriptedEngine::new(&[
        (
            "s0",
            &[
                truncated,
                include_str!("fixtures/model_output/chunk-0.json"),
            ],
        ),
        ("s3", &[include_str!("fixtures/model_output/chunk-1.json")]),
        ("s6", &[include_str!("fixtures/model_output/chunk-2.json")]),
        ("s9", &[include_str!("fixtures/model_output/chunk-3.json")]),
    ]);

    let extraction = run_reference(&engine);

    assert!(extraction.diagnostics.iter().any(|d| matches!(
        d,
        Diagnostic::UnparseableOutput { chunk_id, attempt: 1, .. } if chunk_id == "chunk-0"
    )));
    let golden: MeetingIr = serde_json::from_str(include_str!("fixtures/golden_ir.json")).unwrap();
    assert_eq!(
        serde_json::to_value(&extraction.ir).unwrap(),
        serde_json::to_value(&golden).unwrap(),
        "a retried chunk should land on exactly the same IR"
    );
}

/// The bound in "bounded retries": a chunk that never parses is abandoned after
/// `max_attempts`, and the rest of the meeting still extracts.
#[test]
fn a_chunk_that_never_parses_is_abandoned_after_a_fixed_number_of_attempts() {
    let junk = "{\"topics\":[{\"title\":";
    let engine = ScriptedEngine::new(&[
        ("s0", &[junk]),
        ("s3", &[include_str!("fixtures/model_output/chunk-1.json")]),
        ("s6", &[include_str!("fixtures/model_output/chunk-2.json")]),
        ("s9", &[include_str!("fixtures/model_output/chunk-3.json")]),
    ]);

    let extraction = run_reference(&engine);

    assert_eq!(
        extraction
            .diagnostics
            .iter()
            .filter(|d| matches!(
                d,
                Diagnostic::UnparseableOutput { chunk_id, .. } if chunk_id == "chunk-0"
            ))
            .count(),
        ExtractionConfig::default().max_attempts as usize
    );
    assert!(extraction
        .diagnostics
        .contains(&Diagnostic::ChunkAbandoned {
            chunk_id: "chunk-0".into(),
            attempts: ExtractionConfig::default().max_attempts,
        }));

    // Chunk 0 contributed nothing, so the metric and the question that only it
    // saw are gone -- but the rest of the meeting is intact.
    assert!(extraction.ir.facts.metrics.is_empty());
    assert!(extraction.ir.facts.questions.is_empty());
    assert_eq!(extraction.ir.facts.action_items.len(), 2);
    assert_eq!(extraction.ir.facts.decisions.len(), 1);
}

#[test]
fn a_broken_backend_is_an_error_not_an_empty_meeting() {
    let result = extract(
        &BrokenEngine,
        &reference_transcript(),
        &reference_meeting_input(),
        &ExtractionConfig::default(),
        &CancelToken::new(),
    );
    assert_eq!(
        result,
        Err(ExtractionError::Engine(
            EngineError::ModelUnavailable.to_string()
        ))
    );
}

#[test]
fn a_cancelled_run_yields_nothing_rather_than_a_partial_ir() {
    let cancel = CancelToken::new();
    cancel.cancel();
    let result = extract(
        &ScriptedEngine::reference(),
        &reference_transcript(),
        &reference_meeting_input(),
        &ExtractionConfig::default(),
        &cancel,
    );
    assert_eq!(result, Err(ExtractionError::Cancelled));
}

#[test]
fn a_transcript_with_nothing_in_it_is_an_empty_ir_not_an_error() {
    let empty = airo_mind_transcript::process(&[], &reference_chunk_config());
    let extraction = extract(
        &ScriptedEngine::reference(),
        &empty,
        &reference_meeting_input(),
        &ExtractionConfig::default(),
        &CancelToken::new(),
    )
    .expect("silence is a legitimate meeting");
    assert!(extraction.ir.facts.is_empty());
    assert_eq!(extraction.ir.meeting.chunk_count, 0);
}

/// `ADR-0018 §5`: the IR records what produced it.
#[test]
fn the_ir_records_the_model_and_prompt_version_that_produced_it() {
    let extraction = run_reference(&ScriptedEngine::reference());
    assert_eq!(
        extraction.ir.meeting.model_id.as_deref(),
        Some("model-under-test@0.0.0")
    );
    assert_eq!(
        extraction.ir.meeting.prompt_version,
        airo_mind_meeting::PROMPT_VERSION
    );
    assert_eq!(
        extraction.ir.schema_version,
        airo_mind_meeting::IR_SCHEMA_VERSION
    );
}

/// The model must never be handed the whole meeting — that is the one shape
/// this milestone forbids, and it is checkable directly on the prompts.
#[test]
fn no_prompt_ever_contains_the_whole_transcript() {
    let engine = ScriptedEngine::reference();
    run_reference(&engine);

    let transcript = reference_transcript();
    let prompts = engine.prompts();
    assert_eq!(prompts.len(), transcript.chunks.len());
    for prompt in &prompts {
        assert!(
            !prompt.contains(&transcript.normalized),
            "a prompt carried the entire transcript"
        );
        assert!(prompt.contains("EXTRACT, NEVER SUMMARISE"));
    }
}

#[test]
fn the_same_transcript_and_the_same_script_produce_the_same_ir_every_time() {
    let first = run_reference(&ScriptedEngine::reference());
    let second = run_reference(&ScriptedEngine::reference());
    assert_eq!(first.ir, second.ir);
    assert_eq!(first.chunk_irs, second.chunk_irs);
    assert_eq!(first.diagnostics, second.diagnostics);
}

/// Pass 2 is usable on its own — an eval harness scores the passes separately.
#[test]
fn consolidation_can_be_run_on_pass_one_output_alone() {
    let extraction = run_reference(&ScriptedEngine::reference());
    let (ir, _) = consolidate(
        &extraction.chunk_irs,
        Meeting {
            id: "meeting-1633-reference".into(),
            title: Some("Signaling capacity review".into()),
            started_at_ms: 0,
            ended_at_ms: 59_500,
            chunk_count: 4,
            segment_count: 12,
            model_id: Some("model-under-test@0.0.0".into()),
            prompt_version: airo_mind_meeting::PROMPT_VERSION.into(),
        },
        &DedupConfig::default(),
    );
    assert_eq!(ir, extraction.ir);
}
