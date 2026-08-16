//! Resolves which [`SpeakerEmbedder`] runs for a recording.

use std::path::Path;

use airo_mind_core::wav::Pcm;

use crate::diarizer::DiarizationError;
use crate::ecapa_onnx::EcapaOnnxEmbedder;
use crate::embedder::{SpeakerEmbedder, SpeakerEmbedding};
use crate::model_files::ecapa_model_path;
use crate::stub_embedder::StubSpeakerEmbedder;

/// Embedder selected for one diarization run.
pub enum ResolvedEmbedder {
    Stub(StubSpeakerEmbedder),
    EcapaOnnx(EcapaOnnxEmbedder),
}

impl SpeakerEmbedder for ResolvedEmbedder {
    fn embed_segment(
        &self,
        pcm: &Pcm,
        start_ms: u64,
        end_ms: u64,
    ) -> Result<SpeakerEmbedding, DiarizationError> {
        match self {
            ResolvedEmbedder::Stub(embedder) => embedder.embed_segment(pcm, start_ms, end_ms),
            ResolvedEmbedder::EcapaOnnx(embedder) => embedder.embed_segment(pcm, start_ms, end_ms),
        }
    }
}

/// Dev/tests default — deterministic hash vectors.
pub fn stub_embedder() -> ResolvedEmbedder {
    ResolvedEmbedder::Stub(StubSpeakerEmbedder::new(8))
}

/// ECAPA when the optional ONNX file is installed; stub otherwise (dev/tests).
pub fn resolve_embedder(models_dir: Option<&Path>) -> ResolvedEmbedder {
    if let Some(dir) = models_dir {
        if let Some(path) = ecapa_model_path(dir) {
            return ResolvedEmbedder::EcapaOnnx(EcapaOnnxEmbedder::new(path));
        }
    }
    stub_embedder()
}
