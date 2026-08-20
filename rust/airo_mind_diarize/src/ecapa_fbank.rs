//! SpeechBrain-compatible log-fbank features for the vedk00 ECAPA ONNX export.

use std::f32::consts::PI;
use std::sync::OnceLock;

use realfft::RealFftPlanner;

const N_FFT: usize = 400;
const WIN_LENGTH: usize = 400;
const HOP_LENGTH: usize = 160;
const N_MELS: usize = 80;
const N_FREQ_BINS: usize = 201;

fn filterbank_matrix() -> &'static [f32] {
    static MATRIX: OnceLock<Vec<f32>> = OnceLock::new();
    MATRIX.get_or_init(|| {
        const BYTES: &[u8] = include_bytes!("../../fixtures/speaker/ecapa_fbank_80x201_f32.bin");
        let mut out = Vec::with_capacity(N_MELS * N_FREQ_BINS);
        for chunk in BYTES.chunks_exact(4) {
            out.push(f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]));
        }
        out
    })
}

/// Computes `[frames, 80]` log-fbank features with per-utterance mean subtraction.
pub fn features_from_pcm_i16(samples: &[i16]) -> Vec<f32> {
    if samples.len() < WIN_LENGTH {
        return Vec::new();
    }

    let matrix = filterbank_matrix();
    let floats: Vec<f32> = samples
        .iter()
        .map(|s| *s as f32 / i16::MAX as f32)
        .collect();
    let window = hamming(WIN_LENGTH);
    let mut planner = RealFftPlanner::new();
    let r2c = planner.plan_fft_forward(N_FFT);
    let mut scratch = r2c.make_scratch_vec();
    let mut frame = vec![0.0f32; N_FFT];
    let mut spectrum = r2c.make_output_vec();

    let mut rows: Vec<Vec<f32>> = Vec::new();
    for start in (0..floats.len() - WIN_LENGTH + 1).step_by(HOP_LENGTH) {
        for (dst, (sample, w)) in frame
            .iter_mut()
            .zip(floats[start..].iter().zip(window.iter()))
            .take(WIN_LENGTH)
        {
            *dst = *sample * *w;
        }
        r2c.process_with_scratch(&mut frame, &mut spectrum, &mut scratch)
            .expect("rfft");

        let mut mel = vec![0.0f32; N_MELS];
        for (mel_idx, bin_out) in mel.iter_mut().enumerate() {
            let row_offset = mel_idx * N_FREQ_BINS;
            let mut acc = 0.0f32;
            for (bin, coeff) in spectrum.iter().zip(&matrix[row_offset..]).take(N_FREQ_BINS) {
                acc += *coeff * bin.norm_sqr();
            }
            *bin_out = ln_floor(acc);
        }
        rows.push(mel);
    }

    if rows.is_empty() {
        return Vec::new();
    }

    let frames = rows.len();
    let mut out = Vec::with_capacity(frames * N_MELS);
    let mut means = vec![0.0f32; N_MELS];
    for row in &rows {
        for (idx, value) in row.iter().enumerate() {
            means[idx] += *value;
        }
    }
    for mean in &mut means {
        *mean /= frames as f32;
    }
    for row in rows {
        for (idx, value) in row.iter().enumerate() {
            out.push(*value - means[idx]);
        }
    }
    out
}

fn hamming(len: usize) -> Vec<f32> {
    (0..len)
        .map(|i| 0.54 - 0.46 * (2.0 * PI * i as f32 / (len as f32 - 1.0)).cos())
        .collect()
}

fn ln_floor(value: f32) -> f32 {
    value.max(1e-10).ln()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_features_are_reproducible() {
        let mut samples = Vec::with_capacity(48_000);
        let mut state = 42u64;
        for _ in 0..48_000 {
            state = state.wrapping_mul(6364136223846793005).wrapping_add(1);
            let normalized = (state >> 33) as f32 / u32::MAX as f32;
            samples.push((normalized * 0.05 * i16::MAX as f32) as i16);
        }
        let feats = features_from_pcm_i16(&samples);
        let again = features_from_pcm_i16(&samples);
        assert_eq!(feats, again);
        assert_eq!(feats.len(), 298 * N_MELS);
        assert!(feats.iter().all(|v| v.is_finite()));
    }
}
