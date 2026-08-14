//! MoM generation against the `#1633` golden IR. `#1635`.
//!
//! # Why the same golden IR the extraction golden test uses
//!
//! `golden_ir.json` is already the fixture `#1633`'s pipeline test proves it
//! can produce byte-for-byte, and it exercises exactly the shapes a MoM has to
//! render correctly: an ownerless action item next to an owned one, a `due`
//! that is present, a number inside a metric's own field (not read by MoM —
//! metrics are outside the issue's five sections, and that is itself worth
//! proving), and one item of each of the five categories the issue names.
//! Reusing it instead of writing a second fixture means a change to the IR
//! shape shows up here the same day it shows up in the extraction golden
//! test, rather than the two silently drifting apart.
//!
//! # Why a scripted engine here too
//!
//! Same reasoning as `tests/golden.rs`: the two narrative sections are the
//! only place a real model's judgement matters, and that judgement is scored
//! by `#1636`'s eval harness, not by this crate's own tests. What this test
//! proves is the *pipeline* -- that `generate_mom` assembles the five
//! sections in the right order, that the tables it builds from the IR are
//! exactly what direct hand-computation from the IR's fields says they should
//! be, and that the same IR and the same script always produce the same
//! document.

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeStats,
};
use airo_mind_meeting::{generate_mom, MeetingIr};
use std::sync::Mutex;

/// Answers "Meeting Objective", then "Key Discussion Points", then repeats --
/// so calling `generate_mom` more than once in a test (determinism checks)
/// does not exhaust the script.
struct GoldenNarrativeEngine {
    calls: Mutex<usize>,
}

impl GoldenNarrativeEngine {
    fn new() -> Self {
        Self {
            calls: Mutex::new(0),
        }
    }
}

const OBJECTIVE_ANSWER: &str =
    "Review the Temporal signaling limit ahead of the planned migration.";
const DISCUSSION_ANSWER: &str = "The team discussed the Temporal signaling limit and agreed to move signaling onto the queue before the release.";

impl GenerationEngine for GoldenNarrativeEngine {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(0)
    }

    fn generate(
        &self,
        _request: &GenerationRequest,
        _cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        let mut calls = self.calls.lock().unwrap();
        let answer = if (*calls).is_multiple_of(2) {
            OBJECTIVE_ANSWER
        } else {
            DISCUSSION_ANSWER
        };
        *calls += 1;
        sink(GenerationChunk {
            text: answer.to_string(),
        })
    }

    fn stats(&self) -> RuntimeStats {
        RuntimeStats::default()
    }
}

fn golden_ir() -> MeetingIr {
    serde_json::from_str(include_str!("fixtures/golden_ir.json")).expect("golden IR parses")
}

#[test]
fn the_golden_ir_produces_the_golden_mom() {
    let engine = GoldenNarrativeEngine::new();
    let mom = generate_mom(&engine, &golden_ir(), &CancelToken::new()).expect("mom generates");

    let golden = include_str!("fixtures/golden_mom.md");
    assert_eq!(mom, golden);
}

/// AC: section completeness = 100%. All five sections the issue names are
/// present, in order, even independent of the exact narrative wording.
#[test]
fn every_required_section_is_present_in_order() {
    let engine = GoldenNarrativeEngine::new();
    let mom = generate_mom(&engine, &golden_ir(), &CancelToken::new()).expect("mom generates");

    let required = [
        "## Meeting Objective",
        "## Key Discussion Points",
        "## Decisions & Direction",
        "## Action Items",
        "## Next Steps",
    ];
    let mut cursor = 0usize;
    for section in required {
        let found = mom[cursor..]
            .find(section)
            .unwrap_or_else(|| panic!("missing required section `{section}`"));
        cursor += found + section.len();
    }
}

/// AC: the action/decision tables are rendered deterministically from the IR
/// -- computed directly from `golden_ir.json`'s fields here, independent of
/// `airo_mind_meeting::render_*` internals, so this catches a rendering
/// regression a unit test inside the same module might share a bug with.
#[test]
fn the_tables_match_the_golden_irs_fields_by_direct_computation() {
    let engine = GoldenNarrativeEngine::new();
    let mom = generate_mom(&engine, &golden_ir(), &CancelToken::new()).expect("mom generates");

    // Decisions & Direction: one row, the golden IR's one decision.
    assert!(mom.contains("| move signaling onto the queue before the release | Agreed |"));

    // Action Items: the ownerless item renders an em dash, never a guess; the
    // owned one renders the owner verbatim.
    assert!(mom.contains("| check the Temporal signaling limit | — | Friday | Open |"));
    assert!(mom.contains("| update the runbook | Dev | Friday | Done |"));

    // Next Steps: the golden IR's one next step, as a bullet.
    assert!(mom.contains("- review the rollout plan"));
}

/// AC: numbers in the MoM byte-match IR values. The golden IR's metric quotes
/// "about 500,000" -- outside the issue's five sections, so it must not
/// appear anywhere, and no other digit should have reached the document
/// through the narrative sections either.
#[test]
fn no_number_reaches_the_document_except_through_a_table_cell() {
    let engine = GoldenNarrativeEngine::new();
    let mom = generate_mom(&engine, &golden_ir(), &CancelToken::new()).expect("mom generates");

    assert!(
        !mom.contains("500,000") && !mom.contains("500000"),
        "the metric's number leaked into a section outside the tables: {mom}"
    );

    let narrative_end = mom.find("## Decisions & Direction").unwrap();
    assert!(
        !mom[..narrative_end].chars().any(|c| c.is_ascii_digit()),
        "a digit reached a narrative section: {mom}"
    );
}

/// The whole point of "deterministic": the same IR and the same script always
/// produce the same document, byte for byte.
#[test]
fn the_same_ir_and_script_produce_the_same_document_every_time() {
    let first = generate_mom(
        &GoldenNarrativeEngine::new(),
        &golden_ir(),
        &CancelToken::new(),
    )
    .unwrap();
    let second = generate_mom(
        &GoldenNarrativeEngine::new(),
        &golden_ir(),
        &CancelToken::new(),
    )
    .unwrap();
    assert_eq!(first, second);
}
