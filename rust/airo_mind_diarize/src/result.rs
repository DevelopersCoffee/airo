//! Diarization output.

use std::collections::BTreeSet;

use crate::segment::{DiarizedSegment, SpeakerId};

/// Every segment from the input transcript, each tagged with a speaker, plus
/// the distinct speaker set for UI rollups.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiarizationResult {
    pub segments: Vec<DiarizedSegment>,
    pub speakers: Vec<SpeakerId>,
}

impl DiarizationResult {
    pub fn from_segments(segments: Vec<DiarizedSegment>) -> Self {
        let speakers: Vec<SpeakerId> = segments
            .iter()
            .map(|s| s.speaker)
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
        Self { segments, speakers }
    }
}
