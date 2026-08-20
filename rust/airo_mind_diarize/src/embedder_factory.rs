//! Resolves which [`SpeakerEmbedder`] runs for a recording.

use std::path::Path;

use airo_mind_core::wav::Pcm;

use crate::diarizer::DiarizationError;
use crate::embedder::{SpeakerEmbedder, SpeakerEmbedding};
#[cfg(feature = "ecapa-ort")]
use crate::model_files::ecapa_model_path;
use crate::stub_embedder::StubSpeakerEmbedder;

#[cfg(feature = "ecapa-ort")]
use crate::ecapa_onnx::EcapaOnnxEmbedder;

/// Embedder selected for one diarization run.
pub enum ResolvedEmbedder {
    Stub(StubSpeakerEmbedder),
    #[cfg(feature = "ecapa-ort")]
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
            #[cfg(feature = "ecapa-ort")]
            ResolvedEmbedder::EcapaOnnx(embedder) => embedder.embed_segment(pcm, start_ms, end_ms),
        }
    }
}

/// Dev/tests default — deterministic hash vectors.
pub fn stub_embedder() -> ResolvedEmbedder {
    ResolvedEmbedder::Stub(StubSpeakerEmbedder::new(8))
}

/// ECAPA when the optional ONNX file is installed and `ecapa-ort` is enabled;
/// stub otherwise (dev/tests / CI without ORT).
pub fn resolve_embedder(models_dir: Option<&Path>) -> ResolvedEmbedder {
    #[cfg(feature = "ecapa-ort")]
    if let Some(path) = models_dir.and_then(ecapa_model_path) {
        if let Ok(embedder) = EcapaOnnxEmbedder::try_new(path) {
            return ResolvedEmbedder::EcapaOnnx(embedder);
        }
    }
    #[cfg(not(feature = "ecapa-ort"))]
    let _ = models_dir;
    stub_embedder()
}
