//! Slice 16 kHz mono PCM to a segment's time bounds.

use airo_mind_core::wav::Pcm;

/// Returns samples covering [start_ms, end_ms] from [pcm], clamped to audio length.
pub fn slice_segment_pcm(pcm: &Pcm, start_ms: u64, end_ms: u64) -> Vec<i16> {
    if pcm.sample_rate_hz == 0 || pcm.samples.is_empty() {
        return Vec::new();
    }

    let rate = pcm.sample_rate_hz as u64;
    let start_sample = (start_ms * rate / 1000) as usize * pcm.channels as usize;
    let end_sample = ((end_ms * rate / 1000) as usize * pcm.channels as usize)
        .min(pcm.samples.len());
    if end_sample <= start_sample {
        return Vec::new();
    }
    pcm.samples[start_sample..end_sample].to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slices_mono_segment() {
        let pcm = Pcm {
            samples: (0..48_000).map(|i| i as i16).collect(),
            sample_rate_hz: 16_000,
            channels: 1,
        };
        let slice = slice_segment_pcm(&pcm, 500, 1_500);
        assert_eq!(slice.len(), 16_000); // 1 second at 16 kHz
    }
}
