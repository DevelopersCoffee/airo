//! Segment + speaker identity types.

use airo_mind_transcript::Segment;

/// Stable speaker label within one recording (`sp0`, `sp1`, …).
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct SpeakerId(pub u32);

impl SpeakerId {
    pub const SOLO: SpeakerId = SpeakerId(0);

    /// Wire/storage label used by Dart persistence seams.
    pub fn label(self) -> String {
        format!("sp{}", self.0)
    }
}

/// One ASR segment with an assigned speaker.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiarizedSegment {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
    pub speaker: SpeakerId,
    /// Cross-meeting enrolled speaker id (`enrolled_0`, …) when matched (#504).
    pub enrolled_id: Option<String>,
}

impl DiarizedSegment {
    pub fn from_segment(segment: &Segment, speaker: SpeakerId) -> Self {
        Self {
            id: segment.id.clone(),
            start_ms: segment.start_ms,
            end_ms: segment.end_ms,
            text: segment.text.clone(),
            speaker,
            enrolled_id: None,
        }
    }

    /// Wire/storage label — enrolled id when present, else `spN`.
    pub fn wire_label(&self) -> String {
        self.enrolled_id
            .clone()
            .unwrap_or_else(|| self.speaker.label())
    }
}
