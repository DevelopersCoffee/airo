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

  test('reports a stalled download as recoverable retry work', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      download: ModelDownloadProgress(
        modelId: 'gemma-4b',
        totalBytes: 2_000,
        downloadedBytes: 700,
        status: ModelDownloadStatus.downloading,
        speedBytesPerSecond: 0,
        lastProgressAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.downloadIncomplete);
    expect(
      report.stage(ModelHealthStage.downloaded).status,
      ModelHealthStageStatus.blocked,
    );
    expect(
      report.stage(ModelHealthStage.downloaded).detail,
      'Download is stalled.',
    );
    expect(report.actions.first, ModelHealthAction.retry);
    expect(report.actions, contains(ModelHealthAction.resumeDownload));
  });

  test('does not trust a stale persisted path as a downloaded artifact', () {
    final report = ModelHealthReport.fromFacts(
      model: const OfflineModelInfo(
        id: 'stale',
        name: 'Stale model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
        filePath: '/models/removed.litertlm',
      ),
      artifactPresent: false,
    );

    expect(
      report.stage(ModelHealthStage.downloaded).status,
      ModelHealthStageStatus.blocked,
    );
    expect(
      report.stage(ModelHealthStage.verified).status,
      ModelHealthStageStatus.pending,
    );
    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.downloadIncomplete);
    expect(report.actions, contains(ModelHealthAction.resumeDownload));
  });

  test('maps the download service integrity failure to repair guidance', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      download: const ModelDownloadProgress(
        modelId: 'gemma-4b',
        totalBytes: 2_000,
        downloadedBytes: 2_000,
        status: ModelDownloadStatus.failed,
        failureCode: 'integrity_mismatch',
        error: 'Checksum mismatch',
      ),
    );

    expect(report.failureCode, ModelHealthFailureCode.integrityFailed);
    expect(report.explanation, contains('integrity verification'));
    expect(report.actions, contains(ModelHealthAction.repair));
  });

  test('surfaces typed runtime failures instead of leaving health unknown', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      runtimeHealth: const RuntimeHealth(
        state: RuntimeHealthState.failed,
        error: RuntimeErrorCode.timeout,
        detail: 'Native generation timed out',
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.timeout);
    expect(report.explanation, contains('timed out'));
    expect(report.actions, contains(ModelHealthAction.retry));
  });

  test('does not hide an unknown runtime failure as pending health', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      runtimeHealth: const RuntimeHealth(
        state: RuntimeHealthState.failed,
        error: RuntimeErrorCode.unknown,
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.unknown);
    expect(report.explanation, contains('unknown failure'));
  });

  test('maps low-memory runtime state to reduced-context recovery', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      runtimeHealth: const RuntimeHealth(
        state: RuntimeHealthState.lowMemory,
        detail: 'Runtime paused because memory is low.',
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.insufficientMemory);
    expect(report.explanation, contains('transient memory'));
    expect(report.actions, contains(ModelHealthAction.reduceContext));
    expect(report.actions, contains(ModelHealthAction.chooseAlternative));
    expect(
      report.stage(ModelHealthStage.runtimeReady).status,
      ModelHealthStageStatus.blocked,
    );
  });

  test('maps thermal runtime state to retry recovery', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      runtimeHealth: const RuntimeHealth(
        state: RuntimeHealthState.thermallyLimited,
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.thermalLimit);
    expect(report.explanation, contains('thermally limited'));
    expect(report.actions, contains(ModelHealthAction.retry));
  });

  test('maps unavailable runtime state without an error code', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      runtimeHealth: const RuntimeHealth(state: RuntimeHealthState.unavailable),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.runtimeUnavailable);
    expect(report.explanation, contains('No installed runtime'));
    expect(report.actions, contains(ModelHealthAction.chooseAlternative));
  });

  test('maps failed runtime state without an error code', () {
    final report = ModelHealthReport.fromFacts(
      model: _model(),
      runtimeHealth: const RuntimeHealth(
        state: RuntimeHealthState.failed,
        detail: 'LiteRT init failed before reporting a typed error.',
      ),
    );

    expect(report.status, ModelHealthReportStatus.recoverable);
    expect(report.failureCode, ModelHealthFailureCode.initializationFailed);
    expect(report.explanation, contains('LiteRT init failed'));
    expect(report.actions, contains(ModelHealthAction.retry));
  });
}
