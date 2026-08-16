//! Embedding + online clustering diarizer.

use crate::cluster::cluster_embeddings_greedy_with_enrollment;
use crate::diarizer::{DiarizationError, DiarizationInput, Diarizer};
use crate::embedder::SpeakerEmbedder;
use crate::result::DiarizationResult;
use crate::segment::DiarizedSegment;

/// Runs [SpeakerEmbedder] per segment, then greedy online clustering.
pub struct EmbeddingDiarizer<E: SpeakerEmbedder> {
    pub embedder: E,
    /// Cosine similarity threshold for joining an existing speaker cluster.
    pub similarity_threshold: f32,
}

impl<E: SpeakerEmbedder> EmbeddingDiarizer<E> {
    pub fn new(embedder: E, similarity_threshold: f32) -> Self {
        Self {
            embedder,
            similarity_threshold,
        }
    }
}

impl<E: SpeakerEmbedder> Diarizer for EmbeddingDiarizer<E> {
    fn diarize(&self, input: &DiarizationInput<'_>) -> Result<DiarizationResult, DiarizationError> {
        if input.segments.is_empty() {
            return Err(DiarizationError::EmptyInput);
        }
        let pcm = input.pcm.ok_or(DiarizationError::PcmRequired)?;

        let embeddings: Vec<_> = input
            .segments
            .iter()
            .map(|s| self.embedder.embed_segment(pcm, s.start_ms, s.end_ms))
            .collect::<Result<_, _>>()?;

        let enrollment_hints: Vec<Option<String>> = embeddings
            .iter()
            .map(|embedding| {
                input
                    .enrollment
                    .and_then(|store| {
                        store
                            .match_embedding(embedding, self.similarity_threshold)
                            .map(|profile| profile.id.clone())
                    })
            })
            .collect();

        let assignments = crate::cluster::cluster_embeddings_greedy_with_enrollment(
            &embeddings,
            self.similarity_threshold,
            &enrollment_hints,
        );

        let segments: Vec<DiarizedSegment> = input
            .segments
            .iter()
            .zip(assignments.iter())
            .map(|(s, assignment)| {
                let mut diarized = DiarizedSegment::from_segment(s, assignment.speaker);
                diarized.enrolled_id = assignment.enrolled_id.clone();
                diarized
            })
            .collect();

        Ok(DiarizationResult::from_segments(segments))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::stub_embedder::StubSpeakerEmbedder;
    use airo_mind_core::wav::Pcm;
    use airo_mind_transcript::Segment;

    fn seg(id: &str, start: u64, end: u64) -> Segment {
        Segment {
            id: id.into(),
            start_ms: start,
            end_ms: end,
            text: format!("segment {id}"),
        }
    }

    #[test]
    fn requires_pcm() {
        let diarizer = EmbeddingDiarizer::new(StubSpeakerEmbedder::new(8), 0.85);
        let err = diarizer
            .diarize(&DiarizationInput {
                segments: &[seg("s0", 0, 1000)],
                pcm: None,
                enrollment: None,
            })
            .unwrap_err();
        assert_eq!(err, DiarizationError::PcmRequired);
    }

    #[test]
    fn assigns_speakers_from_audio_slices() {
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
        let diarizer = EmbeddingDiarizer::new(StubSpeakerEmbedder::new(8), 0.85);
        let result = diarizer
            .diarize(&DiarizationInput {
                segments: &segments,
                pcm: Some(&pcm),
                enrollment: None,
            })
            .expect("diarize");

        assert_eq!(result.segments.len(), 3);
        assert!(!result.speakers.is_empty());
    }
}
