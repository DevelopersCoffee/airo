import 'package:flutter/foundation.dart';

import '../runtime/models/model_models.dart';

/// Where a per-model benchmark reading stands relative to what a surface may
/// show for it.
///
/// [notRun] and [inProgress] both carry no [ModelBenchDisplay.bench] — the
/// surface has nothing measured to show yet. [measured] and [stale] both
/// carry a reading; the difference is whether that reading still describes
/// current conditions.
enum ModelBenchStatus { notRun, inProgress, measured, stale }

/// Why a previously-measured reading no longer describes current conditions.
///
/// A stale reading is not wrong — it was true when captured. It is wrong to
/// display without qualification, because the codebase treats a tok/s figure
/// measured cold and shown while throttled as a false claim.
enum ModelBenchStaleReason {
  /// [ModelPort.thermal] emitted a state that differs from
  /// [ModelBench.measuredUnder].
  thermalChanged,

  /// The reading was captured on different hardware (a `.airobackup` restore
  /// onto new hardware, or a fixture switch in tests).
  deviceChanged,

  /// Time elapsed since [ModelBench.measuredAtMs] exceeds the controller's
  /// staleness window. Thermal and battery drift with uptime even without a
  /// discrete thermal-state transition, so a reading with no other signal
  /// still expires.
  staleByTime,
}

/// What a Model Bench surface renders for one model: never just the numbers.
///
/// A bare [ModelBench] cannot express "not yet run" or "stale, and here is
/// why" — both are required states per MIND-DS-3 (#1456: "no metric is shown
/// before it has been measured once", "displayed figures carry the thermal
/// state they were measured under"). This wraps [ModelBench] with the status
/// a surface needs to render truthfully.
@immutable
class ModelBenchDisplay {
  const ModelBenchDisplay({
    required this.status,
    this.bench,
    this.progress,
    this.staleReason,
  }) : assert(
         status != ModelBenchStatus.measured || bench != null,
         'measured status requires a bench reading',
       ),
       assert(
         status != ModelBenchStatus.stale ||
             (bench != null && staleReason != null),
         'a stale display must carry both the old reading and why',
       ),
       assert(
         status == ModelBenchStatus.inProgress || progress == null,
         'progress is only meaningful while a benchmark is running',
       );

  /// No benchmark has ever run for this model.
  static const notRun = ModelBenchDisplay(status: ModelBenchStatus.notRun);

  final ModelBenchStatus status;

  /// The measured reading. Null iff [status] is [ModelBenchStatus.notRun] or
  /// [ModelBenchStatus.inProgress].
  final ModelBench? bench;

  /// Fraction complete in `[0, 1]` while [status] is
  /// [ModelBenchStatus.inProgress]. Null otherwise, including when a bench
  /// run has started but the runtime cannot report incremental progress.
  final double? progress;

  /// Set iff [status] is [ModelBenchStatus.stale].
  final ModelBenchStaleReason? staleReason;

  ModelBenchDisplay copyWith({
    ModelBenchStatus? status,
    ModelBench? bench,
    double? progress,
    ModelBenchStaleReason? staleReason,
    bool clearProgress = false,
    bool clearStaleReason = false,
  }) {
    return ModelBenchDisplay(
      status: status ?? this.status,
      bench: bench ?? this.bench,
      progress: clearProgress ? null : (progress ?? this.progress),
      staleReason: clearStaleReason
          ? null
          : (staleReason ?? this.staleReason),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModelBenchDisplay &&
      other.status == status &&
      other.bench == bench &&
      other.progress == progress &&
      other.staleReason == staleReason;

  @override
  int get hashCode => Object.hash(status, bench, progress, staleReason);
}
