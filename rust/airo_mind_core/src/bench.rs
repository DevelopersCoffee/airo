//! Generation-engine benchmark protocol.
//!
//! Backend-free: this crate links nothing native, so the protocol can sit in
//! `airo_mind_core` and be shared by llama.cpp, a future CUDA Windows build,
//! and tests that never load a model.
//!
//! The methodology is the Jan.ai kernel-bench practices that survive contact
//! with on-device inference, not a port of CUDA events / `ncu` / L2 flush:
//!
//! 1. Measure on the hardware that will serve the user.
//! 2. Warm up, then time (shader compile / mmap / graph build stay out of
//!    the reported number).
//! 3. Report **median** of N timed runs, not a single shot.
//! 4. Split prefill (TTFT) from decode (tok/s) — they are different kernels
//!    in cost profile, even when they share one `generate()` call.
//! 5. Record the accelerator and clock policy with the number, so a CUDA
//!    Windows run and a Metal macOS run cannot be compared as if they were
//!    the same measurement.
//!
//! Absolute tok/s is still not a CI gate. Stochastic clocks (Jan §6) make
//! wall-clock thresholds flaky; [`crate`] scaling tests stay the CI shape.

use crate::cancel::CancelToken;
use crate::engine::{EngineError, GenerationEngine, GenerationRequest, RuntimeStats};

/// GPU / NPU / CPU accelerator the timed `generate()` actually used.
///
/// [`AccelBackend::Cuda`] is a first-class member so Windows CUDA testing can
/// attach this label without a protocol change. This crate does not link
/// CUDA; `airo_mind_llama`'s optional `cuda` feature is the future load path.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum AccelBackend {
    #[default]
    None,
    Metal,
    OpenCl,
    Vulkan,
    Cuda,
    Auto,
}

/// How GPU clocks were treated for this run.
///
/// Jan's `ncu --clock-control` lesson: locking to base under-reports what
/// users see; locking to max is only a ceiling; unlocked boost is stochastic.
/// Record which policy was used rather than pretending the number is absolute.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum GpuClockControl {
    /// Do not lock clocks. Default, and the one that matches user experience
    /// on phones, TVs, and a Windows CUDA box that is not under `ncu`.
    #[default]
    Unlocked,
    /// Lock to base clock. For later `ncu`-style comparisons on Windows CUDA.
    Base,
    /// Lock to advertised boost. Ceiling only — the GPU may still drop.
    MaxBoost,
}

/// Which headline this report is answering.
///
/// Both numbers are always collected from the same warmed timed runs. The
/// mode records which one a caller asked to treat as the comparison key.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum BenchMode {
    /// Prefill median (`first_token_ms`) and decode median (`tokens_per_second`)
    /// from the same warmed timed runs. Default for Model Bench.
    #[default]
    Combined,
    /// Headline is cold-prompt TTFT (prefill).
    ColdPrompt,
    /// Headline is steady decode tok/s.
    SteadyDecode,
}

/// How many discarded warmup calls and how many timed calls to make.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BenchProtocol {
    pub warmup_iterations: u32,
    pub timed_iterations: u32,
}

impl Default for BenchProtocol {
    fn default() -> Self {
        Self {
            warmup_iterations: 3,
            timed_iterations: 5,
        }
    }
}

impl BenchProtocol {
    pub fn total_iterations(&self) -> u32 {
        self.warmup_iterations.saturating_add(self.timed_iterations)
    }
}

/// Hardware / engine settings that make a tok/s figure interpretable.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BenchMetadata {
    pub backend: AccelBackend,
    pub clock_control: GpuClockControl,
    /// Layers offloaded to the GPU. `0` is CPU. `-1` means all layers.
    pub gpu_layers: i32,
    pub thread_count: u32,
    pub mode: BenchMode,
}

impl Default for BenchMetadata {
    fn default() -> Self {
        Self {
            backend: AccelBackend::None,
            clock_control: GpuClockControl::Unlocked,
            gpu_layers: 0,
            thread_count: 1,
            mode: BenchMode::Combined,
        }
    }
}

/// Aggregated result of a warmed, median-reduced generation bench.
#[derive(Clone, Debug, PartialEq)]
pub struct BenchReport {
    pub median_tokens_per_second: f64,
    pub median_first_token_ms: u64,
    pub peak_rss_bytes: u64,
    pub prompt_tokens: u32,
    pub generated_tokens: u32,
    pub warmup_iterations: u32,
    pub timed_iterations: u32,
    pub metadata: BenchMetadata,
}

#[derive(Debug, PartialEq, Eq)]
pub enum BenchError {
    /// Timed loop produced no samples — a protocol misconfiguration, not a
    /// slow model.
    NoSamples,
    Engine(EngineError),
}

impl std::fmt::Display for BenchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NoSamples => write!(
                f,
                "benchmark produced no timed samples (timed_iterations must be > 0)"
            ),
            Self::Engine(e) => write!(f, "benchmark engine failed: {e}"),
        }
    }
}

impl std::error::Error for BenchError {}

impl From<EngineError> for BenchError {
    fn from(value: EngineError) -> Self {
        Self::Engine(value)
    }
}

/// Median of floating-point samples. Empty → `0.0`.
///
/// Even-length slices use the mean of the two central values, matching the
/// Jan.py `statistics.median` convention used in their `do_bench_cuda`.
pub fn median_f64(values: &[f64]) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let n = sorted.len();
    if n % 2 == 1 {
        sorted[n / 2]
    } else {
        (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    }
}

/// Median of integer samples. Empty → `0`. Even-length uses truncated mean
/// of the two central values.
pub fn median_u64(values: &[u64]) -> u64 {
    if values.is_empty() {
        return 0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_unstable();
    let n = sorted.len();
    if n % 2 == 1 {
        sorted[n / 2]
    } else {
        sorted[n / 2 - 1] / 2 + sorted[n / 2] / 2 + (sorted[n / 2 - 1] % 2 + sorted[n / 2] % 2) / 2
    }
}

/// Reduce timed [`RuntimeStats`] samples into a [`BenchReport`].
///
/// Warmup samples must already have been discarded by the caller. An empty
/// slice is [`BenchError::NoSamples`] rather than a zeroed report — zeros
/// would look like a real measurement of a model that produced nothing.
pub fn aggregate(
    samples: &[RuntimeStats],
    protocol: &BenchProtocol,
    metadata: BenchMetadata,
) -> Result<BenchReport, BenchError> {
    if samples.is_empty() {
        return Err(BenchError::NoSamples);
    }
    let tok_s: Vec<f64> = samples.iter().map(|s| s.tokens_per_second).collect();
    let ttft: Vec<u64> = samples.iter().map(|s| s.prefill_ms).collect();
    let prompt_tokens = samples.iter().map(|s| s.prefill_tokens).max().unwrap_or(0);
    let generated_tokens = samples
        .iter()
        .map(|s| s.generated_tokens)
        .max()
        .unwrap_or(0);
    let peak_rss_bytes = samples.iter().map(|s| s.peak_rss_bytes).max().unwrap_or(0);
    Ok(BenchReport {
        median_tokens_per_second: median_f64(&tok_s),
        median_first_token_ms: median_u64(&ttft),
        peak_rss_bytes,
        prompt_tokens,
        generated_tokens,
        warmup_iterations: protocol.warmup_iterations,
        timed_iterations: protocol.timed_iterations,
        metadata,
    })
}

/// Run `warmup_iterations` discarded `generate()` calls, then
/// `timed_iterations` measured ones, and aggregate the timed [`RuntimeStats`].
///
/// Each call is a full prefill+decode. Prefill median is the cold-prompt
/// TTFT; decode tok/s is the generation half. The engine's own KV cache is
/// not flushed between calls — that is realistic for repeated chat turns
/// after warmup, and the opposite of Jan's GPU L2 flush, which would
/// *un*-measure the decode path users actually hit.
pub fn run_generation_bench(
    engine: &dyn GenerationEngine,
    request: &GenerationRequest,
    protocol: &BenchProtocol,
    metadata: BenchMetadata,
    cancel: &CancelToken,
) -> Result<BenchReport, BenchError> {
    if protocol.timed_iterations == 0 {
        return Err(BenchError::NoSamples);
    }
    let mut sink = |_chunk: crate::engine::GenerationChunk| Ok(());
    for _ in 0..protocol.warmup_iterations {
        if cancel.is_cancelled() {
            return Err(BenchError::Engine(EngineError::Cancelled));
        }
        engine.generate(request, cancel, &mut sink)?;
    }
    let mut samples = Vec::with_capacity(protocol.timed_iterations as usize);
    for _ in 0..protocol.timed_iterations {
        if cancel.is_cancelled() {
            return Err(BenchError::Engine(EngineError::Cancelled));
        }
        engine.generate(request, cancel, &mut sink)?;
        samples.push(engine.stats());
    }
    aggregate(&samples, protocol, metadata)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::budget::ResourceRequest;
    use crate::engine::{GenerationChunk, GenerationEngine};
    use std::sync::atomic::{AtomicU32, Ordering};
    use std::sync::Mutex;

    struct ScriptedGeneration {
        remaining: Mutex<Vec<RuntimeStats>>,
        last: Mutex<RuntimeStats>,
        calls: AtomicU32,
    }

    impl ScriptedGeneration {
        fn new(samples: Vec<RuntimeStats>) -> Self {
            Self {
                remaining: Mutex::new(samples),
                last: Mutex::new(RuntimeStats::default()),
                calls: AtomicU32::new(0),
            }
        }
    }

    impl GenerationEngine for ScriptedGeneration {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(64)
        }

        fn generate(
            &self,
            _request: &GenerationRequest,
            cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }
            self.calls.fetch_add(1, Ordering::SeqCst);
            let next = {
                let mut remaining = self.remaining.lock().expect("scripted stats mutex");
                remaining.remove(0)
            };
            *self.last.lock().expect("scripted last mutex") = next;
            sink(GenerationChunk { text: "ok".into() })
        }

        fn stats(&self) -> RuntimeStats {
            *self.last.lock().expect("scripted last mutex")
        }
    }

    fn stats(prefill_ms: u64, tok_s: f64) -> RuntimeStats {
        RuntimeStats {
            prefill_ms,
            prefill_tokens: 8,
            generation_ms: 200,
            generated_tokens: 16,
            tokens_per_second: tok_s,
            peak_rss_bytes: 1_000,
        }
    }

    fn request() -> GenerationRequest {
        GenerationRequest {
            prompt: "count".into(),
            max_output_tokens: 16,
            grammar: None,
        }
    }

    #[test]
    fn median_f64_odd_and_even() {
        assert_eq!(median_f64(&[3.0, 1.0, 2.0]), 2.0);
        assert_eq!(median_f64(&[4.0, 1.0, 2.0, 3.0]), 2.5);
        assert_eq!(median_f64(&[]), 0.0);
    }

    #[test]
    fn median_u64_odd_and_even() {
        assert_eq!(median_u64(&[30, 10, 20]), 20);
        assert_eq!(median_u64(&[40, 10, 20, 30]), 25);
        assert_eq!(median_u64(&[]), 0);
    }

    #[test]
    fn aggregate_rejects_an_empty_timed_set() {
        assert_eq!(
            aggregate(&[], &BenchProtocol::default(), BenchMetadata::default()),
            Err(BenchError::NoSamples)
        );
    }

    #[test]
    fn warmup_samples_are_discarded_from_the_median() {
        // First call is the cold shader-compile outlier Jan's warmup exists
        // to remove. Protocol: 1 warmup + 3 timed.
        let engine = ScriptedGeneration::new(vec![
            stats(900, 4.0),
            stats(100, 20.0),
            stats(120, 22.0),
            stats(80, 18.0),
        ]);
        let protocol = BenchProtocol {
            warmup_iterations: 1,
            timed_iterations: 3,
        };
        let report = run_generation_bench(
            &engine,
            &request(),
            &protocol,
            BenchMetadata {
                backend: AccelBackend::Cuda,
                clock_control: GpuClockControl::Unlocked,
                gpu_layers: 32,
                thread_count: 1,
                mode: BenchMode::Combined,
            },
            &CancelToken::new(),
        )
        .expect("scripted bench");

        assert_eq!(engine.calls.load(Ordering::SeqCst), 4);
        assert_eq!(report.median_first_token_ms, 100);
        assert_eq!(report.median_tokens_per_second, 20.0);
        assert_eq!(report.warmup_iterations, 1);
        assert_eq!(report.timed_iterations, 3);
        assert_eq!(report.metadata.backend, AccelBackend::Cuda);
        assert_eq!(report.peak_rss_bytes, 1_000);
        assert_eq!(report.prompt_tokens, 8);
        assert_eq!(report.generated_tokens, 16);
    }

    #[test]
    fn zero_timed_iterations_is_no_samples_not_a_zero_report() {
        let engine = ScriptedGeneration::new(vec![stats(100, 20.0)]);
        let err = run_generation_bench(
            &engine,
            &request(),
            &BenchProtocol {
                warmup_iterations: 1,
                timed_iterations: 0,
            },
            BenchMetadata::default(),
            &CancelToken::new(),
        )
        .expect_err("zero timed");
        assert_eq!(err, BenchError::NoSamples);
        assert_eq!(engine.calls.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn cancellation_during_warmup_is_an_engine_cancel() {
        let engine = ScriptedGeneration::new(vec![stats(100, 20.0)]);
        let cancel = CancelToken::new();
        cancel.cancel();
        let err = run_generation_bench(
            &engine,
            &request(),
            &BenchProtocol {
                warmup_iterations: 1,
                timed_iterations: 1,
            },
            BenchMetadata::default(),
            &cancel,
        )
        .expect_err("cancelled");
        assert_eq!(err, BenchError::Engine(EngineError::Cancelled));
    }
}
