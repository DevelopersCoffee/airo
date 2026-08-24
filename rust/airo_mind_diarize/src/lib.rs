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
mod diarization_log;
mod diarizer;
#[cfg(feature = "ecapa-ort")]
mod ecapa_fbank;
#[cfg(feature = "ecapa-ort")]
mod ecapa_onnx;
mod embedder;
mod embedder_factory;
mod embedding_diarizer;
mod enrollment;
mod model_files;
mod pcm_slice;
mod result;
mod segment;
mod single_speaker;
mod strategy;
mod stub_embedder;

pub use cluster::{cluster_embeddings_greedy, ADJACENT_SPLIT_SIMILARITY};
pub use diarizer::{DiarizationError, DiarizationInput, Diarizer};
#[cfg(feature = "ecapa-ort")]
pub use ecapa_onnx::EcapaOnnxEmbedder;
pub use embedder::{SpeakerEmbedder, SpeakerEmbedding};
pub use embedder_factory::{resolve_embedder, stub_embedder, ResolvedEmbedder};
pub use embedding_diarizer::EmbeddingDiarizer;
pub use enrollment::{EnrolledSpeaker, SpeakerEnrollmentStore};
pub use model_files::{ecapa_model_path, ECAPA_TINY_ONNX_FILE};
pub use pcm_slice::{slice_segment_pcm, slice_segment_pcm_padded};
pub use result::DiarizationResult;
pub use segment::{DiarizedSegment, SpeakerId};
pub use single_speaker::SingleSpeakerDiarizer;
pub use strategy::{
    diarize_segments, product_diarization_strategy, DiarizationStrategy,
    DEFAULT_EMBEDDING_SIMILARITY,
};
pub use stub_embedder::StubSpeakerEmbedder;

/// Runs the default v0 diarizer (`SingleSpeakerDiarizer`) on transcript segments.
pub fn diarize_single_speaker(
    segments: &[airo_mind_transcript::Segment],
) -> Result<DiarizationResult, DiarizationError> {
    SingleSpeakerDiarizer::new().diarize(&DiarizationInput {
        segments,
        pcm: None,
        enrollment: None,
    })
}
