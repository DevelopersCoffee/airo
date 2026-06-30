import 'package:platform_hardware/src/capabilities/capability_descriptors.dart';
import 'package:platform_hardware/src/capabilities/detection_result.dart';
import 'package:platform_hardware/src/detectors/hardware_detector.dart';
import 'package:platform_hardware/src/platform/hardware_profile.dart';

class MockHardwareDetector implements HardwareDetector {
  @override
  Future<HardwareProfile> detect() async {
    return const HardwareProfile(
      deviceId: 'mock-device-123',
      manufacturer: 'MockApple',
      model: 'iPhone 15 Pro',
      platform: 'iOS',
      osVersion: '17.0.0',
      architecture: 'arm64',
      cpu: DetectionResult(
        value: CPUCapability(supported: true, maxThreads: 6),
        confidence: DetectionConfidence.exact,
      ),
      gpu: DetectionResult(
        value: GPUCapability(supported: true, backend: 'Metal'),
        confidence: DetectionConfidence.exact,
      ),
      npu: DetectionResult(
        value: NPUCapability(supported: true, backend: 'CoreML'),
        confidence: DetectionConfidence.estimated,
      ),
      availableMemoryMb: DetectionResult(
        value: 4000,
        confidence: DetectionConfidence.estimated,
      ),
      totalMemoryMb: DetectionResult(
        value: 8000,
        confidence: DetectionConfidence.exact,
      ),
      availableStorageMb: DetectionResult(
        value: 120000,
        confidence: DetectionConfidence.derived,
      ),
      supportsMetal: true,
      supportsVulkan: false,
      supportsOpenCL: false,
      supportsNNAPI: false,
      supportsCoreML: true,
      supportsGPUInference: true,
      supportsBackgroundExecution: true,
    );
  }
}
