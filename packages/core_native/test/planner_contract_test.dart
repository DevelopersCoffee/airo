import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner v1 contracts are available to Dart', () {
    final request = InferenceRequest(
      capability: CapabilityId.chat,
      prompt: 'hello',
      modelId: null,
      priority: ExecutionPriority.interactive,
    );
    final profile = DeviceProfile(
      totalMemoryMb: BigInt.from(12000),
      availableMemoryMb: BigInt.from(8000),
      accelerator: ComputeAccelerator.cpu,
      thermalLimited: false,
      batterySaver: false,
    );
    final manifest = ModelManifest(
      id: 'mock-chat',
      capability: CapabilityId.chat,
      estimatedPeakMemoryMb: BigInt.from(1000),
      maxContextTokens: 4096,
      preferredRuntime: RuntimeId.mock,
      preferredAccelerator: ComputeAccelerator.cpu,
    );
    const config = PlannerConfig(
      defaultContextTokens: 2048,
      minimumContextTokens: 256,
      defaultOutputTokens: 256,
      minimumOutputTokens: 32,
      batchSize: 1,
      temperature: 0.2,
      topK: 40,
      topP: 0.9,
    );
    final registry = RuntimeRegistry(
      contractVersion: RuntimeApiVersion.v1,
      runtimes: const [RuntimeId.mock],
    );

    expect(request.capability, CapabilityId.chat);
    expect(profile.accelerator, ComputeAccelerator.cpu);
    expect(manifest.preferredRuntime, RuntimeId.mock);
    expect(config.minimumContextTokens, 256);
    expect(registry.runtimes, const [RuntimeId.mock]);
    expect(PlannerErrorCode.values, hasLength(5));
  });
}
