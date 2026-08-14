import 'package:meta/meta.dart';

/// Coarse hardware class for a device's SoC, used only to cap the tier a
/// generous RAM reading alone would otherwise grant.
///
/// No platform bridge in this codebase reports a chipset SKU today -- see
/// `RealLlmDeviceSignalsProbe` for the honest heuristic it derives this from.
/// [entry] exists for the policy and its tests; the real probe currently
/// never returns it, only [unknown], [mainstream], or [flagship].
enum LlmChipsetClass {
  unknown,
  entry,
  mainstream,
  flagship;

  String get stableId => name;
}

/// Thermal pressure at the moment signals were probed.
///
/// Named after the same four-step ladder Android's `PowerManager` and iOS'
/// `ProcessInfo.ThermalState` both use, so a platform-side mapping is a
/// straight lookup rather than an invented scale.
enum LlmThermalPressure {
  nominal,
  fair,
  serious,
  critical;

  String get stableId => name;

  /// Critical pressure means local inference does not start this request at
  /// all -- not "run it slower." See `LlmDeviceTierPolicy`.
  bool get blocksLocalInference => this == LlmThermalPressure.critical;

  /// Serious or critical pressure means a running batch job (meeting
  /// extraction) must pause rather than continue at a throttled rate --
  /// the milestone's explicit non-goal is a "throttle-crawl."
  bool get shouldPauseBatchJobs =>
      this == LlmThermalPressure.serious ||
      this == LlmThermalPressure.critical;
}

/// The three axes #1631's tier matrix is computed from, plus thermal
/// pressure at read time.
///
/// Deliberately not sourced from a single platform call: RAM comes from
/// `DeviceCapabilityService.getMemoryInfo`, which core_ai already wires to a
/// real platform channel; storage and chipset are best-effort seams a
/// probe implementation fills in (see `RealLlmDeviceSignalsProbe`).
@immutable
class LlmDeviceSignals {
  const LlmDeviceSignals({
    required this.totalRamMb,
    required this.availableStorageMb,
    this.chipsetClass = LlmChipsetClass.unknown,
    this.thermalPressure = LlmThermalPressure.nominal,
  });

  final int totalRamMb;
  final int availableStorageMb;
  final LlmChipsetClass chipsetClass;
  final LlmThermalPressure thermalPressure;

  LlmDeviceSignals copyWith({
    int? totalRamMb,
    int? availableStorageMb,
    LlmChipsetClass? chipsetClass,
    LlmThermalPressure? thermalPressure,
  }) {
    return LlmDeviceSignals(
      totalRamMb: totalRamMb ?? this.totalRamMb,
      availableStorageMb: availableStorageMb ?? this.availableStorageMb,
      chipsetClass: chipsetClass ?? this.chipsetClass,
      thermalPressure: thermalPressure ?? this.thermalPressure,
    );
  }

  Map<String, Object?> toPublicMap() => {
    'totalRamMb': totalRamMb,
    'availableStorageMb': availableStorageMb,
    'chipsetClass': chipsetClass.stableId,
    'thermalPressure': thermalPressure.stableId,
  };

  @override
  bool operator ==(Object other) =>
      other is LlmDeviceSignals &&
      other.totalRamMb == totalRamMb &&
      other.availableStorageMb == availableStorageMb &&
      other.chipsetClass == chipsetClass &&
      other.thermalPressure == thermalPressure;

  @override
  int get hashCode =>
      Object.hash(totalRamMb, availableStorageMb, chipsetClass, thermalPressure);

  @override
  String toString() =>
      'LlmDeviceSignals(ramMb: $totalRamMb, storageMb: $availableStorageMb, '
      'chipset: ${chipsetClass.stableId}, thermal: ${thermalPressure.stableId})';
}

/// Reads [LlmDeviceSignals] from the current device.
///
/// Kept as an interface -- not just a function -- so the same shape used in
/// production (`RealLlmDeviceSignalsProbe`) is what a test substitutes
/// (`FakeLlmDeviceSignalsProbe`), matching the seam pattern the rest of
/// `core_ai` already uses (`ModelWarmupGateway`, `ModelPreloadPreferences`).
abstract interface class LlmDeviceSignalsProbe {
  Future<LlmDeviceSignals> probe();
}

/// Fixed, injected signals. The seam #1631's acceptance criteria asks for
/// directly: "fake thermal/RAM injection tests."
class FakeLlmDeviceSignalsProbe implements LlmDeviceSignalsProbe {
  const FakeLlmDeviceSignalsProbe(this.signals);

  final LlmDeviceSignals signals;

  @override
  Future<LlmDeviceSignals> probe() async => signals;
}
