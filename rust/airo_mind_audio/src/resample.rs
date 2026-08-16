use rubato::{FftFixedIn, Resampler};

use crate::{TARGET_CHANNELS, TARGET_SAMPLE_RATE};

/// Downmix interleaved PCM to mono `f32` in `[-1.0, 1.0]`.
pub fn downmix_to_mono_f32(samples: &[i16], channels: u16) -> Result<Vec<f32>, String> {
    let channels = usize::from(channels);
    if channels == 0 {
        return Err("zero channels".into());
    }
    Ok(samples
        .chunks(channels)
        .map(|frame| {
            let sum: f32 = frame.iter().map(|s| f32::from(*s) / 32_768.0).sum();
            sum / channels as f32
        })
        .collect())
}

/// Resample mono `f32` audio to [TARGET_SAMPLE_RATE].
pub fn resample_mono_to_16k(input: &[f32], source_rate_hz: u32) -> Result<Vec<f32>, String> {
    if source_rate_hz == TARGET_SAMPLE_RATE {
        return Ok(input.to_vec());
    }
    if input.is_empty() {
        return Ok(Vec::new());
    }
    if source_rate_hz == 0 {
        return Err("zero sample rate".into());
    }

    let chunk_size = 1024usize;
    let mut resampler = FftFixedIn::<f64>::new(
        source_rate_hz as usize,
        TARGET_SAMPLE_RATE as usize,
        chunk_size,
        2,
        1,
    )
    .map_err(|e| format!("resampler init: {e}"))?;

    let input_f64: Vec<f64> = input.iter().map(|s| f64::from(*s)).collect();
    let mut out = Vec::new();
    let mut pos = 0usize;

    while pos < input_f64.len() {
        let end = (pos + chunk_size).min(input_f64.len());
        let mut chunk = input_f64[pos..end].to_vec();
        if chunk.len() < chunk_size {
            chunk.resize(chunk_size, 0.0);
        }
        let waves_out = resampler
            .process(&[chunk], None)
            .map_err(|e| format!("resample: {e}"))?;
        let produced = waves_out[0].len();
        let valid = if end == input_f64.len() && end - pos < chunk_size {
            ((produced as f64) * (end - pos) as f64 / chunk_size as f64).round() as usize
        } else {
            produced
        };
        out.extend(waves_out[0].iter().take(valid).map(|s| *s as f32));
        pos = end;
    }

    let expected_len =
        ((input.len() as f64) * TARGET_SAMPLE_RATE as f64 / source_rate_hz as f64).round() as usize;
    out.truncate(expected_len);
    Ok(out)
}

pub fn float_to_i16(samples: &[f32]) -> Vec<i16> {
    samples
        .iter()
        .map(|s| (s.clamp(-1.0, 1.0) * 32_767.0).round() as i16)
        .collect()
}

/// Convert decoded PCM (any rate/channels) to whisper's required shape.
pub fn normalize_pcm(
    samples: Vec<i16>,
    sample_rate_hz: u32,
    channels: u16,
) -> Result<airo_mind_core::wav::Pcm, String> {
    let mono = downmix_to_mono_f32(&samples, channels)?;
    let resampled = resample_mono_to_16k(&mono, sample_rate_hz)?;
    Ok(airo_mind_core::wav::Pcm {
        samples: float_to_i16(&resampled),
        sample_rate_hz: TARGET_SAMPLE_RATE,
        channels: TARGET_CHANNELS,
    })
}
