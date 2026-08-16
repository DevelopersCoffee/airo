//! Product-facing diarization strategy selector — solo today, embedding when PCM
//! and a real embedder are available.

use std::path::Path;

use airo_mind_core::wav::Pcm;
use airo_mind_transcript::Segment;

use crate::diarizer::{DiarizationError, DiarizationInput, Diarizer};
use crate::embedder_factory::{resolve_embedder, ResolvedEmbedder};
use crate::embedding_diarizer::EmbeddingDiarizer;
use crate::model_files::ecapa_model_path;
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
    /// Product embedding path — ECAPA when installed, stub in tests without weights.
    Embedding {
        similarity_threshold: f32,
    },
}

impl Default for DiarizationStrategy {
    fn default() -> Self {
        Self::Solo
    }
}

/// Strategy for transcribe: embedding when ECAPA weights are on disk, else solo.
pub fn product_diarization_strategy(models_dir: &Path) -> DiarizationStrategy {
    if ecapa_model_path(models_dir).is_some() {
        DiarizationStrategy::Embedding {
            similarity_threshold: 0.85,
        }
    } else {
        DiarizationStrategy::Solo
    }
}

/// Runs the selected strategy on ASR segments and optional 16 kHz mono PCM.
pub fn diarize_segments(
    segments: &[Segment],
    pcm: Option<&Pcm>,
    strategy: DiarizationStrategy,
    models_dir: Option<&Path>,
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
        DiarizationStrategy::Embedding {
            similarity_threshold,
        } => {
            let pcm = pcm.ok_or(DiarizationError::PcmRequired)?;
            let embedder = resolve_embedder(models_dir);
            run_embedding_diarizer(embedder, segments, pcm, similarity_threshold)
        }
    }
}

fn run_embedding_diarizer(
    embedder: ResolvedEmbedder,
    segments: &[Segment],
    pcm: &Pcm,
    similarity_threshold: f32,
) -> Result<DiarizationResult, DiarizationError> {
    match embedder {
        ResolvedEmbedder::Stub(stub) => {
            EmbeddingDiarizer::new(stub, similarity_threshold).diarize(&DiarizationInput {
                segments,
                pcm: Some(pcm),
            })
        }
        ResolvedEmbedder::EcapaOnnx(onnx) => {
            EmbeddingDiarizer::new(onnx, similarity_threshold).diarize(&DiarizationInput {
                segments,
                pcm: Some(pcm),
            })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_core::wav::Pcm;
    use std::path::PathBuf;

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
            None,
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
            None,
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
            None,
        )
        .expect("stub embedding diarize");
        assert_eq!(result.segments.len(), 3);
        assert!(!result.speakers.is_empty());
    }

    #[test]
    fn product_strategy_picks_embedding_when_ecapa_file_present() {
        let dir = std::env::temp_dir().join(format!(
            "airo_diarize_strategy_{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("temp dir");
        std::fs::write(dir.join(crate::model_files::ECAPA_TINY_ONNX_FILE), [0u8; 8])
            .expect("write ecapa stub file");

        assert_eq!(
            product_diarization_strategy(&dir),
            DiarizationStrategy::Embedding {
                similarity_threshold: 0.85,
            }
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn product_strategy_defaults_to_solo_without_ecapa() {
        let dir = PathBuf::from("/tmp/airo-mind-no-ecapa-dir-never-exists");
        assert_eq!(product_diarization_strategy(&dir), DiarizationStrategy::Solo);
    }
}
