//! Integration-style check that diarization preserves segment evidence fields.

use airo_mind_diarize::{DiarizationInput, Diarizer, SingleSpeakerDiarizer, SpeakerId};
use airo_mind_transcript::Segment;

#[test]
fn preserves_segment_ids_and_timestamps() {
    let segments = [
        Segment {
            id: "s0".into(),
            start_ms: 120,
            end_ms: 450,
            text: "we agreed to ship".into(),
        },
        Segment {
            id: "s1".into(),
            start_ms: 450,
            end_ms: 900,
            text: "next Tuesday".into(),
        },
    ];

    let result = SingleSpeakerDiarizer::new()
        .diarize(&DiarizationInput {
            segments: &segments,
            pcm: None,
            enrollment: None,
        })
        .expect("diarize");

    assert_eq!(result.speakers, vec![SpeakerId::SOLO]);
    let first = &result.segments[0];
    assert_eq!(first.id, "s0");
    assert_eq!(first.start_ms, 120);
    assert_eq!(first.end_ms, 450);
    assert_eq!(first.text, "we agreed to ship");
    assert_eq!(first.speaker.label(), "sp0");
}
