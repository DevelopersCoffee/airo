//! Product-facing diarization strategy selector — solo today, embedding when PCM
//! and a real embedder are available.

use airo_mind_core::wav::Pcm;
use airo_mind_transcript::Segment;

use crate::diarizer::{DiarizationError, DiarizationInput, Diarizer};
use crate::embedding_diarizer::EmbeddingDiarizer;
use crate::result::DiarizationResult;
use crate::single_speaker::SingleSpeakerDiarizer;
use crate::stub_embedder::StubSpeakerEmbedder;

/// Which diarizer runs for a recording.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DiarizationStrategy {
    /// v0 product default — one speaker for the whole recording (`sp0`).
    Solo,
    /// Dev/CLI path: deterministic stub embedder + greedy clustering.
    StubEmbedding {
        similarity_threshold: f32,
    },
}

impl Default for DiarizationStrategy {
    fn default() -> Self {
        Self::Solo
    }
}

/// Runs the selected strategy on ASR segments and optional 16 kHz mono PCM.
pub fn diarize_segments(
    segments: &[Segment],
    pcm: Option<&Pcm>,
    strategy: DiarizationStrategy,
) -> Result<DiarizationResult, DiarizationError> {
    match strategy {
        DiarizationStrategy::Solo => SingleSpeakerDiarizer::new().diarize(&DiarizationInput {
            segments,
            pcm: None,
        }),
        DiarizationStrategy::StubEmbedding {
            similarity_threshold,
        } => {
            let pcm = pcm.ok_or(DiarizationError::PcmRequired)?;
            EmbeddingDiarizer::new(StubSpeakerEmbedder::new(8), similarity_threshold).diarize(
                &DiarizationInput {
                    segments,
                    pcm: Some(pcm),
                },
            )
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_core::wav::Pcm;

    fn seg(id: &str, start: u64, end: u64) -> Segment {
        Segment {
            id: id.into(),
            start_ms: start,
            end_ms: end,
            text: format!("segment {id}"),
        }
    }

    #[test]
    fn solo_strategy_needs_no_pcm() {
        let result = diarize_segments(
            &[seg("s0", 0, 1000)],
            None,
            DiarizationStrategy::Solo,
        )
        .expect("solo diarize");
        assert_eq!(result.segments[0].speaker.label(), "sp0");
    }

    #[test]
    fn stub_embedding_requires_pcm() {
        let err = diarize_segments(
            &[seg("s0", 0, 1000)],
            None,
            DiarizationStrategy::StubEmbedding {
                similarity_threshold: 0.85,
            },
        )
        .unwrap_err();
        assert_eq!(err, DiarizationError::PcmRequired);
    }

    #[test]
    fn stub_embedding_assigns_speakers_from_pcm() {
        let pcm = Pcm {
            samples: (0..48_000).map(|i| (i % 100) as i16).collect(),
            sample_rate_hz: 16_000,
            channels: 1,
        };
        let segments = [
            seg("s0", 0, 1_000),
            seg("s1", 1_000, 2_000),
            seg("s2", 2_000, 3_000),
        ];
        let result = diarize_segments(
            &segments,
            Some(&pcm),
            DiarizationStrategy::StubEmbedding {
                similarity_threshold: 0.85,
            },
        )
        .expect("stub embedding diarize");
        assert_eq!(result.segments.len(), 3);
        assert!(!result.speakers.is_empty());
    }
}
