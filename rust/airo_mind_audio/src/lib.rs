//! Cross-platform audio preprocess for Airo Mind whisper input.
//!
//! Meeting capture writes AAC `.m4a`; dev fixtures may be WAV. Everything
//! that reaches `SpeechEngine` must be **16 kHz mono 16-bit PCM** — this
//! crate owns container decode, downmix, and resample. Lives outside
//! `airo_mind_core` so the runtime core stays std-only.

#![deny(unsafe_code)]

mod decode;
mod fanout;
mod governor;
mod live;
mod probes;
mod resample;
mod ring;
mod speaker_activity;
mod stabilizer;
mod vad;
mod wav_write;

pub use airo_mind_core::wav;
pub use airo_mind_core::wav::Pcm;

pub const TARGET_SAMPLE_RATE: u32 = 16_000;
pub const TARGET_CHANNELS: u16 = 1;

pub use fanout::{CaptureFanout, FanoutReport};
pub use governor::{
    BatteryBand, IntelligencePolicy, LiveAdmission, ResourceGovernor, ResourceSnapshot, ThermalBand,
};
pub use live::{LiveSpeechConfig, LiveSpeechPipeline, LiveStepReport};
pub use probes::{
    parse_meminfo_mb, parse_pmset_battery_percent, parse_sysctl_memsize_mb,
    parse_vm_stat_available_mb, parse_wmic_battery_percent, parse_wmic_memory_mb,
    probe_resource_snapshot, thermal_from_millideg_c,
};
pub use ring::{PcmRingBuffer, RingPushReport};
pub use speaker_activity::{SpeakerActivitySlice, SpeakerActivityTracker};
pub use stabilizer::TranscriptStabilizer;
pub use vad::{rms_energy, EnergyVad, VadState};
pub use wav_write::IncrementalWavWriter;

/// Read [path] and return whisper-ready PCM.
pub fn preprocess_path(path: &std::path::Path) -> Result<Pcm, String> {
    let bytes = std::fs::read(path).map_err(|e| format!("reading {}: {e}", path.display()))?;
    let extension = path.extension().and_then(|s| s.to_str());
    preprocess_bytes(&bytes, extension)
}

/// Decode in-memory audio. [extension_hint] helps symphonia probe (e.g. `"m4a"`).
pub fn preprocess_bytes(bytes: &[u8], extension_hint: Option<&str>) -> Result<Pcm, String> {
    if bytes.is_empty() {
        return Err("empty audio input".into());
    }

    if let Ok(pcm) = wav::decode(bytes) {
        if pcm.sample_rate_hz == TARGET_SAMPLE_RATE && pcm.channels == TARGET_CHANNELS {
            return Ok(pcm);
        }
        return resample::normalize_pcm(pcm.samples, pcm.sample_rate_hz, pcm.channels);
    }

    decode::decode_container(bytes, extension_hint)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_input_is_rejected() {
        assert!(preprocess_bytes(&[], None).is_err());
    }

    #[test]
    fn garbage_is_rejected() {
        assert!(preprocess_bytes(b"not audio", Some("m4a")).is_err());
    }
}
