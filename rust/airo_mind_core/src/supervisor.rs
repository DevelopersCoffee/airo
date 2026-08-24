//! The Supervisor.
//!
//! `C6`: *"every engine requests resources; the Supervisor grants them."*
//!
//! Two concerns, both `C6`'s:
//!
//! - **Job execution** — `#1396`'s scope. Two registration slots (speech,
//!   generation), admission against a memory budget, cooperative
//!   cancellation. Unchanged by `#1302`.
//! - **Engine lifecycle** — `#1302`'s scope. An arbitrary number of stateful
//!   engines (Vault, Replay, Sync, Projection, ...) registered with
//!   dependencies, started, stopped, restarted, and shut down in dependency
//!   order. Delegated to [`crate::lifecycle::EngineRegistry`], which is where
//!   the algorithms live; this module is the single point both concerns are
//!   reached through, per `C6`'s *"one place"* framing.

use crate::budget::ResourceBudget;
use crate::cancel::CancelToken;
use crate::engine::{
    AudioInput, EngineError, GenerationChunk, GenerationEngine, GenerationRequest, RuntimeStats,
    SpeechEngine, TranscriptSegment, TranscriptionOptions,
};
use crate::lifecycle::{
    ConcurrencyLimiter, EngineMetrics, EngineName, EngineRegistry, EngineState, GroupCommitBuffer,
    LifecycleError, ManagedEngine,
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
    /// The concurrency cap (`C6`: *"resource limits ... concurrency caps"*)
    /// is already at capacity. Refused before the job starts, the same way
    /// `OverBudget` is — a job admitted then torn down mid-flight has already
    /// spent the CPU this cap exists to bound.
    OverCapacity { active: u32, max: u32 },
    /// The engine stopped.
    Engine(EngineError),
    /// A lifecycle operation (start/stop/restart on a managed engine)
    /// failed. See [`LifecycleError`] for the specific reason.
    Lifecycle(LifecycleError),
}

impl std::fmt::Display for RuntimeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NoEngine(task) => write!(f, "no {task} engine registered"),
            Self::OverBudget {
                needs_mb,
                budget_mb,
            } => write!(f, "engine needs {needs_mb} MB, budget is {budget_mb} MB"),
            Self::OverCapacity { active, max } => {
                write!(f, "{active} jobs already active, cap is {max}")
            }
            Self::Engine(e) => write!(f, "{e}"),
            Self::Lifecycle(e) => write!(f, "{e}"),
        }
    }
}

impl std::error::Error for RuntimeError {}

impl From<EngineError> for RuntimeError {
    fn from(e: EngineError) -> Self {
        Self::Engine(e)
    }
}

impl From<LifecycleError> for RuntimeError {
    fn from(e: LifecycleError) -> Self {
        Self::Lifecycle(e)
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
    concurrency: ConcurrencyLimiter,
    engines: EngineRegistry,
    shutdown_buffer: GroupCommitBuffer,
}

impl Supervisor {
    pub fn new(budget: ResourceBudget) -> Self {
        Self {
            speech: None,
            generation: None,
            budget,
            // Unbounded by default: existing callers (`#1396`'s meeting
            // pipeline) never set a cap, and a cap that appears under them
            // without being asked for would be a silent behavior change.
            concurrency: ConcurrencyLimiter::unbounded(),
            engines: EngineRegistry::new(),
            shutdown_buffer: GroupCommitBuffer::new(),
        }
    }

    /// Caps how many jobs (`run_speech` + `run_generation` combined) may run
    /// at once. `C6` / `#1302`: *"resource limits — memory ceilings and
    /// concurrency caps, enforced centrally."*
    pub fn with_max_concurrent_jobs(mut self, max: u32) -> Self {
        self.concurrency = ConcurrencyLimiter::new(max);
        self
    }

    pub fn register_speech(&mut self, engine: Box<dyn SpeechEngine>) {
        self.speech = Some(engine);
    }

    pub fn register_generation(&mut self, engine: Box<dyn GenerationEngine>) {
        self.generation = Some(engine);
    }

    /// Drops the registered generation engine, releasing whatever memory it
    /// holds. There is no separate "unload" verb on the Supervisor: the
    /// engine's own `Drop` (and, on `LlamaGenerationEngine`, its explicit
    /// `unload`) does the real free either way, and a `Box<dyn _>` cannot be
    /// asked to unload itself through the trait without widening
    /// `GenerationEngine` for every implementor just to serve one caller.
    pub fn unregister_generation(&mut self) {
        self.generation = None;
    }

    /// True when a generation engine is registered and can accept prompts.
    pub fn has_generation_engine(&self) -> bool {
        self.generation.is_some()
    }

    /// Stats from the registered generation engine's most recent `generate`
    /// call, or `None` if no generation engine is registered.
    pub fn generation_stats(&self) -> Option<RuntimeStats> {
        self.generation.as_ref().map(|e| e.stats())
    }

    pub fn budget(&self) -> ResourceBudget {
        self.budget
    }

    /// How many jobs are currently admitted and running.
    pub fn active_jobs(&self) -> u32 {
        self.concurrency.active()
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
        options: &TranscriptionOptions,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), RuntimeError> {
        let engine = self
            .speech
            .as_ref()
            .ok_or(RuntimeError::NoEngine("speech"))?;
        self.admit(engine.resource_request().memory_mb)?;
        let _slot = self.admit_concurrency()?;
        engine.transcribe(audio, options, cancel, sink)?;
        Ok(())
    }

    /// Refuses before a live session opens the microphone when the speech model
    /// cannot be admitted under the current budget (`ADR-0025` §6.6).
    pub fn check_speech_admission(&self) -> Result<(), RuntimeError> {
        let engine = self
            .speech
            .as_ref()
            .ok_or(RuntimeError::NoEngine("speech"))?;
        self.admit(engine.resource_request().memory_mb)?;
        Ok(())
    }

    /// Borrow the registered speech engine for windowed live inference.
    ///
    /// Callers must still route work through [`Self::run_speech`] when they need
    /// admission and concurrency enforcement per window.
    pub fn speech_engine(&self) -> Result<&dyn SpeechEngine, RuntimeError> {
        self.speech
            .as_deref()
            .ok_or(RuntimeError::NoEngine("speech"))
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
        let _slot = self.admit_concurrency()?;
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

    fn admit_concurrency(&self) -> Result<crate::lifecycle::ConcurrencySlot<'_>, RuntimeError> {
        self.concurrency
            .admit()
            .map_err(|(active, max)| RuntimeError::OverCapacity { active, max })
    }

    // -- Engine lifecycle (`C6`, `#1302`) -----------------------------------
    //
    // A second, independent registry from `speech`/`generation` above: those
    // are per-call job slots, these are long-lived stateful engines (Vault,
    // Replay, Sync, Projection, ...) with a dependency order between them.
    // See `crate::lifecycle` for why the two are not modeled the same way.

    /// Registers a stateful engine with the dependencies it needs `Running`
    /// before it may start. Panics on a duplicate name or an unregistered
    /// dependency — see [`EngineRegistry::register`].
    pub fn register_engine(
        &mut self,
        name: EngineName,
        depends_on: &[EngineName],
        engine: Box<dyn ManagedEngine>,
    ) {
        self.engines.register(name, depends_on, engine);
    }

    /// Starts one registered engine. Refuses with
    /// [`LifecycleError::DependencyNotReady`] if any dependency has not
    /// reached [`EngineState::Running`] — this is the enforcement point for
    /// *"Vault before Replay before Projection."*
    pub fn start_engine(&self, name: EngineName) -> Result<(), RuntimeError> {
        Ok(self.engines.start(name)?)
    }

    /// Stops one registered engine, ignoring dependency order. For an
    /// ordered stop of everything, use [`Self::shutdown`].
    pub fn stop_engine(&self, name: EngineName) -> Result<(), RuntimeError> {
        Ok(self.engines.stop(name)?)
    }

    /// Stops then starts one engine, touching no other engine's state. `C6` /
    /// S4: *"a failed engine restarts without corrupting the state of the
    /// engines around it."*
    pub fn restart_engine(&self, name: EngineName) -> Result<(), RuntimeError> {
        Ok(self.engines.restart(name)?)
    }

    pub fn engine_state(&self, name: EngineName) -> Option<EngineState> {
        self.engines.state_of(name)
    }

    /// Every registered engine's lifecycle state. `C6`: *"health — which
    /// engines are up, which are degraded."*
    pub fn health(&self) -> Vec<(EngineName, EngineState)> {
        self.engines.health()
    }

    /// Records one unit of work against an engine, feeding
    /// [`Self::engine_metrics`]'s operations count.
    pub fn record_op(&self, name: EngineName) {
        self.engines.record_op(name);
    }

    pub fn engine_metrics(&self, name: EngineName) -> Option<EngineMetrics> {
        self.engines.metrics_of(name)
    }

    /// Stops every running engine in reverse dependency order, then flushes
    /// and seals the group-commit buffer. `C6`: *"shutdown is graceful: the
    /// group-commit buffer flushes and the active segment seals."*
    ///
    /// The buffer here is [`crate::lifecycle::GroupCommitBuffer`], the stand-
    /// in for the operation log's real buffer until `#1338` lands it — see
    /// that type's docs for why the stand-in is where it is.
    pub fn shutdown(&self) {
        self.engines.shutdown_all();
        self.shutdown_buffer.flush();
        self.shutdown_buffer.seal();
    }

    /// Buffers a write the way the pending operation log would, ahead of its
    /// bounded group-commit window. Exposed so a caller — or a conformance
    /// test — can simulate pending work that [`Self::shutdown`] must not
    /// lose.
    pub fn buffer_write(&self, bytes: &[u8]) {
        self.shutdown_buffer.write(bytes);
    }

    /// What is durable after [`Self::shutdown`] — everything that was
    /// buffered via [`Self::buffer_write`], nothing more and nothing less.
    pub fn durable_buffer(&self) -> Vec<u8> {
        self.shutdown_buffer.durable()
    }

    pub fn buffer_sealed(&self) -> bool {
        self.shutdown_buffer.is_sealed()
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

    impl FakeSpeech {
        fn new(segments: usize, memory_mb: u32) -> Self {
            Self {
                segments,
                memory_mb,
            }
        }
    }

    impl SpeechEngine for FakeSpeech {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(self.memory_mb)
        }

        fn transcribe(
            &self,
            _audio: AudioInput<'_>,
            _options: &TranscriptionOptions,
            cancel: &CancelToken,
            sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            for i in 0..self.segments {
                // Checked BETWEEN segments: an engine holding a partially
                // decoded model cannot be killed safely mid-segment.
                if cancel.is_cancelled() {
                    return Err(EngineError::Cancelled);
                }
                sink(TranscriptSegment::final_text(
                    (i as u64) * 1000,
                    (i as u64 + 1) * 1000,
                    format!("segment {i}"),
                ))?;
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

        fn stats(&self) -> RuntimeStats {
            // Deterministic and cheap to construct is the point of a fake --
            // this fixture does not measure anything real.
            RuntimeStats::default()
        }
    }

    fn audio() -> [i16; 4] {
        [0, 1, 2, 3]
    }

    fn supervisor(budget_mb: u32, engine_mb: u32) -> Supervisor {
        let mut s = Supervisor::new(ResourceBudget::new(budget_mb));
        s.register_speech(Box::new(FakeSpeech::new(3, engine_mb)));
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
            &TranscriptionOptions::default(),
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

    /// `#1664`: a language hint passed to `run_speech` must reach the engine
    /// unchanged, not get dropped or defaulted away somewhere in between.
    #[test]
    fn run_speech_passes_the_language_hint_to_the_engine() {
        let samples = audio();
        let mut s = Supervisor::new(ResourceBudget::new(2048));

        // `Supervisor` owns the only `Box<dyn SpeechEngine>` handle, so the
        // engine reports what it saw through a shared `Arc<Mutex<_>>` rather
        // than being inspected after the fact.
        let observed = std::sync::Arc::new(std::sync::Mutex::new(None));
        struct ObservingSpeech {
            observed: std::sync::Arc<std::sync::Mutex<Option<TranscriptionOptions>>>,
        }
        impl SpeechEngine for ObservingSpeech {
            fn resource_request(&self) -> ResourceRequest {
                ResourceRequest::new(512)
            }
            fn transcribe(
                &self,
                _audio: AudioInput<'_>,
                options: &TranscriptionOptions,
                _cancel: &CancelToken,
                sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
            ) -> Result<(), EngineError> {
                *self.observed.lock().unwrap() = Some(options.clone());
                sink(TranscriptSegment::final_text(0, 100, "hi".into()))
            }
        }
        s.register_speech(Box::new(ObservingSpeech {
            observed: observed.clone(),
        }));

        s.run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &TranscriptionOptions {
                language: Some("hi".into()),
            },
            &CancelToken::new(),
            &mut |_| Ok(()),
        )
        .unwrap();

        assert_eq!(
            observed.lock().unwrap().clone(),
            Some(TranscriptionOptions {
                language: Some("hi".into())
            }),
            "the language hint must reach the engine's transcribe() call unchanged"
        );
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
                grammar: None,
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
            &TranscriptionOptions::default(),
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
            &TranscriptionOptions::default(),
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
    fn check_speech_admission_refuses_an_over_budget_engine() {
        let s = supervisor(512, 4096);
        assert_eq!(
            s.check_speech_admission(),
            Err(RuntimeError::OverBudget {
                needs_mb: 4096,
                budget_mb: 512
            })
        );
    }

    #[test]
    fn check_speech_admission_allows_an_in_budget_engine() {
        assert!(supervisor(2048, 512).check_speech_admission().is_ok());
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
            &TranscriptionOptions::default(),
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
            &TranscriptionOptions::default(),
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

    #[test]
    fn generation_stats_is_reachable_through_the_supervisor_and_none_when_unregistered() {
        let mut s = Supervisor::new(ResourceBudget::new(2048));
        assert_eq!(
            s.generation_stats(),
            None,
            "nothing registered yet -- there is nothing to report"
        );

        s.register_generation(Box::new(FakeGeneration { memory_mb: 512 }));
        assert_eq!(
            s.generation_stats(),
            Some(RuntimeStats::default()),
            "the fake does not measure itself, so its answer is the zero value"
        );
    }

    #[test]
    fn unregister_generation_drops_the_engine_and_the_next_run_is_refused() {
        let mut s = supervisor(2048, 512);
        s.unregister_generation();

        let r = s.run_generation(
            &GenerationRequest {
                prompt: "anything".into(),
                max_output_tokens: 8,
                grammar: None,
            },
            &CancelToken::new(),
            &mut |_| Ok(()),
        );
        assert_eq!(r, Err(RuntimeError::NoEngine("generation")));
        assert_eq!(s.generation_stats(), None);
    }
}
