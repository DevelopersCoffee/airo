import 'memory_severity.dart';

class DesktopHostFacts {
  const DesktopHostFacts({
    this.model,
    this.osVersion,
    this.cpuSummary,
    this.gpuSummary,
    this.npuSummary,
    this.storageSummary,
    this.thermalSummary,
  });

  final String? model;
  final String? osVersion;
  final String? cpuSummary;
  final String? gpuSummary;
  final String? npuSummary;
  final String? storageSummary;
  final String? thermalSummary;
}

Future<MemoryInfo?> probeDesktopMemory() async => null;

Future<DesktopHostFacts?> probeDesktopHostFacts() async => null;
