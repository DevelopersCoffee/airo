//! Deterministic test embedder — no ONNX, no network.

use airo_mind_core::wav::Pcm;

use crate::diarizer::DiarizationError;
use crate::embedder::{SpeakerEmbedder, SpeakerEmbedding};
use crate::pcm_slice::slice_segment_pcm;

/// Hash-derived 8-D embeddings for dev/tests. Same segment audio → same vector.
#[derive(Clone, Copy, Debug, Default)]
pub struct StubSpeakerEmbedder {
    pub dims: usize,
}

impl StubSpeakerEmbedder {
    pub fn new(dims: usize) -> Self {
        Self { dims: dims.max(1) }
    }
}

impl SpeakerEmbedder for StubSpeakerEmbedder {
    fn embed_segment(
        &self,
        pcm: &Pcm,
        start_ms: u64,
        end_ms: u64,
    ) -> Result<SpeakerEmbedding, DiarizationError> {
        let slice = slice_segment_pcm(pcm, start_ms, end_ms);
        if slice.is_empty() {
            return Err(DiarizationError::Internal(
                "segment produced no PCM samples".into(),
            ));
        }

        let mut seed = 0u64;
        for sample in slice.iter().take(256) {
            seed = seed.wrapping_mul(31).wrapping_add(*sample as u64);
        }
        seed = seed.wrapping_add(start_ms).wrapping_add(end_ms);

        let mut out = Vec::with_capacity(self.dims);
        for i in 0..self.dims {
            let bit = ((seed >> (i % 32)) & 0xff) as f32 / 255.0;
            out.push(bit);
        }
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
