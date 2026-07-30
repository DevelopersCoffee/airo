import 'package:core_native/core_native.dart';
import 'package:meta/meta.dart';

import '../download/model_download_progress.dart';
import '../device/memory_severity.dart';
import '../models/offline_model_info.dart';
import '../registry/model_registry.dart';

/// Ordered lifecycle stages shown by the Airo Runtime Health Center.
enum ModelHealthStage {
  downloaded,
  verified,
  compatible,
  runtimeReady,
  warmedUp,
  running,
}

enum ModelHealthStageStatus { unknown, pending, passed, blocked, failed }

@immutable
class ModelHealthStageResult {
  const ModelHealthStageResult({
    required this.stage,
    required this.status,
    required this.detail,
  });

  final ModelHealthStage stage;
  final ModelHealthStageStatus status;
  final String detail;

  bool get isPassed => status == ModelHealthStageStatus.passed;
}

/// Product-neutral recovery actions. The app decides how to render/execute
/// them; the framework only explains which action is safe.
enum ModelHealthAction {
  retry,
  resumeDownload,
  repair,
  reduceContext,
  chooseAlternative,
}

enum ModelHealthFailureCode {
  none,
  downloadIncomplete,
  integrityFailed,
  insufficientMemory,
  runtimeUnavailable,
  backendUnavailable,
  initializationFailed,
  modelMissing,
  permissionDenied,
  unsupportedModel,
  plannerFailure,
  timeout,
  cancelled,
  thermalLimit,
  contextTooLarge,
  storageFailure,
  unknown,
}

@immutable
class ModelHealthReport {
  const ModelHealthReport({
    required this.modelId,
    required this.modelName,
    required this.status,
    required this.stages,
    required this.explanation,
    required this.failureCode,
    required this.actions,
    this.availableMemoryMb,
    this.requiredMemoryMb,
    this.runtime,
    this.accelerator,
    this.contextTokens,
    this.trace,
  });

  final String modelId;
  final String modelName;
  final ModelHealthReportStatus status;
  final List<ModelHealthStageResult> stages;
  final String explanation;
  final ModelHealthFailureCode failureCode;
  final List<ModelHealthAction> actions;
  final double? availableMemoryMb;
  final double? requiredMemoryMb;
  final RuntimeId? runtime;
  final ComputeAccelerator? accelerator;
  final int? contextTokens;
  final ExecutionTrace? trace;

  bool get isReady =>
      status == ModelHealthReportStatus.ready ||
      status == ModelHealthReportStatus.running;

  ModelHealthStageResult stage(ModelHealthStage value) =>
      stages.firstWhere((entry) => entry.stage == value);

  /// Composes a report exclusively from observed facts. It performs no I/O,
  /// platform calls, or runtime calls, so identical facts produce identical
  /// diagnostics in Airo and Airo Mind.
  factory ModelHealthReport.fromFacts({
    required OfflineModelInfo model,
    ModelDownloadProgress? download,
    bool? artifactPresent,
    ModelCompatibilityResult? compatibility,
    RuntimeHealth? runtimeHealth,
    ExecutionPlan? plan,
    ExecutionTrace? trace,
  }) {
    final downloadStatus = download?.status;
    final downloaded =
        downloadStatus == ModelDownloadStatus.completed ||
        (download == null && (artifactPresent ?? model.isDownloaded));
    final downloading =
        downloadStatus == ModelDownloadStatus.downloading ||
        downloadStatus == ModelDownloadStatus.pending ||
        downloadStatus == ModelDownloadStatus.verifying ||
        downloadStatus == ModelDownloadStatus.paused;

    final stages = <ModelHealthStageResult>[
      ModelHealthStageResult(
        stage: ModelHealthStage.downloaded,
        status: downloaded
            ? ModelHealthStageStatus.passed
            : downloading
            ? ModelHealthStageStatus.pending
            : ModelHealthStageStatus.blocked,
        detail: downloaded
            ? 'Model artifact is present on this device.'
            : downloading
            ? 'Download is ${download!.statusDisplay.toLowerCase()}.'
            : 'Model artifact is not downloaded.',
      ),
      ModelHealthStageResult(
        stage: ModelHealthStage.verified,
        status: downloadStatus == ModelDownloadStatus.completed
            ? ModelHealthStageStatus.passed
            : downloadStatus == ModelDownloadStatus.failed
            ? ModelHealthStageStatus.failed
            : (artifactPresent ?? model.isDownloaded)
            ? ModelHealthStageStatus.unknown
            : ModelHealthStageStatus.pending,
        detail: downloadStatus == ModelDownloadStatus.failed
            ? (download?.error ?? 'Integrity verification failed.')
            : (artifactPresent ?? model.isDownloaded)
            ? 'Integrity receipt is not available in this snapshot.'
            : 'Verification starts after download completion.',
      ),
      ModelHealthStageResult(
        stage: ModelHealthStage.compatible,
        status: compatibility == null
            ? ModelHealthStageStatus.unknown
            : compatibility.isCompatible
            ? ModelHealthStageStatus.passed
            : ModelHealthStageStatus.blocked,
        detail:
            compatibility?.reason ??
            (compatibility == null
                ? 'Compatibility has not been measured yet.'
                : 'Device memory and capability checks passed.'),
      ),
      ModelHealthStageResult(
        stage: ModelHealthStage.runtimeReady,
        status: _runtimeStageStatus(runtimeHealth),
        detail: _runtimeDetail(runtimeHealth),
      ),
      ModelHealthStageResult(
        stage: ModelHealthStage.warmedUp,
        status: runtimeHealth?.state == RuntimeHealthState.busy
            ? ModelHealthStageStatus.passed
            : ModelHealthStageStatus.unknown,
        detail: runtimeHealth?.state == RuntimeHealthState.busy
            ? 'Runtime has accepted an inference request.'
            : 'Warmup has not been observed yet.',
      ),
      ModelHealthStageResult(
        stage: ModelHealthStage.running,
        status: runtimeHealth?.state == RuntimeHealthState.busy
            ? ModelHealthStageStatus.passed
            : ModelHealthStageStatus.unknown,
        detail: runtimeHealth?.state == RuntimeHealthState.busy
            ? 'Model is running.'
            : 'No active generation is running.',
      ),
    ];

    final failureCode = _failureCode(
      download: download,
      artifactPresent: artifactPresent,
      compatibility: compatibility,
      runtimeHealth: runtimeHealth,
    );
    final isRunning = runtimeHealth?.state == RuntimeHealthState.busy;
    final hasFailure = failureCode != ModelHealthFailureCode.none;
    final status = isRunning
        ? ModelHealthReportStatus.running
        : hasFailure
        ? ModelHealthReportStatus.recoverable
        : stages.every((entry) => entry.isPassed)
        ? ModelHealthReportStatus.ready
        : downloading
        ? ModelHealthReportStatus.preparing
        : ModelHealthReportStatus.unknown;

    return ModelHealthReport(
      modelId: model.id,
      modelName: model.name,
      status: status,
      stages: List.unmodifiable(stages),
      explanation: _explanation(
        model: model,
        failureCode: failureCode,
        compatibility: compatibility,
        runtimeHealth: runtimeHealth,
      ),
      failureCode: failureCode,
      actions: _actions(failureCode: failureCode, downloading: downloading),
      availableMemoryMb: compatibility?.availableMemoryMB,
      requiredMemoryMb: compatibility?.requiredMemoryMB,
      runtime: plan?.ir.runtime,
      accelerator: plan?.ir.accelerator,
      contextTokens: plan?.ir.contextTokens,
      trace: trace,
    );
  }

  static ModelHealthStageStatus _runtimeStageStatus(RuntimeHealth? health) {
    return switch (health?.state) {
      RuntimeHealthState.ready ||
      RuntimeHealthState.busy => ModelHealthStageStatus.passed,
      RuntimeHealthState.initializing ||
      RuntimeHealthState.recovering => ModelHealthStageStatus.pending,
      RuntimeHealthState.unavailable ||
      RuntimeHealthState.failed ||
      RuntimeHealthState.lowMemory ||
      RuntimeHealthState.thermallyLimited => ModelHealthStageStatus.blocked,
      _ => ModelHealthStageStatus.unknown,
    };
  }

  static String _runtimeDetail(RuntimeHealth? health) {
    if (health == null) return 'Runtime health has not been observed yet.';
    final detail = health.detail;
    if (detail != null && detail.trim().isNotEmpty) {
      return detail;
    }
    return switch (health.state) {
      RuntimeHealthState.ready => 'Selected runtime is ready.',
      RuntimeHealthState.busy => 'Selected runtime is processing a request.',
      RuntimeHealthState.lowMemory => 'Runtime paused because memory is low.',
      RuntimeHealthState.unavailable => 'No compatible runtime is available.',
      RuntimeHealthState.failed => 'Runtime initialization failed.',
      _ => 'Runtime state: ${health.state.name}.',
    };
  }

  static ModelHealthFailureCode _failureCode({
    required ModelDownloadProgress? download,
    required bool? artifactPresent,
    required ModelCompatibilityResult? compatibility,
    required RuntimeHealth? runtimeHealth,
  }) {
    // A live artifact probe is authoritative. A persisted file path can outlive
    // the file itself, so surface that state as recoverable instead of leaving
    // the Health Center stuck at "unknown".
    if (download == null && artifactPresent == false) {
      return ModelHealthFailureCode.downloadIncomplete;
    }
    if (download?.status == ModelDownloadStatus.failed) {
      final code = download?.failureCode;
      // Accept both the legacy camel-case value and the shared download
      // service's snake-case value while older persisted progress is migrated.
      if (code == 'integrityMismatch' ||
          code == 'integrity_mismatch' ||
          code == 'integrity-mismatch') {
        return ModelHealthFailureCode.integrityFailed;
      }
      return ModelHealthFailureCode.downloadIncomplete;
    }
    if (compatibility?.memorySeverity == MemorySeverity.blocked ||
        compatibility?.memorySeverity == MemorySeverity.critical) {
      return ModelHealthFailureCode.insufficientMemory;
    }
    return switch (runtimeHealth?.error) {
      RuntimeErrorCode.outOfMemory => ModelHealthFailureCode.insufficientMemory,
      RuntimeErrorCode.runtimeUnavailable =>
        ModelHealthFailureCode.runtimeUnavailable,
      RuntimeErrorCode.backendUnavailable =>
        ModelHealthFailureCode.backendUnavailable,
      RuntimeErrorCode.initializationFailed =>
        ModelHealthFailureCode.initializationFailed,
      RuntimeErrorCode.modelMissing => ModelHealthFailureCode.modelMissing,
      RuntimeErrorCode.permissionDenied =>
        ModelHealthFailureCode.permissionDenied,
      RuntimeErrorCode.unsupportedModel =>
        ModelHealthFailureCode.unsupportedModel,
      RuntimeErrorCode.plannerFailure => ModelHealthFailureCode.plannerFailure,
      RuntimeErrorCode.timeout => ModelHealthFailureCode.timeout,
      RuntimeErrorCode.cancelled => ModelHealthFailureCode.cancelled,
      RuntimeErrorCode.thermalLimit => ModelHealthFailureCode.thermalLimit,
      RuntimeErrorCode.contextTooLarge =>
        ModelHealthFailureCode.contextTooLarge,
      RuntimeErrorCode.storageFailure => ModelHealthFailureCode.storageFailure,
      _ => ModelHealthFailureCode.none,
    };
  }

  static String _explanation({
    required OfflineModelInfo model,
    required ModelHealthFailureCode failureCode,
    required ModelCompatibilityResult? compatibility,
    required RuntimeHealth? runtimeHealth,
  }) {
    switch (failureCode) {
      case ModelHealthFailureCode.insufficientMemory:
        final available = compatibility?.availableMemoryMB;
        final required =
            compatibility?.requiredMemoryMB ??
            model.estimatedMinMemoryBytes / (1024 * 1024);
        return available == null || available <= 0
            ? 'This model needs about ${required.toStringAsFixed(0)} MB of transient memory before warmup.'
            : 'This model needs about ${required.toStringAsFixed(0)} MB, but only ${available.toStringAsFixed(0)} MB is currently available.';
      case ModelHealthFailureCode.downloadIncomplete:
        return 'The model is not ready because its download did not complete.';
      case ModelHealthFailureCode.integrityFailed:
        return 'The downloaded file failed integrity verification and must be repaired.';
      case ModelHealthFailureCode.runtimeUnavailable:
        return 'No installed runtime can execute this model on the current device.';
      case ModelHealthFailureCode.backendUnavailable:
        return 'The preferred accelerator is unavailable; choose another backend or model.';
      case ModelHealthFailureCode.initializationFailed:
        return runtimeHealth?.detail ??
            'The runtime failed during initialization.';
      case ModelHealthFailureCode.modelMissing:
        return 'The selected model artifact is missing from local storage.';
      case ModelHealthFailureCode.permissionDenied:
        return 'A required device or storage permission was denied.';
      case ModelHealthFailureCode.unsupportedModel:
        return 'The selected runtime cannot execute this model format.';
      case ModelHealthFailureCode.plannerFailure:
        return runtimeHealth?.detail ??
            'Airo could not produce a safe execution plan for this request.';
      case ModelHealthFailureCode.timeout:
        return 'The runtime did not respond before the operation timed out.';
      case ModelHealthFailureCode.cancelled:
        return 'The inference request was cancelled before it completed.';
      case ModelHealthFailureCode.thermalLimit:
        return 'The device is thermally limited; pause and retry when it cools.';
      case ModelHealthFailureCode.contextTooLarge:
        return 'The requested context is too large for the current memory budget.';
      case ModelHealthFailureCode.storageFailure:
        return 'The model storage operation failed; repair the local artifact.';
      case ModelHealthFailureCode.none:
      case ModelHealthFailureCode.unknown:
        return 'Airo is still collecting runtime facts for this model.';
    }
  }

  static List<ModelHealthAction> _actions({
    required ModelHealthFailureCode failureCode,
    required bool downloading,
  }) {
    if (downloading) return const [ModelHealthAction.resumeDownload];
    return switch (failureCode) {
      ModelHealthFailureCode.insufficientMemory ||
      ModelHealthFailureCode.contextTooLarge => const [
        ModelHealthAction.reduceContext,
        ModelHealthAction.chooseAlternative,
      ],
      ModelHealthFailureCode.downloadIncomplete => const [
        ModelHealthAction.resumeDownload,
        ModelHealthAction.retry,
      ],
      ModelHealthFailureCode.integrityFailed ||
      ModelHealthFailureCode.storageFailure => const [
        ModelHealthAction.repair,
        ModelHealthAction.chooseAlternative,
      ],
      ModelHealthFailureCode.modelMissing => const [
        ModelHealthAction.resumeDownload,
        ModelHealthAction.chooseAlternative,
      ],
      ModelHealthFailureCode.none => const [],
      _ => const [ModelHealthAction.retry, ModelHealthAction.chooseAlternative],
    };
  }
}

enum ModelHealthReportStatus { unknown, preparing, ready, running, recoverable }
