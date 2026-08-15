//! Performance section: audio minutes, processing seconds, peak memory.
//! `#1636`.
//!
//! Reuses `airo_mind_core::RuntimeStats`'s shape rather than inventing a
//! parallel one: `RuntimeStats` already carries `peak_rss_bytes` and timing,
//! measured by whichever engine crate implements `GenerationEngine`/
//! `SpeechEngine` (`airo_mind_llama::LlamaGenerationEngine` measures its own
//! via `getrusage`, see that crate's `peak_rss_bytes`). This module does not
//! re-measure anything -- it aggregates the `RuntimeStats` an eval run's real
//! engine calls produced (when there were any) alongside the audio duration
//! and the eval run's own wall-clock time.

use airo_mind_core::RuntimeStats;

/// One pipeline run's performance profile.
#[derive(Clone, Copy, Debug, Default, PartialEq, serde::Serialize)]
pub struct PerformanceStats {
    pub audio_minutes: f64,
    pub processing_seconds: f64,
    /// The highest `peak_rss_bytes` reported by any engine call this run made
    /// (ASR, extraction, MoM narrative generation, judge). `0` when no real
    /// engine ran -- see [`crate::report`]'s doc comment on the CLI's default
    /// self-check mode.
    pub peak_memory_bytes: u64,
}

/// Builds [`PerformanceStats`] from the audio's total duration, the wall
/// time the pipeline actually took, and every `RuntimeStats` an engine call
/// produced along the way (order does not matter -- only the maximum RSS is
/// kept).
pub fn measure(
    audio_duration_ms: u64,
    processing: std::time::Duration,
    stats: &[RuntimeStats],
) -> PerformanceStats {
    let peak_memory_bytes = stats.iter().map(|s| s.peak_rss_bytes).max().unwrap_or(0);
    PerformanceStats {
        audio_minutes: audio_duration_ms as f64 / 60_000.0,
        processing_seconds: processing.as_secs_f64(),
        peak_memory_bytes,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn audio_duration_converts_ms_to_minutes() {
        let stats = measure(120_000, Duration::from_secs(30), &[]);
        assert_eq!(stats.audio_minutes, 2.0);
        assert_eq!(stats.processing_seconds, 30.0);
    }

    #[test]
    fn peak_memory_is_the_maximum_across_every_engine_call() {
        let stats = measure(
            60_000,
            Duration::from_secs(1),
            &[
                RuntimeStats {
                    peak_rss_bytes: 100,
                    ..RuntimeStats::default()
                },
                RuntimeStats {
                    peak_rss_bytes: 300,
                    ..RuntimeStats::default()
                },
                RuntimeStats {
                    peak_rss_bytes: 200,
                    ..RuntimeStats::default()
                },
            ],
        );
        assert_eq!(stats.peak_memory_bytes, 300);
    }

    #[test]
    fn no_engine_calls_means_zero_memory_not_an_error() {
        let stats = measure(0, Duration::from_secs(0), &[]);
        assert_eq!(stats.peak_memory_bytes, 0);
        assert_eq!(stats.audio_minutes, 0.0);
    }
}
