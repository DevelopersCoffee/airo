#![deny(unsafe_code)]
//! Airo Mind Meeting capability — Meeting IR and two-pass extraction. `#1633`,
//! Milestone 26 Phase 2/Wave 2.
//!
//! # The rule this crate exists to keep
//!
//! **The LLM never summarises the transcript.** Pass 1 extracts atomic facts
//! from one chunk at a time, each citing the segment ids it came from. Pass 2
//! consolidates those facts into one meeting IR. Neither pass produces prose.
//! Minutes, action-item lists and meeting search are *projections* of the IR,
//! built elsewhere (`#1634` onward) — a projection can be regenerated, argued
//! with, and traced back to a timestamp in the recording. A summary cannot.
//!
//! # Where this sits
//!
//! ```text
//! airo_mind_whisper  #1629   audio        -> segments
//! airo_mind_transcript #1632 segments     -> normalized text + chunks (segment_ids)
//! airo_mind_meeting  #1633   chunks       -> MeetingIr          <- this crate
//! (projections)      #1634+  MeetingIr    -> minutes / actions / search
//! ```
//!
//! It is the **capability**, above the runtime's engine boundary. `C5` keeps
//! meeting vocabulary out of `airo_mind_core`/`airo_mind_llama`, so the prompt,
//! the GBNF grammar, the IR schema and the word "meeting" all live here, and
//! the engine below only ever sees a `GenerationRequest`. That is also why this
//! crate takes a `&dyn GenerationEngine` rather than constructing one: the real
//! llama engine and a test double are the same shape to it, and nothing here
//! needs cmake to compile or a 4 GB model to test.
//!
//! # Persistence is somewhere else
//!
//! Nothing here writes anything. Recording a `MeetingIr` into the operation log
//! is `#1657`; this crate is pure transformation, which is what makes both
//! passes testable without a vault.
//!
//! # Off the main isolate
//!
//! Same as `airo_mind_transcript`: no FFI surface of its own, called from Rust
//! by whichever engine crate drives extraction, already off the Flutter main
//! isolate at the `core_native` boundary. There is no synchronous path from
//! Dart into this crate to guard.

pub mod dedup;
pub mod diagnostics;
mod fact;
pub mod ir;
pub mod pass1;
pub mod pass2;
pub mod prompt;

use std::collections::BTreeMap;

use airo_mind_core::{CancelToken, GenerationEngine};
use airo_mind_transcript::ProcessedTranscript;

pub use dedup::DedupConfig;
pub use diagnostics::Diagnostic;
pub use ir::{
    ActionItem, ActionStatus, ChunkIr, Decision, DecisionStatus, Facts, Meeting, MeetingIr, Metric,
    NextStep, Observation, Question, Risk, Topic, IR_SCHEMA_VERSION,
};
pub use pass1::{extract_chunk, ExtractionConfig};
pub use pass2::consolidate;
pub use prompt::{CHUNK_FACTS_GRAMMAR, PROMPT_VERSION};

/// Why extraction could not finish at all.
///
/// Deliberately short. A chunk whose output would not parse, an item that cited
/// a segment it could not have, an owner the transcript never named — none of
/// those are errors. They are [`Diagnostic`]s, and the run still produces an IR.
/// These two are the cases where there is nothing to produce.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExtractionError {
    /// The user navigated away. Nothing partial should be treated as a result.
    Cancelled,
    /// The generation backend failed or has no model. Reported once, with the
    /// engine's own message, rather than retried per chunk — every remaining
    /// chunk would fail the same way.
    Engine(String),
}

impl std::fmt::Display for ExtractionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Cancelled => write!(f, "cancelled"),
            Self::Engine(message) => write!(f, "generation engine failed: {message}"),
        }
    }
}

impl std::error::Error for ExtractionError {}

/// What the caller knows about the meeting that the transcript does not.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MeetingInput {
    pub id: String,
    pub title: Option<String>,
    /// The logical model id and version that will do the extracting, as
    /// `airo_mind_llama::generation_model_id` reports it. `None` records
    /// "unknown provenance" honestly rather than inventing one.
    pub model_id: Option<String>,
}

/// One completed extraction: the IR, and everything the run discarded.
#[derive(Clone, Debug, PartialEq)]
pub struct Extraction {
    pub ir: MeetingIr,
    /// Pass 1's per-chunk output, before consolidation. Kept because it is what
    /// makes a consolidation decision reviewable after the fact — and what
    /// MIND-LLM-11 needs to score the two passes separately.
    pub chunk_irs: Vec<ChunkIr>,
    pub diagnostics: Vec<Diagnostic>,
}

/// Runs both passes over a processed transcript.
///
/// This is the entry point; [`extract_chunk`] and [`consolidate`] are exposed
/// underneath it for callers that need to drive the passes separately (an eval
/// harness scoring Pass 1 on its own, for instance).
///
/// A transcript with no chunks yields an empty IR rather than an error — a
/// recording of silence is a legitimate meeting with nothing in it.
pub fn extract(
    engine: &dyn GenerationEngine,
    transcript: &ProcessedTranscript,
    meeting: &MeetingInput,
    config: &ExtractionConfig,
    cancel: &CancelToken,
) -> Result<Extraction, ExtractionError> {
    let segment_text: BTreeMap<&str, &str> = transcript
        .segments
        .iter()
        .map(|s| (s.id.as_str(), s.normalized.as_str()))
        .collect();

    let mut chunk_irs = Vec::with_capacity(transcript.chunks.len());
    let mut diagnostics = Vec::new();
    for chunk in &transcript.chunks {
        let (chunk_ir, chunk_diagnostics) =
            extract_chunk(engine, chunk, &segment_text, config, cancel)?;
        chunk_irs.push(chunk_ir);
        diagnostics.extend(chunk_diagnostics);
    }

    let meta = Meeting {
        id: meeting.id.clone(),
        title: meeting.title.clone(),
        started_at_ms: transcript.segments.first().map(|s| s.start_ms).unwrap_or(0),
        ended_at_ms: transcript.segments.last().map(|s| s.end_ms).unwrap_or(0),
        chunk_count: u32::try_from(transcript.chunks.len()).unwrap_or(u32::MAX),
        segment_count: u32::try_from(transcript.segments.len()).unwrap_or(u32::MAX),
        model_id: meeting.model_id.clone(),
        prompt_version: PROMPT_VERSION.to_string(),
    };

    let (ir, merge_diagnostics) = consolidate(&chunk_irs, meta, &config.dedup);
    diagnostics.extend(merge_diagnostics);

    Ok(Extraction {
        ir,
        chunk_irs,
        diagnostics,
    })
}
