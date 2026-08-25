import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

/// Snapshot of device resources the processing planner can score against.
@immutable
class HardwareProfile {
  const HardwareProfile({
    required this.totalRamMb,
    required this.availableRamMb,
    required this.cpuArchitecture,
    required this.isAppleSilicon,
    required this.isLowMemoryPressure,
    required this.isBatteryConstrained,
  });

  factory HardwareProfile.fromMemoryInfo(
    MemoryInfo memory, {
    bool batteryConstrained = false,
  }) {
    final arch = _detectArchitecture();
    return HardwareProfile(
      totalRamMb: memory.isAvailable ? memory.totalMB.round() : 0,
      availableRamMb: memory.isAvailable ? memory.availableMB.round() : 0,
      cpuArchitecture: arch,
      isAppleSilicon: arch == 'arm64' && Platform.isMacOS,
      isLowMemoryPressure:
          memory.isAvailable &&
          (memory.availableGB < 2 || memory.usagePercent > 0.85),
      isBatteryConstrained: batteryConstrained,
    );
  }

  factory HardwareProfile.unknown() => const HardwareProfile(
    totalRamMb: 0,
    availableRamMb: 0,
    cpuArchitecture: 'unknown',
    isAppleSilicon: false,
    isLowMemoryPressure: false,
    isBatteryConstrained: false,
  );

  final int totalRamMb;
  final int availableRamMb;
  final String cpuArchitecture;
  final bool isAppleSilicon;
  final bool isLowMemoryPressure;
  final bool isBatteryConstrained;

  /// Admission ceiling passed to the Rust supervisor (MB).
  int memoryBudgetMb({int fallbackMb = 4096}) {
    if (availableRamMb <= 0) return fallbackMb;
    // Reserve headroom for UI, capture, and diarization staging.
    final safe = (availableRamMb * 0.55).round();
    return safe.clamp(512, fallbackMb);
  }

  static String _detectArchitecture() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS || Platform.isAndroid) return 'arm64';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }
}
