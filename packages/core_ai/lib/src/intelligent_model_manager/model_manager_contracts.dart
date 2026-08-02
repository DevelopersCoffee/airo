import 'package:meta/meta.dart';

import '../download/model_download_progress.dart';
import '../models/offline_model_info.dart';
import 'model_entry.dart';

@immutable
class ModelManagerSnapshot {
  const ModelManagerSnapshot({
    required this.models,
    required this.downloadQueue,
    required this.storageUsedBytes,
  });

  final List<ModelEntry> models;
  final List<ModelDownloadProgress> downloadQueue;
  final int storageUsedBytes;

  List<ModelEntry> get installedModels =>
      models.where((model) => model.isDownloaded).toList(growable: false);

  List<ModelEntry> get recommendedModels =>
      models.where((model) => model.isRecommended).toList(growable: false);

  /// Support-safe model/download diagnostics for release qualification.
  ///
  /// The report deliberately omits local file paths and raw platform errors.
  /// Pass [downloadQueueOverride] when the UI has fresher in-memory progress
  /// than the persisted snapshot.
  String toMarkdown({
    Iterable<ModelDownloadProgress>? downloadQueueOverride,
    DateTime? generatedAt,
  }) {
    final queue = (downloadQueueOverride ?? downloadQueue).toList()
      ..sort(
        (left, right) => (left.queuePosition ?? 0x7fffffff).compareTo(
          right.queuePosition ?? 0x7fffffff,
        ),
      );
    final buffer = StringBuffer()
      ..writeln('# Airo Model Manager Diagnostics')
      ..writeln()
      ..writeln('| Field | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Models | `${models.length}` |')
      ..writeln('| Installed | `${installedModels.length}` |')
      ..writeln('| Recommended | `${recommendedModels.length}` |')
      ..writeln('| Download queue | `${queue.length}` |')
      ..writeln('| Storage used | `${_formatBytes(storageUsedBytes)}` |')
      ..writeln(
        '| Generated | `${(generatedAt ?? DateTime.now()).toUtc().toIso8601String()}` |',
      )
      ..writeln()
      ..writeln('## Download queue')
      ..writeln();
    if (queue.isEmpty) {
      buffer.writeln('- No active or restored downloads.');
    } else {
      for (final progress in queue) {
        buffer
          ..writeln('- `${progress.modelId}`')
          ..writeln('  - Status: `${progress.statusDisplay}`')
          ..writeln(
            '  - Downloaded: `${_formatBytes(progress.downloadedBytes)} / ${_formatBytes(progress.totalBytes)}`',
          )
          ..writeln('  - Speed: `${progress.speedDisplay}`')
          ..writeln('  - ETA: `${progress.etaDisplay ?? 'not available'}`')
          ..writeln('  - Resume supported: `${progress.resumeSupported}`')
          ..writeln('  - Retry count: `${progress.retryCount}`')
          ..writeln('  - Integrity: `${_integrityState(progress)}`');
        final failureCode = progress.failureCode;
        if (failureCode != null && failureCode.trim().isNotEmpty) {
          buffer.writeln('  - Failure code: `$failureCode`');
        }
      }
    }
    buffer
      ..writeln()
      ..writeln('## Models')
      ..writeln();
    for (final model in models) {
      buffer
        ..writeln('- `${model.id}` ${model.name}')
        ..writeln('  - Version: `${model.version}`')
        ..writeln('  - Installed: `${model.isDownloaded}`')
        ..writeln('  - Active: `${model.isActive}`')
        ..writeln('  - Recommended: `${model.isRecommended}`')
        ..writeln('  - Resident: `${model.isResident}`')
        ..writeln('  - Update state: `${model.updateState.name}`')
        ..writeln('  - Size: `${_formatBytes(model.sizeBytes)}`');
      final installedVersion = model.installedVersion;
      if (installedVersion != null && installedVersion.trim().isNotEmpty) {
        buffer.writeln('  - Installed version: `$installedVersion`');
      }
    }
    return buffer.toString().trimRight();
  }

  static String _integrityState(ModelDownloadProgress progress) {
    final code = progress.failureCode?.toLowerCase();
    final integrityFailure =
        code == 'integritymismatch' ||
        code == 'integrity_mismatch' ||
        code == 'integrity-mismatch';
    return switch (progress.status) {
      ModelDownloadStatus.completed => 'verified',
      ModelDownloadStatus.verifying => 'verifying',
      ModelDownloadStatus.failed when integrityFailure => 'repair_required',
      ModelDownloadStatus.failed => 'not_verified',
      _ => 'pending_verification',
    };
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum ModelWarmupStatus { warmed, alreadyResident, unavailable, failed }

@immutable
class ModelWarmupResult {
  const ModelWarmupResult({
    required this.modelId,
    required this.status,
    this.detail,
  });

  final String modelId;
  final ModelWarmupStatus status;
  final String? detail;
}

/// App/runtime adapter for explicitly loading a model into memory.
abstract interface class ModelWarmupGateway {
  Future<ModelWarmupResult> warm(OfflineModelInfo model);

  Set<String> get residentModelIds;
}

/// App adapter for its persisted active-model selection.
abstract interface class ModelActivationGateway {
  Future<void> activate(OfflineModelInfo model);

  Future<void> clear(OfflineModelInfo model);
}

/// App-provided persistence for the user's frequent-model preload choices.
abstract interface class ModelPreloadPreferences {
  Future<Set<String>> loadModelIds();

  Future<void> setEnabled(String modelId, bool enabled);
}

class EmptyModelPreloadPreferences implements ModelPreloadPreferences {
  const EmptyModelPreloadPreferences();

  @override
  Future<Set<String>> loadModelIds() async => const <String>{};

  @override
  Future<void> setEnabled(String modelId, bool enabled) async {}
}
