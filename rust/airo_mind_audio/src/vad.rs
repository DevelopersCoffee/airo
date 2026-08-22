//! Lightweight energy VAD for live speech gating.

/// Voice-activity state after processing one PCM chunk.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VadState {
    Silence,
    Speech,
    /// Speech ended after a silence run long enough to commit a clause.
    SpeechEnded,
}

/// RMS energy gate with hysteresis via a silence-run counter.
pub struct EnergyVad {
    threshold: f32,
    silence_samples_required: usize,
    speech_active: bool,
    silence_run: usize,
}

impl EnergyVad {
    pub fn new(threshold: f32, silence_ms: u64, sample_rate_hz: u32) -> Self {
        let silence_samples_required =
            (sample_rate_hz as u64 * silence_ms / 1000).max(1) as usize;
        Self {
            threshold,
            silence_samples_required,
            speech_active: false,
            silence_run: 0,
        }
    }

    pub fn speech_active(&self) -> bool {
        self.speech_active
    }

    pub fn process(&mut self, samples: &[i16]) -> VadState {
        if samples.is_empty() {
            return VadState::Silence;
        }
        let energy = rms_energy(samples);
        if energy >= self.threshold {
            self.speech_active = true;
            self.silence_run = 0;
            return VadState::Speech;
        }

        if self.speech_active {
            self.silence_run += samples.len();
            if self.silence_run >= self.silence_samples_required {
                self.speech_active = false;
                self.silence_run = 0;
                return VadState::SpeechEnded;
            }
            return VadState::Speech;
        }

        VadState::Silence
    }
}

fn rms_energy(samples: &[i16]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    let sum: f64 = samples
        .iter()
        .map(|s| {
            let v = f64::from(*s) / 32_768.0;
            v * v
        })
        .sum();
    (sum / samples.len() as f64).sqrt() as f32
}

#[cfg(test)]
mod tests {
    use super::*;

    fn loud_chunk() -> Vec<i16> {
        vec![10_000; 320]
    }

    fn silent_chunk() -> Vec<i16> {
        vec![0; 320]
    }

    #[test]
    fn silence_then_speech_then_end() {
        let mut vad = EnergyVad::new(0.01, 300, 16_000);
        assert_eq!(vad.process(&silent_chunk()), VadState::Silence);
        assert_eq!(vad.process(&loud_chunk()), VadState::Speech);
        // 300 ms silence at 16 kHz needs 4_800 samples; keep feeding silence until end.
        let mut state = VadState::Speech;
        for _ in 0..20 {
            state = vad.process(&silent_chunk());
            if state == VadState::SpeechEnded {
                break;
            }
        }
        assert_eq!(state, VadState::SpeechEnded);
        assert!(!vad.speech_active());
    }
}
