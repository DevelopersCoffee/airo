import 'package:core_ai/core_ai.dart';
import 'package:core_native/core_native.dart';
import 'package:flutter/foundation.dart';

import '../services/gguf_artifact_guard.dart';

/// Assembles observed facts for [ModelHealthReport] from Mind-specific probes.
class ModelHealthFacts {
  const ModelHealthFacts._();

  static Future<ModelHealthReport> build({
    required OfflineModelInfo model,
    ModelCompatibilityResult? compatibility,
    ModelReadinessState? readiness,
    ModelDownloadProgress? download,
    int? contextTokens,
  }) async {
    final resolvedCompatibility =
        compatibility ?? await _compatibilityFor(model);
    final artifactPresent =
        GgufArtifactGuard.isVerified(model) ||
        (model.filePath?.trim().isNotEmpty == true && model.isDownloaded);

    return ModelHealthReport.fromFacts(
      model: model,
      download: download,
      artifactPresent: artifactPresent,
      artifactSizeVerified: GgufArtifactGuard.isVerified(model),
      compatibility: resolvedCompatibility,
      runtimeHealth: _runtimeHealth(readiness),
      plan: _plan(model, contextTokens),
    );
  }

  static Future<ModelCompatibilityResult> compatibilityFor(
    OfflineModelInfo model,
  ) => _compatibilityFor(model);

  static Future<ModelCompatibilityResult> _compatibilityFor(
    OfflineModelInfo model,
  ) async {
    final registry = ModelRegistry()..registerModel(model);
    return registry.checkCompatibility(model);
  }

  static RuntimeHealth? _runtimeHealth(ModelReadinessState? readiness) {
    if (readiness == null) return null;
    if (readiness.isRunnable) {
      return RuntimeHealth(
        state: RuntimeHealthState.ready,
        detail: readiness.detail,
      );
    }
    if (!readiness.canPrepare) {
      return RuntimeHealth(
        state: RuntimeHealthState.unavailable,
        detail: readiness.detail,
        error: switch (readiness.phase) {
          ModelReadinessPhase.notDownloaded => RuntimeErrorCode.modelMissing,
          _ => RuntimeErrorCode.runtimeUnavailable,
        },
      );
    }
    return RuntimeHealth(
      state: RuntimeHealthState.initializing,
      detail: readiness.detail,
    );
  }

  static ExecutionPlan? _plan(OfflineModelInfo model, int? contextTokens) {
    final runtime = switch (model.effectiveRuntime) {
      InferenceRuntime.llamaCpp => RuntimeId.llamaCpp,
      InferenceRuntime.litertLm => RuntimeId.liteRt,
      InferenceRuntime.onnx => RuntimeId.onnx,
      _ => null,
    };
    if (runtime == null) return null;

    final accelerator = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => ComputeAccelerator.metal,
      TargetPlatform.android => ComputeAccelerator.nnapi,
      _ => ComputeAccelerator.cpu,
    };
    final tokens = contextTokens ?? (model.contextLength > 0 ? model.contextLength : 2048);

    return ExecutionPlan(
      ir: InferenceIr(
        runtime: runtime,
        accelerator: accelerator,
        modelId: model.id,
        contextTokens: tokens,
        outputTokens: 512,
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        priority: ExecutionPriority.interactive,
      ),
      batchSize: 1,
      thermalLimited: false,
      batterySaver: false,
    );
  }
}
