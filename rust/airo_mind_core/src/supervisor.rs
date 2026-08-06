//! The Supervisor.
//!
//! `C6`: *"every engine requests resources; the Supervisor grants them."*
//!
//! Scope is `#1396` — execute one pipeline. Two registration slots, not a
//! registry; two run methods, not a job graph. A generic engine registry would
//! not move the meeting pipeline this week, so it is backlog.

use crate::budget::ResourceBudget;
use crate::cancel::CancelToken;
use crate::engine::{
    AudioInput, EngineError, GenerationChunk, GenerationEngine, GenerationRequest, SpeechEngine,
    TranscriptSegment,
};

/// Why the Supervisor refused or stopped a job.
#[derive(Debug, PartialEq, Eq)]
pub enum RuntimeError {
    /// No engine registered for this task.
    NoEngine(&'static str),
    /// The engine needs more than the device budget allows. Refused **before**
    /// it allocates, which is the only point where this is recoverable —
    /// afterwards it is an OOM kill, and on Android that takes the whole app.
    OverBudget { needs_mb: u32, budget_mb: u32 },
    /// The engine stopped.
    Engine(EngineError),
}

impl std::fmt::Display for RuntimeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NoEngine(task) => write!(f, "no {task} engine registered"),
            Self::OverBudget {
                needs_mb,
                budget_mb,
            } => write!(f, "engine needs {needs_mb} MB, budget is {budget_mb} MB"),
            Self::Engine(e) => write!(f, "{e}"),
        }
    }
}

impl std::error::Error for RuntimeError {}

impl From<EngineError> for RuntimeError {
    fn from(e: EngineError) -> Self {
        Self::Engine(e)
    }
}

/// Owns the engines and the device budget.
///
/// **Control plane only** (`C6`). No audio, no transcript, no generated text is
/// stored here — every payload passes through a caller-supplied sink and the
/// Supervisor never holds it. That is what stops it becoming the single global
/// contention point every job waits on.
pub struct Supervisor {
    speech: Option<Box<dyn SpeechEngine>>,
    generation: Option<Box<dyn GenerationEngine>>,
    budget: ResourceBudget,
}

impl Supervisor {
    pub fn new(budget: ResourceBudget) -> Self {
        Self {
            speech: None,
            generation: None,
            budget,
        }
    }

    pub fn register_speech(&mut self, engine: Box<dyn SpeechEngine>) {
        self.speech = Some(engine);
    }

    pub fn register_generation(&mut self, engine: Box<dyn GenerationEngine>) {
        self.generation = Some(engine);
    }

    pub fn budget(&self) -> ResourceBudget {
        self.budget
    }

    /// Runs one speech job.
    ///
    /// Admission first, then execution. Segments reach the caller through
    /// `sink` as they are produced — the Supervisor does not accumulate them,
    /// so peak memory is the caller's choice rather than a property of the
    /// runtime (`I7`).
    pub fn run_speech(
        &self,
        audio: AudioInput<'_>,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), RuntimeError> {
        let engine = self
            .speech
            .as_ref()
            .ok_or(RuntimeError::NoEngine("speech"))?;
        self.admit(engine.resource_request().memory_mb)?;
        engine.transcribe(audio, cancel, sink)?;
        Ok(())
    }

    /// Runs one generation job.
    pub fn run_generation(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), RuntimeError> {
        let engine = self
            .generation
            .as_ref()
            .ok_or(RuntimeError::NoEngine("generation"))?;
        self.admit(engine.resource_request().memory_mb)?;
        engine.generate(request, cancel, sink)?;
        Ok(())
    }

    fn admit(&self, needs_mb: u32) -> Result<(), RuntimeError> {
        if self.budget.memory_mb < needs_mb {
            return Err(RuntimeError::OverBudget {
                needs_mb,
                budget_mb: self.budget.memory_mb,
            });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::budget::ResourceRequest;

    /// A deterministic speech engine. Splits a fixed number of segments so a
    /// test can assert exactly what a cancelled job produced, which a real
    /// backend cannot promise.
    struct FakeSpeech {
        segments: usize,
        memory_mb: u32,
    }

    impl SpeechEngine for FakeSpeech {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(self.memory_mb)
        }

        fn transcribe(
            &self,
            _audio: AudioInput<'_>,
            cancel: &CancelToken,
            sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            for i in 0..self.segments {
                // Checked BETWEEN segments: an engine holding a partially
                // decoded model cannot be killed safely mid-segment.
                if cancel.is_cancelled() {
                    return Err(EngineError::Cancelled);
                }
                sink(TranscriptSegment {
                    start_ms: (i as u64) * 1000,
                    end_ms: (i as u64 + 1) * 1000,
                    text: format!("segment {i}"),
                })?;
            }
            Ok(())
        }
    }

    struct FakeGeneration {
        memory_mb: u32,
    }

    impl GenerationEngine for FakeGeneration {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(self.memory_mb)
        }

        fn generate(
            &self,
            request: &GenerationRequest,
            cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            for word in request.prompt.split_whitespace().take(3) {
                if cancel.is_cancelled() {
                    return Err(EngineError::Cancelled);
                }
                sink(GenerationChunk {
                    text: word.to_string(),
                })?;
            }
            Ok(())
        }
    }

    fn audio() -> [i16; 4] {
        [0, 1, 2, 3]
    }

    fn supervisor(budget_mb: u32, engine_mb: u32) -> Supervisor {
        let mut s = Supervisor::new(ResourceBudget::new(budget_mb));
        s.register_speech(Box::new(FakeSpeech {
            segments: 3,
            memory_mb: engine_mb,
        }));
        s.register_generation(Box::new(FakeGeneration {
            memory_mb: engine_mb,
        }));
        s
    }

    /// `#1396` acceptance: the Supervisor executes one speech job.
    #[test]
    fn executes_one_speech_job() {
        let samples = audio();
        let s = supervisor(2048, 512);
        let mut out = Vec::new();
        s.run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &CancelToken::new(),
            &mut |seg| {
                out.push(seg);
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(out.len(), 3);
        assert_eq!(out[0].text, "segment 0");
    }

    /// `#1396` acceptance: the Supervisor executes one generation job.
    #[test]
    fn executes_one_generation_job() {
        let s = supervisor(2048, 512);
        let mut out = String::new();
        s.run_generation(
            &GenerationRequest {
                prompt: "agenda decisions actions owners".into(),
                max_output_tokens: 256,
            },
            &CancelToken::new(),
            &mut |chunk| {
                out.push_str(&chunk.text);
                out.push(' ');
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(out.trim(), "agenda decisions actions");
    }

    /// `#1396` acceptance: cancellation works.
    #[test]
    fn cancellation_stops_the_job_and_reports_it() {
        let samples = audio();
        let s = supervisor(2048, 512);
        let cancel = CancelToken::new();
        let mut out = Vec::new();

        let result = s.run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &cancel,
            &mut |seg| {
                out.push(seg);
                // Cancel from inside the sink: this is the UI navigating away
                // while the job runs, which is the case `C6` names.
                cancel.cancel();
                Ok(())
            },
        );

        assert_eq!(result, Err(RuntimeError::Engine(EngineError::Cancelled)));
        assert_eq!(
            out.len(),
            1,
            "a cancelled job must stop at the next boundary, not run to completion"
        );
    }

    /// `#1396` acceptance: resource budgeting works.
    #[test]
    fn an_engine_over_budget_is_refused_before_it_runs() {
        let samples = audio();
        // A 4 GB model on a 512 MB budget.
        let s = supervisor(512, 4096);
        let mut called = false;

        let result = s.run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &CancelToken::new(),
            &mut |_| {
                called = true;
                Ok(())
            },
        );

        assert_eq!(
            result,
            Err(RuntimeError::OverBudget {
                needs_mb: 4096,
                budget_mb: 512
            })
        );
        assert!(
            !called,
            "refusal must happen BEFORE the engine allocates -- afterwards it is an OOM kill"
        );
    }

    #[test]
    fn an_unregistered_engine_is_a_refusal_not_a_panic() {
        let samples = audio();
        let s = Supervisor::new(ResourceBudget::new(2048));
        let r = s.run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &CancelToken::new(),
            &mut |_| Ok(()),
        );
        assert_eq!(r, Err(RuntimeError::NoEngine("speech")));
    }

    /// Backpressure: a sink that refuses stops the engine. `C6` requires a
    /// producer faster than the consumer to be pushed back on rather than
    /// buffered without bound.
    #[test]
    fn a_refusing_sink_stops_the_engine() {
        let samples = audio();
        let s = supervisor(2048, 512);
        let mut seen = 0;
        let r = s.run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &CancelToken::new(),
            &mut |_| {
                seen += 1;
                Err(EngineError::Backend("sink full".into()))
            },
        );
        assert!(matches!(
            r,
            Err(RuntimeError::Engine(EngineError::Backend(_)))
        ));
        assert_eq!(seen, 1, "the engine must stop on the first refusal");
    }
}
