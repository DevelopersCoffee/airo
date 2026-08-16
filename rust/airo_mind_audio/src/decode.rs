use std::io::Cursor;

use symphonia::core::audio::SampleBuffer;
use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::errors::Error;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;

use crate::resample::normalize_pcm;

/// Demux and decode a compressed or non-PCM container via symphonia.
pub fn decode_container(bytes: &[u8], extension_hint: Option<&str>) -> Result<crate::Pcm, String> {
    let mss = MediaSourceStream::new(
        Box::new(Cursor::new(bytes.to_vec())),
        Default::default(),
    );

    let mut hint = Hint::new();
    if let Some(ext) = extension_hint {
        hint.with_extension(ext);
    }

    let probed = symphonia::default::get_probe()
        .format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )
        .map_err(|e| format!("probe audio: {e}"))?;

    let mut format = probed.format;
    let track = format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
        .ok_or("no audio track found")?;

    let sample_rate_hz = track
        .codec_params
        .sample_rate
        .ok_or("audio track has no sample rate")?;
    let channels = track
        .codec_params
        .channels
        .map(|c| c.count() as u16)
        .unwrap_or(1);

    let mut decoder = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|e| format!("open decoder: {e}"))?;

    let track_id = track.id;
    let mut interleaved_f32: Vec<f32> = Vec::new();

    loop {
        let packet = match format.next_packet() {
            Ok(packet) => packet,
            Err(Error::ResetRequired) => {
                decoder.reset();
                continue;
            }
            Err(_) => break,
        };

        if packet.track_id() != track_id {
            continue;
        }

        let decoded = decoder
            .decode(&packet)
            .map_err(|e| format!("decode packet: {e}"))?;

        let spec = *decoded.spec();
        let mut sample_buf = SampleBuffer::<f32>::new(decoded.frames() as u64, spec);
        sample_buf.copy_interleaved_ref(decoded);
        interleaved_f32.extend_from_slice(sample_buf.samples());
    }

    if interleaved_f32.is_empty() {
        return Err("no audio samples decoded".into());
    }

    let i16_samples = f32_interleaved_to_i16(&interleaved_f32);
    normalize_pcm(i16_samples, sample_rate_hz, channels)
}

fn f32_interleaved_to_i16(samples: &[f32]) -> Vec<i16> {
    samples
        .iter()
        .map(|s| (s.clamp(-1.0, 1.0) * 32_767.0).round() as i16)
        .collect()
}
