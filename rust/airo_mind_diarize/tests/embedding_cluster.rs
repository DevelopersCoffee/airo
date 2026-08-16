//! Two-speaker synthetic fixture via stub embeddings + clustering.

use airo_mind_core::wav::Pcm;
use airo_mind_diarize::{DiarizationInput, Diarizer, EmbeddingDiarizer, StubSpeakerEmbedder};
use airo_mind_transcript::Segment;

#[test]
fn distinct_audio_regions_can_split_speakers() {
    // Region A: low samples; region B: high samples — stub embedder diverges.
    let samples: Vec<i16> = (0..48_000)
        .map(|i| if i < 16_000 { 10 } else { 10_000 })
        .collect();
    let pcm = Pcm {
        samples,
        sample_rate_hz: 16_000,
        channels: 1,
    };
    let segments = [
        Segment {
            id: "s0".into(),
            start_ms: 0,
            end_ms: 1_000,
            text: "low speaker".into(),
        },
        Segment {
            id: "s1".into(),
            start_ms: 1_000,
            end_ms: 2_000,
            text: "low again".into(),
        },
        Segment {
            id: "s2".into(),
            start_ms: 2_000,
            end_ms: 3_000,
            text: "high speaker".into(),
        },
    ];

    let diarizer = EmbeddingDiarizer::new(StubSpeakerEmbedder::new(16), 0.85);
    let result = diarizer
        .diarize(&DiarizationInput {
            segments: &segments,
            pcm: Some(&pcm),
        })
        .expect("diarize");

    assert_eq!(result.segments.len(), 3);
    assert_ne!(result.segments[0].speaker, result.segments[2].speaker);
    assert_eq!(result.speakers.len(), 2);
}
