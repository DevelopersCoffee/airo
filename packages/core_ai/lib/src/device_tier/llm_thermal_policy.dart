import 'llm_device_signals.dart';

/// What a batch job (meeting extraction, and anything else that runs
/// unattended over several minutes) should do right now.
enum LlmBatchJobAction {
  /// No thermal pressure worth acting on. Keep running.
  proceed,

  /// Serious or critical thermal pressure. Stop making forward progress
  /// until pressure eases -- never continue at a reduced rate.
  pause,

  /// Pressure has eased since the job was paused. Safe to continue from
  /// where it left off.
  resume,
}

/// Degrades batch jobs under thermal pressure by pausing them, not by
/// throttling their rate.
///
/// #1631's AC is explicit about the shape of this: "pause/queue batch jobs
/// (meeting extraction) rather than throttle-crawl." A throttled job still
/// burns the same peak power per token, just spread thinner -- it does not
/// actually relieve thermal pressure the way stopping does, and it hides the
/// problem from the person as a job that never seems to finish. Pause is
/// binary, visible, and resumable.
///
/// This is orthogonal to [LlmDeviceTierPolicy]'s thermal-critical override:
/// that policy decides whether a *new* request may start locally at all;
/// this policy decides whether an *already-running* batch job should keep
/// going.
class LlmThermalPolicy {
  const LlmThermalPolicy();

  LlmBatchJobAction decide({
    required LlmThermalPressure pressure,
    required bool jobCurrentlyPaused,
  }) {
    if (pressure.shouldPauseBatchJobs) {
      return LlmBatchJobAction.pause;
    }
    if (jobCurrentlyPaused) {
      return LlmBatchJobAction.resume;
    }
    return LlmBatchJobAction.proceed;
  }
}
