//! ECAPA-TDNN ONNX embedder scaffold — loads when weights are on disk.

use std::path::PathBuf;

use airo_mind_core::wav::Pcm;

use crate::diarizer::DiarizationError;
use crate::embedder::{SpeakerEmbedder, SpeakerEmbedding};

/// Speaker embedder backed by an ECAPA-TDNN ONNX file.
///
/// Inference is not wired yet (`ort` / ONNX Runtime lands in a follow-up once
/// the pinned weights are distributed). The struct exists so product code can
/// select the embedding path when the file is installed and fail gracefully
/// until runtime inference ships.
#[derive(Clone, Debug)]
pub struct EcapaOnnxEmbedder {
    pub path: PathBuf,
}

impl EcapaOnnxEmbedder {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }
}

impl SpeakerEmbedder for EcapaOnnxEmbedder {
    fn embed_segment(
        &self,
        _pcm: &Pcm,
        _start_ms: u64,
        _end_ms: u64,
    ) -> Result<SpeakerEmbedding, DiarizationError> {
        Err(DiarizationError::Internal(format!(
            "ECAPA ONNX inference is not linked yet (model at {})",
            self.path.display()
        )))
    }
}
