import 'package:flutter_test/flutter_test.dart';
import 'package:platform_hardware/platform_hardware.dart';
import 'package:platform_models/platform_models.dart';

void main() {
  group('CompatibilityEvaluator', () {
    late HardwareProfile profile;
    late CompatibilityEvaluator evaluator;

    setUp(() {
      evaluator = DefaultCompatibilityEvaluator();
      profile = const HardwareProfile(
        deviceId: 'test',
        manufacturer: 'Test',
        model: 'Test Device',
        platform: 'TestOS',
        osVersion: '1.0',
        architecture: 'arm64',
        cpu: DetectionResult(
          value: CPUCapability(supported: true, maxThreads: 4),
          confidence: DetectionConfidence.exact,
        ),
        gpu: DetectionResult(
          value: GPUCapability(supported: true, backend: 'Metal'),
          confidence: DetectionConfidence.exact,
        ),
        npu: DetectionResult(
          value: NPUCapability(supported: false),
          confidence: DetectionConfidence.exact,
        ),
        availableMemoryMb: DetectionResult(
          value: 4000,
          confidence: DetectionConfidence.exact,
        ),
        totalMemoryMb: DetectionResult(
          value: 8000,
          confidence: DetectionConfidence.exact,
        ),
        availableStorageMb: DetectionResult(
          value: 10000,
          confidence: DetectionConfidence.exact,
        ),
        supportsMetal: true,
        supportsVulkan: false,
        supportsOpenCL: false,
        supportsNNAPI: false,
        supportsCoreML: false,
        supportsGPUInference: true,
        supportsBackgroundExecution: true,
      );
    });

    test('is compatible with sufficient RAM and storage', () {
      const model = ModelDescriptor(
        identifier: 'test-model',
        family: 'test',
        modality: ModelModality.textToText,
        version: '1.0',
        parameterCount: 1000000000,
        quantization: 'Q4_K',
        contextWindow: 1024,
        capabilities: ModelCapabilities(),
        minimumRamMb: 2000,
        downloadManifest: const DownloadManifest(
          identifier: 'test-model',
          version: '1.0',
          artifacts: [
            DownloadArtifactDescriptor(
              name: 'model.bin',
              primaryUrl: 'http://test',
              sizeInBytes: 1024 * 1024 * 500,
              sha256Checksum: '123',
            ),
          ],
        ),
      );

      final report = evaluator.evaluate(profile, model);
      
      expect(report.isCompatible, true);
      expect(report.blockingReasons, isEmpty);
      expect(report.recommendedRuntime, 'Metal');
    });

    test('is incompatible if RAM is insufficient', () {
      const model = ModelDescriptor(
        identifier: 'test-model',
        family: 'test',
        modality: ModelModality.textToText,
        version: '1.0',
        parameterCount: 7000000000,
        quantization: 'Q4_K',
        contextWindow: 1024,
        capabilities: ModelCapabilities(),
        minimumRamMb: 6000, // Needs 6GB, device has 4GB available
        downloadManifest: const DownloadManifest(
          identifier: 'test-model',
          version: '1.0',
          artifacts: [
            DownloadArtifactDescriptor(
              name: 'model.bin',
              primaryUrl: 'http://test',
              sizeInBytes: 1024 * 1024 * 500,
              sha256Checksum: '123',
            ),
          ],
        ),
      );

      final report = evaluator.evaluate(profile, model);
      
      expect(report.isCompatible, false);
      expect(report.blockingReasons, isNotEmpty);
      expect(report.blockingReasons.first, contains('Insufficient RAM'));
    });
  });
}
