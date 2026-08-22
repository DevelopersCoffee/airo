//! Minimal RIFF/WAVE reader for microphone recordings.
//!
//! Capability-side, not runtime-side: a container format is an input detail the
//! Meeting capability owns. `SpeechEngine` takes PCM and knows nothing about
//! files (`I6` — canonicalize once, at the boundary).
//!
//! Deliberately not a dependency. `hound` would do this, but it is a
//! Constitution §6 scorecard for eighty lines that will only ever read the one
//! format the recorder is configured to emit.

/// Decoded PCM, in the shape `AudioInput` wants.
#[derive(Debug)]
pub struct Pcm {
    pub samples: Vec<i16>,
    pub sample_rate_hz: u32,
    pub channels: u16,
}

fn u16_at(b: &[u8], i: usize) -> u16 {
    u16::from_le_bytes([b[i], b[i + 1]])
}

fn u32_at(b: &[u8], i: usize) -> u32 {
    u32::from_le_bytes([b[i], b[i + 1], b[i + 2], b[i + 3]])
}

/// Parses a 16-bit PCM WAVE file.
///
/// Walks the chunk list rather than assuming `data` sits at a fixed offset —
/// recorders emit `LIST`/`fact` chunks, and a hardcoded offset reads metadata
/// as audio and produces silence that looks like a model failure.
pub fn decode(bytes: &[u8]) -> Result<Pcm, String> {
    if bytes.len() < 12 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return Err("not a WAVE file".into());
    }

    let mut fmt: Option<(u16, u16, u32, u16)> = None;
    let mut data: Option<&[u8]> = None;
    let mut pos = 12usize;

    while pos + 8 <= bytes.len() {
        let id = &bytes[pos..pos + 4];
        let size = u32_at(bytes, pos + 4) as usize;
        let body_at = pos + 8;
        // A truncated final chunk is common when a recording is interrupted:
        // take what is there rather than refusing the whole file.
        let end = body_at.saturating_add(size).min(bytes.len());
        let body = &bytes[body_at.min(bytes.len())..end];

        match id {
            b"fmt " if body.len() >= 16 => {
                fmt = Some((
                    u16_at(body, 0),  // format tag
                    u16_at(body, 2),  // channels
                    u32_at(body, 4),  // sample rate
                    u16_at(body, 14), // bits per sample
                ));
            }
            b"data" => data = Some(body),
            _ => {}
        }

        // Chunks are word-aligned; an odd size carries a pad byte.
        pos = body_at + size + (size & 1);
    }

    let (tag, channels, sample_rate_hz, bits) = fmt.ok_or("WAVE file has no fmt chunk")?;
    let data = data.ok_or("WAVE file has no data chunk")?;

    // 1 = PCM, 0xFFFE = WAVE_FORMAT_EXTENSIBLE, which recorders emit for plain
    // PCM once there are more than two channels or an unusual bit depth.
    if tag != 1 && tag != 0xFFFE {
        return Err(format!("unsupported WAVE format tag {tag}, expected PCM"));
    }
    if bits != 16 {
        return Err(format!("expected 16-bit PCM, found {bits}-bit"));
    }
    if channels == 0 {
        return Err("WAVE file declares zero channels".into());
    }

    Ok(Pcm {
        samples: {
            // Clippy 1.98 prefers `as_chunks::<2>()`; keep `chunks_exact`
            // until the workspace pins a toolchain where that API is stable.
            #[allow(clippy::chunks_exact_to_as_chunks)]
            let pairs = data.chunks_exact(2);
            pairs.map(|p| i16::from_le_bytes([p[0], p[1]])).collect()
        },
        sample_rate_hz,
        channels,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Builds a WAVE file with an extra chunk before `data`, which is what a
    /// real recorder emits and what a fixed-offset reader gets wrong.
    fn wav(channels: u16, rate: u32, samples: &[i16], extra_chunk: bool) -> Vec<u8> {
        let mut body = Vec::new();
        body.extend_from_slice(b"WAVE");

        body.extend_from_slice(b"fmt ");
        body.extend_from_slice(&16u32.to_le_bytes());
        body.extend_from_slice(&1u16.to_le_bytes());
        body.extend_from_slice(&channels.to_le_bytes());
        body.extend_from_slice(&rate.to_le_bytes());
        body.extend_from_slice(&(rate * channels as u32 * 2).to_le_bytes());
        body.extend_from_slice(&(channels * 2).to_le_bytes());
        body.extend_from_slice(&16u16.to_le_bytes());

        if extra_chunk {
            // Odd size, to exercise the pad byte too.
            body.extend_from_slice(b"LIST");
            body.extend_from_slice(&3u32.to_le_bytes());
            body.extend_from_slice(&[1, 2, 3, 0]);
        }

        let pcm: Vec<u8> = samples.iter().flat_map(|s| s.to_le_bytes()).collect();
        body.extend_from_slice(b"data");
        body.extend_from_slice(&(pcm.len() as u32).to_le_bytes());
        body.extend_from_slice(&pcm);

        let mut out = Vec::new();
        out.extend_from_slice(b"RIFF");
        out.extend_from_slice(&(body.len() as u32).to_le_bytes());
        out.extend_from_slice(&body);
        out
    }

    #[test]
    fn reads_mono_16k_pcm() {
        let pcm = decode(&wav(1, 16_000, &[1, -2, 3], false)).unwrap();
        assert_eq!(pcm.samples, vec![1, -2, 3]);
        assert_eq!(pcm.sample_rate_hz, 16_000);
        assert_eq!(pcm.channels, 1);
    }

    /// The reason this walks chunks. A fixed offset would return the `LIST`
    /// bytes as audio — silence, which looks like a model failure rather than a
    /// parse failure.
    #[test]
    fn a_chunk_before_data_does_not_shift_the_audio() {
        let pcm = decode(&wav(1, 16_000, &[7, 8, 9], true)).unwrap();
        assert_eq!(pcm.samples, vec![7, 8, 9]);
    }

    #[test]
    fn stereo_is_reported_so_the_engine_can_downmix() {
        let pcm = decode(&wav(2, 44_100, &[1, 2, 3, 4], false)).unwrap();
        assert_eq!(pcm.channels, 2);
        assert_eq!(pcm.sample_rate_hz, 44_100);
    }

    /// An interrupted recording: the header claims more audio than the file
    /// holds. Salvage it rather than losing the meeting.
    #[test]
    fn a_truncated_recording_yields_the_audio_that_survived() {
        let mut bytes = wav(1, 16_000, &[1, 2, 3, 4, 5], false);
        bytes.truncate(bytes.len() - 4);
        let pcm = decode(&bytes).unwrap();
        assert_eq!(pcm.samples, vec![1, 2, 3]);
    }

    #[test]
    fn non_wave_input_is_an_error_not_a_panic() {
        assert!(decode(b"").is_err());
        assert!(decode(b"not audio at all").is_err());
        assert!(decode(&[0u8; 64]).is_err());
    }

    #[test]
    fn eight_bit_audio_is_refused_rather_than_misread() {
        let mut bytes = wav(1, 16_000, &[1, 2], false);
        // bits-per-sample sits at RIFF(8) + "WAVE"(4) + chunk header(8) + 14.
        bytes[12 + 8 + 14] = 8;
        assert!(decode(&bytes).unwrap_err().contains("8-bit"));
    }
}
