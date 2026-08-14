//! The input shape this crate consumes.
//!
//! A local mirror of `airo_mind_whisper::api::meetings::TranscriptSegmentRecord`
//! / `airo_mind_whisper::transcript_store::StoredSegment` (`#1629`), not a
//! re-export: this crate has no dependency on `airo_mind_whisper` and should
//! not gain one just to borrow a struct. All three shapes carry the same four
//! fields for the same reason -- `id`/`start_ms`/`end_ms`/`text` is the
//! smallest evidence-grounding contract a downstream consumer needs, and
//! whoever calls this crate already has whisper's `TranscriptSegmentRecord`
//! in hand and can build this from it field-for-field.

/// One ASR segment as whisper produced it: a stable id scoped to the
/// recording (`"s0"`, `"s1"`, …) and the timestamps/text that came with it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Segment {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}
