//! Speaker diarization for Airo Mind — Wave 3 scaffolding.
//!
//! Whisper produces time-bounded segments with text but no speaker identity.
//! This crate assigns a stable [`SpeakerId`] per segment so downstream Meeting
//! IR, persistence (`speakerLabel` columns in the app DB), and export can cite
//! who spoke without re-running ASR.
//!
//! The shipped [`SingleSpeakerDiarizer`] is the v0 fallback: one speaker for
//! the whole recording. Future embedders (ECAPA-TDNN tiny, online clustering)
//! implement the same [`Diarizer`] trait and consume optional 16 kHz PCM from
//! [`airo_mind_audio`] / [`airo_mind_core::wav::Pcm`].

#![deny(unsafe_code)]

mod cluster;
mod diarizer;
mod embedder;
mod embedding_diarizer;
mod pcm_slice;
mod result;
mod segment;
mod single_speaker;
mod stub_embedder;

pub use cluster::cluster_embeddings_greedy;
pub use diarizer::{Diarizer, DiarizationError, DiarizationInput};
pub use embedder::{SpeakerEmbedder, SpeakerEmbedding};
pub use embedding_diarizer::EmbeddingDiarizer;
pub use pcm_slice::slice_segment_pcm;
pub use result::DiarizationResult;
pub use segment::{DiarizedSegment, SpeakerId};
pub use single_speaker::SingleSpeakerDiarizer;
pub use stub_embedder::StubSpeakerEmbedder;

/// Runs the default v0 diarizer (`SingleSpeakerDiarizer`) on transcript segments.
pub fn diarize_single_speaker(
    segments: &[airo_mind_transcript::Segment],
) -> Result<DiarizationResult, DiarizationError> {
    SingleSpeakerDiarizer::new().diarize(&DiarizationInput {
        segments,
        pcm: None,
    })
}
