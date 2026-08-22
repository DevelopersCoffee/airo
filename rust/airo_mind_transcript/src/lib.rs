#![deny(unsafe_code)]
//! Airo Mind transcript processor. `#1632`, Milestone 26 Phase 2/Wave 2.
//!
//! The preprocessing stage between ASR (`airo_mind_whisper`, `#1629`) and
//! extraction (`#1633`). It produces two things and nothing else:
//!
//! 1. **Raw + normalized text**, per segment and for the whole transcript.
//!    `raw` is evidence — untouched, always traceable back to what whisper
//!    actually produced. `normalized` corrects a known technical-term
//!    vocabulary and number formatting, and is what extraction reads.
//! 2. **Overlapping semantic chunks**, each carrying the segment ids that
//!    back it, so a downstream fact can cite a segment id rather than bare
//!    LLM output — the evidence-grounding rule this whole milestone runs on.
//!
//! Nothing here summarizes or extracts a fact. That is `#1633`'s job, on the
//! other side of this stage's output — the "LLM never summarizes the
//! transcript directly" rule the epic states applies to the boundary right
//! here: this crate does not call an LLM at all.
//!
//! # Off the main isolate
//!
//! This crate is pure Rust with no FFI surface (see `Cargo.toml`'s `crate-type`
//! note). It is not itself compiled into a Flutter-reachable cdylib; whichever
//! engine crate wires `#1633`'s extraction pass will call [`process`] from
//! Rust, which already runs off the Flutter main isolate the same way every
//! other engine call does (`packages/core_native`'s FFI boundary runs on a
//! background isolate/thread by construction — see `AGENTS.md`'s "parsing
//! never runs on the main isolate" rule). There is no synchronous call site
//! into this crate from Dart to guard against.

pub mod chunk;
pub mod normalize;
pub mod segment;
pub mod vocabulary;

pub use chunk::{Chunk, ChunkConfig, ChunkInput};
pub use normalize::{NormalizationResult, NumberNormalization, TermCorrection};
pub use segment::Segment;
pub use vocabulary::{
    CorrectionResult, VocabularyCategory, VocabularyContext, VocabularyCorrection,
    VocabularyEntry, VocabularyIntelligence, VocabularySource,
};

/// One segment's raw and normalized text side by side, with its timestamps
/// and id carried through unchanged.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProcessedSegment {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub raw: String,
    pub normalized: String,
    pub terms_corrected: Vec<TermCorrection>,
    pub numbers: Vec<NumberNormalization>,
}

/// The full output of preprocessing one transcript: raw and normalized text
/// (both whole-transcript and per-segment), and the overlapping chunks built
/// from the normalized segments.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProcessedTranscript {
    pub raw: String,
    pub normalized: String,
    pub segments: Vec<ProcessedSegment>,
    pub chunks: Vec<Chunk>,
}

/// Runs the full pipeline: normalize every segment, then chunk the
/// normalized segments. Deterministic — depends only on `segments`' own
/// content and `config`.
pub fn process(segments: &[Segment], config: &ChunkConfig) -> ProcessedTranscript {
    let processed: Vec<ProcessedSegment> = segments
        .iter()
        .map(|s| {
            let result = normalize::normalize(&s.text);
            ProcessedSegment {
                id: s.id.clone(),
                start_ms: s.start_ms,
                end_ms: s.end_ms,
                raw: result.raw,
                normalized: result.normalized,
                terms_corrected: result.terms_corrected,
                numbers: result.numbers,
            }
        })
        .collect();

    let chunk_inputs: Vec<ChunkInput> = processed
        .iter()
        .map(|s| ChunkInput {
            id: s.id.clone(),
            start_ms: s.start_ms,
            end_ms: s.end_ms,
            text: s.normalized.clone(),
        })
        .collect();
    let chunks = chunk::chunk_segments(&chunk_inputs, config);

    // Raw stays a plain join of each segment's untouched text — the same
    // "join what the engine gave you" rule `TranscriptEvent::TranscriptReady`
    // already applies to the flat `text` field in
    // `airo_mind_whisper::api::meetings`.
    let raw = segments
        .iter()
        .map(|s| s.text.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    let normalized = processed
        .iter()
        .map(|s| s.normalized.as_str())
        .collect::<Vec<_>>()
        .join(" ");

    ProcessedTranscript {
        raw,
        normalized,
        segments: processed,
        chunks,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(id: &str, start_ms: u64, end_ms: u64, text: &str) -> Segment {
        Segment {
            id: id.to_string(),
            start_ms,
            end_ms,
            text: text.to_string(),
        }
    }

    #[test]
    fn raw_is_untouched_while_normalized_corrects_known_terms() {
        let segments = vec![seg(
            "s0",
            0,
            2_000,
            "we moved the temple workspace onto GCP and fixed the worklows.",
        )];
        let out = process(&segments, &ChunkConfig::default());

        assert_eq!(
            out.segments[0].raw,
            "we moved the temple workspace onto GCP and fixed the worklows."
        );
        assert_eq!(
            out.segments[0].normalized,
            "we moved the Temporal workspace onto GCP and fixed the workflows."
        );
        assert!(out.raw.contains("temple workspace"));
        assert!(!out.normalized.contains("temple workspace"));
    }

    #[test]
    fn number_normalization_reports_canonical_and_display() {
        let segments = vec![seg(
            "s0",
            0,
            2_000,
            "the migration touched about 500,000 rows and 1200000 events.",
        )];
        let out = process(&segments, &ChunkConfig::default());
        let numbers = &out.segments[0].numbers;

        let rows = numbers.iter().find(|n| n.raw == "500,000").unwrap();
        assert_eq!(rows.canonical, 500_000);
        assert_eq!(rows.display, "500,000");

        let events = numbers.iter().find(|n| n.raw == "1200000").unwrap();
        assert_eq!(events.canonical, 1_200_000);
        assert_eq!(events.display, "1,200,000");
        assert!(out.segments[0].normalized.contains("1,200,000"));
    }

    #[test]
    fn same_transcript_produces_identical_chunks_every_time() {
        let segments: Vec<Segment> = (0..50)
            .map(|i| {
                seg(
                    &format!("s{i}"),
                    i * 10_000,
                    i * 10_000 + 9_500,
                    "we discussed the plan.",
                )
            })
            .collect();

        let first = process(&segments, &ChunkConfig::default());
        let second = process(&segments, &ChunkConfig::default());

        assert_eq!(first.chunks, second.chunks);
        assert!(!first.chunks.is_empty());
    }
}
