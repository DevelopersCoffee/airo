import 'dart:async';
import 'dart:io';

import 'package:platform_downloads/platform_downloads.dart';

import '../models/offline_model_info.dart';
import '../storage/model_storage_manager.dart';
import 'model_download_progress.dart';

/// AI-model adapter over the product-neutral progressive download platform.
class ModelDownloadService {
  factory ModelDownloadService({
    BackgroundDownloads? downloads,
    ModelStorageManager? storageManager,
  }) {
    final resolvedDownloads = downloads ?? MethodChannelBackgroundDownloads();
    return ModelDownloadService._(
      downloads: resolvedDownloads,
      storageManager:
          storageManager ?? ModelStorageManager(downloads: resolvedDownloads),
    );
  }

  ModelDownloadService._({
    required this._downloads,
    required this._storageManager,
  });

  final BackgroundDownloads _downloads;
  final ModelStorageManager _storageManager;
  StreamSubscription<DownloadProgress>? _progressSubscription;
  final Map<String, StreamController<ModelDownloadProgress>> _progressStreams =
      {};
  final Set<String> _scheduledIds = {};
  final Map<String, OfflineModelInfo> _scheduledModels = {};
  final StreamController<ModelDownloadProgress> _globalProgressController =
      StreamController<ModelDownloadProgress>.broadcast();

  Stream<ModelDownloadProgress> get globalProgressStream =>
      _globalProgressController.stream;

  Stream<ModelDownloadProgress> downloadModel(OfflineModelInfo model) {
    _ensureSubscribed();
    final controller = _progressStreams.putIfAbsent(
      model.id,
      () => StreamController<ModelDownloadProgress>.broadcast(),
    );
    if (_scheduledIds.add(model.id)) {
      _scheduledModels[model.id] = model;
      scheduleMicrotask(() => _prepareDownload(model));
    }
    return controller.stream;
  }

  Future<void> _prepareDownload(OfflineModelInfo model) async {
    if (await _storageManager.verifyModelIntegrity(model)) {
      await _tryWriteReceipt(model);
      _emit(ModelDownloadProgress.completed(model.id, model.fileSizeBytes));
      _scheduledIds.remove(model.id);
      return;
    }

    if (!await _storageManager.hasEnoughDiskSpace(model.fileSizeBytes)) {
      _emit(ModelDownloadProgress.failed(model.id, 'Insufficient disk space.'));
      _scheduledIds.remove(model.id);
      return;
    }

    final source = Uri.tryParse(model.downloadUrl ?? '');
    if (source == null || source.scheme != 'https' || source.host.isEmpty) {
      _emit(
        ModelDownloadProgress.failed(
          model.id,
          'A valid HTTPS model download URL is required.',
        ),
      );
      _scheduledIds.remove(model.id);
      return;
    }

    _emit(ModelDownloadProgress.starting(model.id, model.fileSizeBytes));
    try {
      final destinationPath = await _storageManager.getModelPath(
        model.id,
        model: model,
      );
      await _downloads.enqueue(
        DownloadArtifactRequest(
          artifactId: model.id,
          source: source,
          destinationPath: destinationPath,
          expectedBytes: model.fileSizeBytes,
          expectedSha256: model.sha256,
          displayName: model.name,
        ),
      );
    } on Object {
      _emit(
        ModelDownloadProgress.failed(
          model.id,
          'The platform download could not be started.',
        ),
      );
      _scheduledIds.remove(model.id);
    }
  }

  Future<void> _onPlatformProgress(DownloadProgress progress) async {
    if (progress.status == DownloadStatus.completed) {
      final model = _scheduledModels[progress.artifactId];
      if (model != null) {
        await _tryWriteReceipt(model);
      }
    }
    _emit(_toModelProgress(progress));
    if (progress.status == DownloadStatus.completed ||
        progress.status == DownloadStatus.cancelled) {
      _scheduledIds.remove(progress.artifactId);
      _scheduledModels.remove(progress.artifactId);
    }
  }

  ModelDownloadProgress _toModelProgress(DownloadProgress progress) {
    final status = switch (progress.status) {
      DownloadStatus.queued => ModelDownloadStatus.pending,
      DownloadStatus.downloading => ModelDownloadStatus.downloading,
      DownloadStatus.paused => ModelDownloadStatus.paused,
      DownloadStatus.verifying => ModelDownloadStatus.verifying,
      DownloadStatus.completed => ModelDownloadStatus.completed,
      DownloadStatus.failed => ModelDownloadStatus.failed,
      DownloadStatus.cancelled => ModelDownloadStatus.cancelled,
    };
    return ModelDownloadProgress(
      modelId: progress.artifactId,
      totalBytes: progress.totalBytes,
      downloadedBytes: progress.downloadedBytes,
      status: status,
      speedBytesPerSecond: progress.speedBytesPerSecond,
      error: progress.failure?.message,
      failureCode: progress.failure?.code.name,
      retryCount: progress.retryCount,
      queuePosition: progress.queuePosition,
      resumeSupported: progress.resumeSupported,
    );
  }

  void _emit(ModelDownloadProgress progress) {
    if (!_globalProgressController.isClosed) {
      _globalProgressController.add(progress);
    }
    final controller = _progressStreams[progress.modelId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  Future<void> pauseDownload(String modelId) => _downloads.pause(modelId);

  Future<void> resumeDownload(String modelId) => _downloads.resume(modelId);

  Future<void> retryDownload(String modelId, {OfflineModelInfo? model}) async {
    if (model == null) {
      await _downloads.retry(modelId);
      return;
    }

    // Re-enqueue with current catalog metadata so persisted requests from an
    // older catalog cannot repeat a stale size or checksum failure.
    await _downloads.cancel(modelId);
    _scheduledIds.remove(modelId);
    _scheduledModels.remove(modelId);
    _scheduledIds.add(modelId);
    _scheduledModels[modelId] = model;
    await _prepareDownload(model);
  }

  Future<void> cancelDownload(String modelId) => _downloads.cancel(modelId);

  Future<DownloadQueueSnapshot> getQueue() => _downloads.getQueue();

  Future<List<ModelDownloadProgress>> restoreQueue({
    Iterable<OfflineModelInfo> catalogModels = const <OfflineModelInfo>[],
  }) async {
    _ensureSubscribed();
    final snapshot = await _downloads.getQueue();
    final catalog = <String, OfflineModelInfo>{
      for (final model in catalogModels) model.id: model,
    };
    for (final entry in snapshot.entries) {
      final model = catalog[entry.artifactId];
      if (model == null) continue;
      if (entry.status == DownloadStatus.completed) {
        await _tryWriteReceipt(model);
      } else if (entry.status != DownloadStatus.cancelled) {
        _scheduledModels[model.id] = model;
        _scheduledIds.add(model.id);
      }
    }
    return snapshot.entries.map(_toModelProgress).toList(growable: false);
  }

  Future<String> getModelPath(String modelId, {OfflineModelInfo? model}) {
    return _storageManager.getModelPath(modelId, model: model);
  }

  Future<String?> resolveExistingModelPath(
    String modelId, {
    OfflineModelInfo? model,
  }) {
    return _storageManager.findExistingModelPath(modelId, model: model);
  }

  Future<bool> isModelDownloaded(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    final existingPath = await resolveExistingModelPath(modelId, model: model);
    if (existingPath == null) return false;
    final file = File(existingPath);
    return await file.exists() && await file.length() > 0;
  }

  Future<bool> deleteModel(String modelId) async {
    await cancelDownload(modelId);
    var deleted = false;
    for (final filePath in await _storageManager.getCandidateModelPaths(
      modelId,
    )) {
      for (final candidate in <String>[
        filePath,
        '$filePath.part',
        '$filePath.tmp',
      ]) {
        final file = File(candidate);
        if (await file.exists()) {
          await file.delete();
          deleted = true;
        }
      }
    }
    await _storageManager.deleteInstallReceipt(modelId);
    return deleted;
  }

  Future<int> getStorageUsed() async {
    final directory = await _storageManager.getModelsDirectory();
    if (!await directory.exists()) return 0;
    var totalBytes = 0;
    await for (final entity in directory.list()) {
      if (entity is File &&
          ModelStorageManager.supportedArtifactExtensions.any(
            entity.path.endsWith,
          )) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes;
  }

  Future<void> _tryWriteReceipt(OfflineModelInfo model) async {
    try {
      await _storageManager.writeInstallReceipt(model);
    } on Object {
      // The artifact itself remains valid. A missing receipt is surfaced by
      // the manager as unknown update state, never as "up to date".
    }
  }

  void _ensureSubscribed() {
    _progressSubscription ??= _downloads.events.listen(
      _onPlatformProgress,
      onError: (Object error, StackTrace stackTrace) {
        // Platform stream failures are observable through the global stream,
        // without exposing URLs, credentials, or local paths.
      },
    );
  }

  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    await _globalProgressController.close();
    for (final controller in _progressStreams.values) {
      await controller.close();
    }
    _progressStreams.clear();
    _scheduledIds.clear();
    _scheduledModels.clear();
  }
}
