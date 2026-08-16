//! Speaker embedding trait — ECAPA-TDNN / ONNX backends plug in here.

use airo_mind_core::wav::Pcm;

use crate::diarizer::DiarizationError;

/// One segment's embedding vector (L2-normalized when produced by stock impls).
pub type SpeakerEmbedding = Vec<f32>;

/// Extracts a fixed-dimensional speaker embedding from a PCM slice.
pub trait SpeakerEmbedder {
    /// [start_ms] / [end_ms] are inclusive segment bounds in the parent recording.
    fn embed_segment(
        &self,
        pcm: &Pcm,
        start_ms: u64,
        end_ms: u64,
    ) -> Result<SpeakerEmbedding, DiarizationError>;
}
