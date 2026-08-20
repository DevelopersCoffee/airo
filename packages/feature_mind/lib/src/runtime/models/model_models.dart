import 'package:flutter/foundation.dart';

/// Whether a model is in memory, on disk, or neither.
///
/// Three states, not two. `resident` means a capability holds it on disk —
/// evicting it breaks that capability, and the surface must name which.
enum ModelResidency { loaded, resident, available }

/// Thermal state at the moment a benchmark was taken.
///
/// Carried alongside the benchmark because a tok/s figure measured cold and
/// displayed while throttled is a false claim.
enum ThermalState { nominal, fair, serious, critical }

/// Accelerator the timed generate() actually used.
///
/// [cuda] is a first-class member so Windows CUDA testing can label a
/// reading without a contract change. It is not linked on current
/// macOS/Android builds.
enum InferenceAccelBackend { none, metal, openCl, vulkan, cuda, auto }

/// How GPU clocks were treated for this run.
///
/// Unlocked is user experience (boost is stochastic). [base] / [maxBoost]
/// exist so a later Windows CUDA `ncu` pass can record the lock it used
/// rather than mixing locked-clock numbers with unlocked ones.
enum GpuClockControl { unlocked, base, maxBoost }

/// Which headline this reading is answering. Both tok/s and TTFT are
/// always collected from the same warmed timed runs.
enum ModelBenchMode { combined, coldPrompt, steadyDecode }

/// Numbers measured on this hardware. Never a spec sheet figure.
@immutable
class ModelBench {
  const ModelBench({
    required this.tokensPerSecond,
    required this.firstTokenMs,
    required this.residentBytes,
    required this.batteryPercentPerHour,
    required this.measuredUnder,
    required this.measuredAtMs,
    this.cpuUtilizationPercent,
    this.npuUtilizationPercent,
    this.accelBackend,
    this.clockControl,
    this.gpuLayers,
    this.threadCount,
    this.warmupIterations,
    this.timedIterations,
    this.protocol,
    this.promptTokens,
    this.generatedTokens,
  });

  final double tokensPerSecond;
  final int firstTokenMs;
  final int residentBytes;
  final double batteryPercentPerHour;
  final ThermalState measuredUnder;
  final int measuredAtMs;

  /// Windows-only (MIND-DS-3, #1456). Null on platforms without a CPU
  /// utilisation API wired, and until measured — never a guess.
  final double? cpuUtilizationPercent;

  /// Windows-only (MIND-DS-3, #1456). Null off-Windows, or on Windows
  /// hardware with no NPU, or until measured.
  final double? npuUtilizationPercent;

  /// Null on readings taken before the generation-bench protocol landed.
  final InferenceAccelBackend? accelBackend;

  /// Null means the reading did not record a clock policy (legacy).
  final GpuClockControl? clockControl;

  /// Layers offloaded to GPU. `0` is CPU. `-1` means all layers. Null on
  /// legacy readings.
  final int? gpuLayers;

  final int? threadCount;
  final int? warmupIterations;
  final int? timedIterations;
  final ModelBenchMode? protocol;
  final int? promptTokens;
  final int? generatedTokens;

  @override
  bool operator ==(Object other) =>
      other is ModelBench &&
      other.tokensPerSecond == tokensPerSecond &&
      other.firstTokenMs == firstTokenMs &&
      other.residentBytes == residentBytes &&
      other.batteryPercentPerHour == batteryPercentPerHour &&
      other.measuredUnder == measuredUnder &&
      other.measuredAtMs == measuredAtMs &&
      other.cpuUtilizationPercent == cpuUtilizationPercent &&
      other.npuUtilizationPercent == npuUtilizationPercent &&
      other.accelBackend == accelBackend &&
      other.clockControl == clockControl &&
      other.gpuLayers == gpuLayers &&
      other.threadCount == threadCount &&
      other.warmupIterations == warmupIterations &&
      other.timedIterations == timedIterations &&
      other.protocol == protocol &&
      other.promptTokens == promptTokens &&
      other.generatedTokens == generatedTokens;

  @override
  int get hashCode => Object.hash(
    tokensPerSecond,
    firstTokenMs,
    residentBytes,
    batteryPercentPerHour,
    measuredUnder,
    measuredAtMs,
    cpuUtilizationPercent,
    npuUtilizationPercent,
    accelBackend,
    clockControl,
    gpuLayers,
    threadCount,
    warmupIterations,
    timedIterations,
    protocol,
    promptTokens,
    generatedTokens,
  );
}

/// A model on, or available to, this device.
@immutable
class MindModel {
  const MindModel({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.residency,
    this.heldBy = '',
    this.bench,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final ModelResidency residency;

  /// The capability holding this model resident. Empty unless [residency] is
  /// [ModelResidency.resident].
  final String heldBy;

  /// Null until measured. A surface must not show a benchmark that has never
  /// been run.
  final ModelBench? bench;

  @override
  bool operator ==(Object other) =>
      other is MindModel &&
      other.id == id &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.residency == residency &&
      other.heldBy == heldBy &&
      other.bench == bench;

  @override
  int get hashCode =>
      Object.hash(id, name, sizeBytes, residency, heldBy, bench);
}
