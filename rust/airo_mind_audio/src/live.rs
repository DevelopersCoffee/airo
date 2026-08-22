//! Live speech orchestration above [`SpeechEngine`] — ring, VAD, stabilizer.

use airo_mind_core::cancel::CancelToken;
use airo_mind_core::engine::{
    AudioInput, EngineError, SpeechEngine, TranscriptSegment, TranscriptionOptions,
};

use crate::ring::{PcmRingBuffer, RingPushReport};
use crate::stabilizer::TranscriptStabilizer;
use crate::vad::{rms_energy, EnergyVad, VadState};
use crate::TARGET_SAMPLE_RATE;

/// Configuration for a live session pipeline.
#[derive(Clone, Debug)]
pub struct LiveSpeechConfig {
    /// Ring capacity in samples (~1–2 s of speech at 16 kHz is a starting point).
    pub ring_capacity_samples: usize,
    /// Inference window taken from the ring tail when speech is active.
    pub window_samples: usize,
    /// RMS energy threshold for [`EnergyVad`].
    pub vad_energy_threshold: f32,
    /// Silence duration (ms) that ends an utterance for stabilizer commit.
    pub vad_silence_ms: u64,
}

impl Default for LiveSpeechConfig {
    fn default() -> Self {
        Self {
            ring_capacity_samples: TARGET_SAMPLE_RATE as usize * 2,
            window_samples: TARGET_SAMPLE_RATE as usize / 2,
            vad_energy_threshold: 0.01,
            vad_silence_ms: 400,
        }
    }
}

/// Outcome of one [`LiveSpeechPipeline::step`].
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LiveStepReport {
    pub ring_push: RingPushReport,
    pub degraded: bool,
    pub vad_state: VadState,
    /// RMS energy of the inference window used this tick.
    pub window_energy: f32,
}

/// Native-owned PCM path: ring → VAD → bounded window → engine → stabilizer.
pub struct LiveSpeechPipeline {
    config: LiveSpeechConfig,
    ring: PcmRingBuffer,
    vad: EnergyVad,
    stabilizer: TranscriptStabilizer,
    elapsed_samples: u64,
}

impl LiveSpeechPipeline {
    pub fn new(config: LiveSpeechConfig) -> Self {
        let vad = EnergyVad::new(
            config.vad_energy_threshold,
            config.vad_silence_ms,
            TARGET_SAMPLE_RATE,
        );
        Self {
            ring: PcmRingBuffer::with_capacity_samples(config.ring_capacity_samples),
            vad,
            stabilizer: TranscriptStabilizer::new(),
            config,
            elapsed_samples: 0,
        }
    }

    pub fn push_pcm(&mut self, samples: &[i16]) -> RingPushReport {
        self.elapsed_samples += samples.len() as u64;
        self.ring.push(samples)
    }

    pub fn ring_dropped_samples(&self) -> u64 {
        self.ring.dropped_samples()
    }

    pub fn stabilizer(&self) -> &TranscriptStabilizer {
        &self.stabilizer
    }

    /// Run one pipeline tick using a caller-supplied transcribe hook so
    /// admission stays in [`airo_mind_core::Supervisor::run_speech`].
    pub fn step_with_transcribe(
        &mut self,
        transcribe: impl FnOnce(
            AudioInput<'_>,
            &TranscriptionOptions,
            &CancelToken,
            &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
        ) -> Result<(), EngineError>,
        options: &TranscriptionOptions,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<LiveStepReport, EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }

        let window = self.ring.tail(self.config.window_samples);
        let window_energy = rms_energy(&window);
        let vad_state = self.vad.process(&window);
        let ring_push = RingPushReport {
            accepted: 0,
            dropped: 0,
        };

        if vad_state == VadState::Speech && window.len() >= self.config.window_samples / 4 {
            let offset_ms = self.elapsed_samples.saturating_sub(window.len() as u64) * 1000
                / TARGET_SAMPLE_RATE as u64;
            transcribe(
                AudioInput {
                    samples: &window,
                    sample_rate_hz: TARGET_SAMPLE_RATE,
                    channels: 1,
                },
                options,
                cancel,
                &mut |seg| {
                    let adjusted = TranscriptSegment::new(
                        offset_ms + seg.start_ms,
                        offset_ms + seg.end_ms,
                        seg.text,
                        seg.state,
                    );
                    for event in self.stabilizer.on_engine_segment(adjusted) {
                        sink(event)?;
                    }
                    Ok(())
                },
            )?;
        }

        if vad_state == VadState::SpeechEnded {
            for event in self.stabilizer.on_speech_ended() {
                sink(event)?;
            }
        }

        Ok(LiveStepReport {
            ring_push,
            degraded: self.ring.dropped_samples() > 0,
            vad_state,
            window_energy,
        })
    }

    /// Run one pipeline tick: VAD on the latest window, optional engine pass,
    /// stabilizer events through `sink`.
    pub fn step(
        &mut self,
        engine: &dyn SpeechEngine,
        options: &TranscriptionOptions,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<LiveStepReport, EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }

        let window = self.ring.tail(self.config.window_samples);
        let window_energy = rms_energy(&window);
        let vad_state = self.vad.process(&window);
        let ring_push = RingPushReport {
            accepted: 0,
            dropped: 0,
        };

        if vad_state == VadState::Speech && window.len() >= self.config.window_samples / 4 {
            let offset_ms = self.elapsed_samples.saturating_sub(window.len() as u64) * 1000
                / TARGET_SAMPLE_RATE as u64;
            engine.transcribe(
                AudioInput {
                    samples: &window,
                    sample_rate_hz: TARGET_SAMPLE_RATE,
                    channels: 1,
                },
                options,
                cancel,
                &mut |seg| {
                    let adjusted = TranscriptSegment::new(
                        offset_ms + seg.start_ms,
                        offset_ms + seg.end_ms,
                        seg.text,
                        seg.state,
                    );
                    for event in self.stabilizer.on_engine_segment(adjusted) {
                        sink(event)?;
                    }
                    Ok(())
                },
            )?;
        }

        if vad_state == VadState::SpeechEnded {
            for event in self.stabilizer.on_speech_ended() {
                sink(event)?;
            }
        }

        Ok(LiveStepReport {
            ring_push,
            degraded: self.ring.dropped_samples() > 0,
            vad_state,
            window_energy,
        })
    }

    /// Flush remaining hypothesis and emit [`Final`] segments.
    pub fn finish(
        &mut self,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        for event in self.stabilizer.finalize() {
            sink(event)?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_core::budget::ResourceRequest;
    use airo_mind_core::engine::TranscriptSegmentState;

    struct WindowSpeech;

    impl SpeechEngine for WindowSpeech {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(512)
        }

        fn transcribe(
            &self,
            audio: AudioInput<'_>,
            _options: &TranscriptionOptions,
            _cancel: &CancelToken,
            sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            if audio.samples.is_empty() {
                return Ok(());
            }
            sink(TranscriptSegment::final_text(0, 100, "live".into()))?;
            Ok(())
        }
    }

    fn loud_pcm(n: usize) -> Vec<i16> {
        vec![12_000; n]
    }

    fn silent_pcm(n: usize) -> Vec<i16> {
        vec![0; n]
    }

    #[test]
    fn pipeline_emits_partial_then_stable_on_silence() {
        let config = LiveSpeechConfig {
            ring_capacity_samples: 16_000,
            window_samples: 4_800,
            vad_energy_threshold: 0.01,
            vad_silence_ms: 300,
        };
        let mut pipe = LiveSpeechPipeline::new(config);
        let engine = WindowSpeech;
        let cancel = CancelToken::new();
        let mut events = Vec::new();

        pipe.push_pcm(&loud_pcm(8_000));
        pipe.step(
            &engine,
            &TranscriptionOptions::default(),
            &cancel,
            &mut |seg| {
                events.push(seg);
                Ok(())
            },
        )
        .unwrap();

        assert!(
            events
                .iter()
                .any(|s| s.state == TranscriptSegmentState::Partial),
            "expected partial from engine window"
        );

        pipe.push_pcm(&silent_pcm(8_000));
        pipe.step(
            &engine,
            &TranscriptionOptions::default(),
            &cancel,
            &mut |seg| {
                events.push(seg);
                Ok(())
            },
        )
        .unwrap();

        assert!(
            events
                .iter()
                .any(|s| s.state == TranscriptSegmentState::Stable),
            "expected stable after silence boundary"
        );
    }

    #[test]
    fn ring_overflow_marks_step_degraded() {
        let config = LiveSpeechConfig {
            ring_capacity_samples: 64,
            window_samples: 32,
            vad_energy_threshold: 0.01,
            vad_silence_ms: 300,
        };
        let mut pipe = LiveSpeechPipeline::new(config);
        let engine = WindowSpeech;
        let cancel = CancelToken::new();

        pipe.push_pcm(&loud_pcm(256));
        assert!(pipe.ring_dropped_samples() > 0, "ring should drop oldest");

        let report = pipe
            .step(
                &engine,
                &TranscriptionOptions::default(),
                &cancel,
                &mut |_| Ok(()),
            )
            .unwrap();
        assert!(report.degraded, "overflow should mark step degraded");
    }
}
