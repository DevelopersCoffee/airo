import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 inference contracts are available to Dart', () {
    const request = InferenceRequest(
      capability: CapabilityId.chat,
      prompt: 'hello',
      modelId: 'model-v1',
      priority: ExecutionPriority.interactive,
    );
    const sameRequest = InferenceRequest(
      capability: CapabilityId.chat,
      prompt: 'hello',
      modelId: 'model-v1',
      priority: ExecutionPriority.interactive,
    );

    expect(request, sameRequest);
    expect(RuntimeApiVersion.values, contains(RuntimeApiVersion.v1));
    expect(RuntimeId.values, contains(RuntimeId.mock));
    expect(ComputeAccelerator.values, contains(ComputeAccelerator.cpu));
  });
}
