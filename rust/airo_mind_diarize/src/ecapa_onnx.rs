//! ECAPA-TDNN ONNX embedder — vedk00 SpeechBrain conversion via ONNX Runtime.

use std::path::PathBuf;
use std::sync::Mutex;

use airo_mind_core::wav::Pcm;
use ort::session::Session;
use ort::value::Tensor;

use crate::diarizer::DiarizationError;
use crate::ecapa_fbank::features_from_pcm_i16;
use crate::embedder::{SpeakerEmbedder, SpeakerEmbedding};
use crate::pcm_slice::slice_segment_pcm_padded;

/// Extra audio context on each side of a whisper segment for ECAPA embeddings.
const EMBED_CONTEXT_PAD_MS: u64 = 300;

/// Speaker embedder backed by an ECAPA-TDNN ONNX file.
pub struct EcapaOnnxEmbedder {
    session: Mutex<Session>,
}

impl EcapaOnnxEmbedder {
    pub fn try_new(path: PathBuf) -> Result<Self, DiarizationError> {
        let session = Session::builder()
            .map_err(|e| DiarizationError::Internal(e.to_string()))?
            .commit_from_file(&path)
            .map_err(|e| DiarizationError::Internal(e.to_string()))?;
        Ok(Self {
            session: Mutex::new(session),
        })
    }
}

impl SpeakerEmbedder for EcapaOnnxEmbedder {
    fn embed_segment(
        &self,
        pcm: &Pcm,
        start_ms: u64,
        end_ms: u64,
    ) -> Result<SpeakerEmbedding, DiarizationError> {
        let slice = slice_segment_pcm_padded(pcm, start_ms, end_ms, EMBED_CONTEXT_PAD_MS);
        if slice.is_empty() {
            return Err(DiarizationError::Internal(
                "segment produced no PCM samples".into(),
            ));
        }
        if pcm.sample_rate_hz != 16_000 || pcm.channels != 1 {
            return Err(DiarizationError::Internal(
                "ECAPA expects 16 kHz mono PCM".into(),
            ));
        }

        let flat = features_from_pcm_i16(&slice);
        if flat.is_empty() {
            return Err(DiarizationError::Internal(
                "segment too short for fbank features".into(),
            ));
        }
        let frames = flat.len() / 80;
        let features = Tensor::from_array(([1, frames, 80], flat))
            .map_err(|e| DiarizationError::Internal(e.to_string()))?;
        let feature_lens = Tensor::from_array(([1], vec![frames as f32]))
            .map_err(|e| DiarizationError::Internal(e.to_string()))?;

        let session = self
            .session
            .lock()
            .map_err(|_| DiarizationError::Internal("ECAPA session lock poisoned".into()))?;
        let inputs = ort::inputs!["features" => features, "feature_lens" => feature_lens]
            .map_err(|e| DiarizationError::Internal(e.to_string()))?;
        let outputs = session
            .run(inputs)
            .map_err(|e| DiarizationError::Internal(e.to_string()))?;

        let embedding_value = outputs.get("embedding").ok_or_else(|| {
            DiarizationError::Internal("ECAPA ONNX missing embedding output".into())
        })?;

        let (_shape, data) = embedding_value
            .try_extract_raw_tensor::<f32>()
            .map_err(|e| DiarizationError::Internal(e.to_string()))?;
        let mut out: SpeakerEmbedding = data.to_vec();
        l2_normalize(&mut out);
        Ok(out)
    }
}

fn l2_normalize(v: &mut [f32]) {
    let norm = v.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 0.0 {
        for x in v.iter_mut() {
            *x /= norm;
        }
    }
}
