//! v0 fallback: every segment belongs to one speaker.

use crate::diarizer::{DiarizationError, DiarizationInput, Diarizer};
use crate::result::DiarizationResult;
use crate::segment::{DiarizedSegment, SpeakerId};

/// Assigns [`SpeakerId::SOLO`] to every segment. Deterministic and needs no
/// PCM — suitable for solo recordings and pipeline wiring before ECAPA lands.
#[derive(Clone, Copy, Debug, Default)]
pub struct SingleSpeakerDiarizer;

impl SingleSpeakerDiarizer {
    pub fn new() -> Self {
        Self
    }
}

impl Diarizer for SingleSpeakerDiarizer {
    fn diarize(&self, input: &DiarizationInput<'_>) -> Result<DiarizationResult, DiarizationError> {
        if input.segments.is_empty() {
            return Err(DiarizationError::EmptyInput);
        }

        let segments: Vec<DiarizedSegment> = input
            .segments
            .iter()
            .map(|s| DiarizedSegment::from_segment(s, SpeakerId::SOLO))
            .collect();

        Ok(DiarizationResult::from_segments(segments))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_transcript::Segment;

    fn seg(id: &str, start_ms: u64, end_ms: u64, text: &str) -> Segment {
        Segment {
            id: id.to_string(),
            start_ms,
            end_ms,
            text: text.to_string(),
        }
    }

    #[test]
    fn empty_input_is_rejected() {
        let err = SingleSpeakerDiarizer::new()
            .diarize(&DiarizationInput {
                segments: &[],
                pcm: None,
            })
            .unwrap_err();
        assert_eq!(err, DiarizationError::EmptyInput);
    }

    #[test]
    fn assigns_solo_speaker_to_every_segment() {
        let segments = [
            seg("s0", 0, 1_000, "hello"),
            seg("s1", 1_000, 2_000, "world"),
        ];
        let result = SingleSpeakerDiarizer::new()
            .diarize(&DiarizationInput {
                segments: &segments,
                pcm: None,
            })
            .expect("diarize");

        assert_eq!(result.speakers, vec![SpeakerId::SOLO]);
        assert_eq!(result.segments.len(), 2);
        assert!(result.segments.iter().all(|s| s.speaker == SpeakerId::SOLO));
        assert_eq!(result.segments[0].id, "s0");
        assert_eq!(result.segments[1].text, "world");
    }

    #[test]
    fn speaker_label_is_stable_for_persistence() {
        assert_eq!(SpeakerId::SOLO.label(), "sp0");
    }
}
