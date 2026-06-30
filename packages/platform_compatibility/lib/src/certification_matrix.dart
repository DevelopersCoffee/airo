
import 'package:platform_provider/platform_provider.dart';

enum PlatformOS { android, ios, macos, windows, linux }
enum CpuArchitecture { arm64, x64, avx2, avx512, neon }
enum GpuBackend { metal, vulkan, cuda, directml, opencl }
enum AcceleratorType { coreml, nnapi, qualcomm, mediatek, none }

class HardwareSupportDeclaration {
  final Set<PlatformOS> osSupport;
  final Set<CpuArchitecture> cpuSupport;
  final Set<GpuBackend> gpuSupport;
  final Set<AcceleratorType> acceleratorSupport;

  const HardwareSupportDeclaration({
    this.osSupport = const {},
    this.cpuSupport = const {},
    this.gpuSupport = const {},
    this.acceleratorSupport = const {},
  });
}

class CertificationReport {
  final String providerId;
  final HardwareSupportDeclaration declaredSupport;
  final Map<String, bool> testResults; // Feature -> Passed

  CertificationReport({
    required this.providerId,
    required this.declaredSupport,
    required this.testResults,
  });

  bool get isCertified => testResults.values.every((passed) => passed);
}
