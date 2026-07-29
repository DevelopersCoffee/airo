import 'package:core_ai/core_ai.dart';
import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineModelInfo _model() => const OfflineModelInfo(
  id: 'gemma-4b',
  name: 'Gemma 4B',
  family: ModelFamily.gemma,
  fileSizeBytes: 2_000_000_000,
  minMemoryBytes: 3_500_000_000,
  recommendedMemoryBytes: 4_500_000_000,
);

void main() {
  test('reports a verified running model with the selected plan', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      download: ModelDownloadProgress.completed('gemma-4b', 2_000_000_000),
      compatibility: const ModelCompatibilityResult(
        isCompatible: true,
        memorySeverity: MemorySeverity.safe,
        availableMemoryMB: 6_000,
        requiredMemoryMB: 3_338,
      ),
      runtimeHealth: const RuntimeHealth(state: RuntimeHealthState.busy),
      plan: const ExecutionPlan(
        ir: InferenceIr(
          runtime: RuntimeId.liteRt,
          accelerator: ComputeAccelerator.vulkan,
          modelId: 'gemma-4b',
          contextTokens: 4096,
          outputTokens: 256,
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          priority: ExecutionPriority.interactive,
        ),
        batchSize: 1,
        thermalLimited: false,
        batterySaver: false,
      ),
    );

    expect(report.status, ModelHealthReportStatus.running);
    expect(report.isReady, isTrue);
    expect(report.failureCode, ModelHealthFailureCode.none);
    expect(report.runtime, RuntimeId.liteRt);
    expect(report.accelerator, ComputeAccelerator.vulkan);
    expect(report.stage(ModelHealthStage.verified).isPassed, isTrue);
    expect(report.explanation, contains('Airo'));
  });

  test('explains transient memory pressure and offers recovery', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      compatibility: const ModelCompatibilityResult(
        isCompatible: false,
        memorySeverity: MemorySeverity.blocked,
        reason: 'Budget exceeded',
        availableMemoryMB: 2_100,
        requiredMemoryMB: 3_338,
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.insufficientMemory);
    expect(report.explanation, contains('2100'));
    expect(report.actions, contains(ModelHealthAction.reduceContext));
    expect(report.actions, contains(ModelHealthAction.chooseAlternative));
    expect(
      report.stage(ModelHealthStage.compatible).status,
      ModelHealthStageStatus.blocked,
    );
  });

  test('reports a resumable download without claiming verification', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      download: const ModelDownloadProgress(
        modelId: 'gemma-4b',
        totalBytes: 2_000,
        downloadedBytes: 700,
        status: ModelDownloadStatus.paused,
        resumeSupported: true,
      ),
    );

    expect(report.status, ModelHealthReportStatus.preparing);
    expect(
      report.stage(ModelHealthStage.downloaded).status,
      ModelHealthStageStatus.pending,
    );
    expect(report.stage(ModelHealthStage.verified).isPassed, isFalse);
    expect(report.actions, [ModelHealthAction.resumeDownload]);
  });
}
