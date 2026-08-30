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

/// Cosine threshold for joining an existing speaker cluster (closest-member).
///
/// On vedk00 ECAPA short segments, same-speaker scores often sit 0.97–0.99 and
/// distinct voices in one room 0.92–0.97. `0.72` merged everyone; `0.95` splits
/// most two-speaker recordings without fragmenting one voice.
pub const DEFAULT_EMBEDDING_SIMILARITY: f32 = 0.95;

/// Which diarizer runs for a recording.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub enum DiarizationStrategy {
    /// v0 product default — one speaker for the whole recording (`sp0`).
    #[default]
    Solo,
    /// Dev/CLI path: deterministic stub embedder + greedy clustering.
    StubEmbedding { similarity_threshold: f32 },
    /// Product embedding path — ECAPA when installed, stub in tests without weights.
    Embedding { similarity_threshold: f32 },
}

/// Strategy for transcribe: embedding when ECAPA weights **and** the ORT
/// runtime are available, else solo (`sp0` on every segment).
///
/// File-on-disk alone is not enough: without `ecapa-ort` the embedder is a
/// hash stub that collapses mixed speech into one speaker.
pub fn product_diarization_strategy(models_dir: &Path) -> DiarizationStrategy {
    if ecapa_runtime_ready(models_dir) {
        DiarizationStrategy::Embedding {
            similarity_threshold: DEFAULT_EMBEDDING_SIMILARITY,
        }
    } else {
        DiarizationStrategy::Solo
    }
}

fn ecapa_runtime_ready(models_dir: &Path) -> bool {
    if ecapa_model_path(models_dir).is_none() {
        return false;
    }
    cfg!(feature = "ecapa-ort")
}

/// Runs the selected strategy on ASR segments and optional 16 kHz mono PCM.
pub fn diarize_segments(
    segments: &[Segment],
    pcm: Option<&Pcm>,
    strategy: DiarizationStrategy,
    models_dir: Option<&Path>,
    enrollment: Option<&crate::enrollment::SpeakerEnrollmentStore>,
) -> Result<DiarizationResult, DiarizationError> {
    match strategy {
        DiarizationStrategy::Solo => SingleSpeakerDiarizer::new().diarize(&DiarizationInput {
            segments,
            pcm: None,
            enrollment: None,
        }),
        DiarizationStrategy::StubEmbedding {
            similarity_threshold,
        } => {
            let pcm = pcm.ok_or(DiarizationError::PcmRequired)?;
            EmbeddingDiarizer::new(StubSpeakerEmbedder::new(8), similarity_threshold).diarize(
                &DiarizationInput {
                    segments,
                    pcm: Some(pcm),
                    enrollment,
                },
            )
        }
        DiarizationStrategy::Embedding {
            similarity_threshold,
        } => {
            let pcm = pcm.ok_or(DiarizationError::PcmRequired)?;
            let embedder = resolve_embedder(models_dir);
            run_embedding_diarizer(embedder, segments, pcm, similarity_threshold, enrollment)
        }
    }
}

fn run_embedding_diarizer(
    embedder: ResolvedEmbedder,
    segments: &[Segment],
    pcm: &Pcm,
    similarity_threshold: f32,
    enrollment: Option<&crate::enrollment::SpeakerEnrollmentStore>,
) -> Result<DiarizationResult, DiarizationError> {
    let input = DiarizationInput {
        segments,
        pcm: Some(pcm),
        enrollment,
    };
    match embedder {
        ResolvedEmbedder::Stub(stub) => {
            EmbeddingDiarizer::new(stub, similarity_threshold).diarize(&input)
        }
        #[cfg(feature = "ecapa-ort")]
        ResolvedEmbedder::EcapaOnnx(onnx) => {
            EmbeddingDiarizer::new(onnx, similarity_threshold).diarize(&input)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::embedder::SpeakerEmbedder;
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
            None,
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
            None,
        )
        .expect("stub embedding diarize");
        assert_eq!(result.segments.len(), 3);
        assert!(!result.speakers.is_empty());
    }

    #[test]
    fn product_strategy_needs_ecapa_runtime_not_just_the_file() {
        let dir =
            std::env::temp_dir().join(format!("airo_diarize_strategy_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("temp dir");
        std::fs::write(dir.join(crate::model_files::ECAPA_TINY_ONNX_FILE), [0u8; 8])
            .expect("write ecapa stub file");

        let strategy = product_diarization_strategy(&dir);
        if cfg!(feature = "ecapa-ort") {
            assert_eq!(
                strategy,
                DiarizationStrategy::Embedding {
                    similarity_threshold: DEFAULT_EMBEDDING_SIMILARITY,
                }
            );
        } else {
            assert_eq!(strategy, DiarizationStrategy::Solo);
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn enrollment_hint_labels_segments_with_enrolled_id() {
        let pcm = Pcm {
            samples: (0..48_000).map(|i| (i % 100) as i16).collect(),
            sample_rate_hz: 16_000,
            channels: 1,
        };
        let segments = [seg("s0", 0, 1_000), seg("s1", 1_000, 2_000)];
        let stub = StubSpeakerEmbedder::new(8);
        let embedding = stub.embed_segment(&pcm, 0, 1_000).expect("stub embedding");
        let mut enrollment = crate::enrollment::SpeakerEnrollmentStore::new();
        enrollment.enroll("Alice".into(), embedding);

        let result = diarize_segments(
            &segments,
            Some(&pcm),
            DiarizationStrategy::StubEmbedding {
                similarity_threshold: 0.85,
            },
            None,
            Some(&enrollment),
        )
        .expect("enrollment diarize");

        assert!(
            result
                .segments
                .iter()
                .any(|s| s.enrolled_id.as_deref() == Some("enrolled_0")),
            "expected at least one enrolled match"
        );
    }
}
