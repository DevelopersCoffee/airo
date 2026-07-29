import 'package:core_native/core_native.dart';

import 'litert_lm_runtime_adapter.dart';

/// Thin v1 adapter from the backend-neutral Rust plan to LiteRT-LM.
///
/// Policy, model selection, and resource decisions remain in Rust. This class
/// only translates the immutable plan into the existing LiteRT client surface.
class LiteRtLmExecutionAdapter {
  LiteRtLmExecutionAdapter({required this._client});

  final LiteRtLmClient _client;

  Future<String> generate({
    required ExecutionPlan plan,
    required InferenceRequest request,
    required String modelPath,
    String? systemPrompt,
  }) async {
    if (plan.ir.runtime != RuntimeId.liteRt) {
      throw ArgumentError.value(
        plan.ir.runtime,
        'plan.ir.runtime',
        'LiteRT adapter received a plan for another runtime',
      );
    }

    final backend = _backendFor(plan.ir.accelerator);
    await _client.initialize(
      modelPath: modelPath,
      backend: backend,
      maxTokens: plan.ir.outputTokens,
    );
    return _client.generate(
      prompt: request.prompt,
      backend: backend,
      maxTokens: plan.ir.outputTokens,
      systemPrompt: systemPrompt,
    );
  }

  LiteRtLmBackend _backendFor(ComputeAccelerator accelerator) {
    return switch (accelerator) {
      ComputeAccelerator.cpu => LiteRtLmBackend.cpu,
      ComputeAccelerator.nnapi ||
      ComputeAccelerator.appleNeuralEngine ||
      ComputeAccelerator.coreMl => LiteRtLmBackend.npu,
      _ => LiteRtLmBackend.gpu,
    };
  }
}
