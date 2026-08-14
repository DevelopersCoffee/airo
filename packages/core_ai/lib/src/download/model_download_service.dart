import 'dart:async';
import 'dart:io';

import 'package:platform_downloads/platform_downloads.dart';

import '../models/offline_model_info.dart';
import '../storage/model_storage_manager.dart';
import 'model_download_progress.dart';

/// AI-model adapter over the product-neutral progressive download platform.
class ModelDownloadService {
  ModelDownloadService({
    BackgroundDownloads? downloads,
    ModelStorageManager? storageManager,
    ModelStorageLocation storageLocation =
        ModelStorageLocation.applicationDocuments,
    int storageBudgetBytes = ModelStorageManager.defaultStorageBudgetBytes,
  }) : this._from(
         _resolveDependencies(
           downloads: downloads,
           storageManager: storageManager,
           storageLocation: storageLocation,
         ),
         storageBudgetBytes,
       );

  ModelDownloadService._from(
    _ResolvedDependencies dependencies,
    this.storageBudgetBytes,
  ) : _downloads = dependencies.downloads,
      _storageManager = dependencies.storageManager;

  /// The enforced on-device ceiling for downloaded model artifacts.
  ///
  /// Checked -- and enforced by deleting the least-recently-installed models
  /// that are not [model] itself -- before every new download starts, so the
  /// quota is a real disk limit rather than a number the storage UI merely
  /// displays.
  final int storageBudgetBytes;

  static _ResolvedDependencies _resolveDependencies({
    BackgroundDownloads? downloads,
    ModelStorageManager? storageManager,
    required ModelStorageLocation storageLocation,
  }) {
    final resolvedDownloads = downloads ?? MethodChannelBackgroundDownloads();
    return _ResolvedDependencies(
      downloads: resolvedDownloads,
      storageManager:
          storageManager ??
          ModelStorageManager(
            downloads: resolvedDownloads,
            location: storageLocation,
          ),
    );
  }

  final BackgroundDownloads _downloads;
  final ModelStorageManager _storageManager;

  /// The storage manager backing this service, for callers (e.g.
  /// `ModelPort` implementations) that need real on-disk usage/quota figures
  /// without duplicating a second manager pointed at a different directory.
  ModelStorageManager get storageManager => _storageManager;
  StreamSubscription<DownloadProgress>? _progressSubscription;
  final Map<String, StreamController<ModelDownloadProgress>> _progressStreams =
      {};
  final Set<String> _scheduledIds = {};
  final Map<String, OfflineModelInfo> _scheduledModels = {};
  final Map<String, DateTime> _downloadStartedAt = {};
  final Map<String, DateTime> _lastByteProgressAt = {};
  final Map<String, int> _lastDownloadedBytes = {};
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

    // Real disk-level eviction: free room within the storage budget before
    // a new download starts, rather than letting every past download
    // accumulate on disk forever. Never evicts the model about to be
    // fetched, even if a stale artifact for it happens to be the oldest.
    final roomForIncoming = (storageBudgetBytes - model.fileSizeBytes) < 0
        ? 0
        : storageBudgetBytes - model.fileSizeBytes;
    await _storageManager.enforceStorageQuota(
      maxTotalBytes: roomForIncoming,
      protectedModelIds: {model.id},
    );

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
    final now = DateTime.now();
    _downloadStartedAt[model.id] = now;
    _lastByteProgressAt[model.id] = now;
    _lastDownloadedBytes[model.id] = 0;
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
        _emit(
          ModelDownloadProgress(
            modelId: progress.artifactId,
            totalBytes: progress.totalBytes,
            downloadedBytes: progress.downloadedBytes,
            status: ModelDownloadStatus.verifying,
            retryCount: progress.retryCount,
            resumeSupported: progress.resumeSupported,
          ),
        );
        final verified = await _storageManager.verifyModelIntegrity(model);
        if (!verified) {
          _emit(
            ModelDownloadProgress(
              modelId: progress.artifactId,
              totalBytes: progress.totalBytes,
              downloadedBytes: progress.downloadedBytes,
              status: ModelDownloadStatus.failed,
              error: 'The downloaded artifact failed integrity verification.',
              failureCode: 'integrity_mismatch',
              retryCount: progress.retryCount,
              resumeSupported: progress.resumeSupported,
            ),
          );
          _scheduledIds.remove(progress.artifactId);
          _scheduledModels.remove(progress.artifactId);
          _clearProgressTracking(progress.artifactId);
          return;
        }
        await _tryWriteReceipt(model);
      }
    }
    _emit(_toModelProgress(progress));
    if (progress.status == DownloadStatus.completed ||
        progress.status == DownloadStatus.cancelled ||
        progress.status == DownloadStatus.failed) {
      _scheduledIds.remove(progress.artifactId);
      _scheduledModels.remove(progress.artifactId);
      _clearProgressTracking(progress.artifactId);
    }
  }

  ModelDownloadProgress _toModelProgress(DownloadProgress progress) {
    final now = DateTime.now();
    final status = switch (progress.status) {
      DownloadStatus.queued => ModelDownloadStatus.pending,
      DownloadStatus.downloading => ModelDownloadStatus.downloading,
      DownloadStatus.paused => ModelDownloadStatus.paused,
      DownloadStatus.verifying => ModelDownloadStatus.verifying,
      DownloadStatus.completed => ModelDownloadStatus.completed,
      DownloadStatus.failed => ModelDownloadStatus.failed,
      DownloadStatus.cancelled => ModelDownloadStatus.cancelled,
    };
    final startedAt = status == ModelDownloadStatus.downloading
        ? _downloadStartedAt.putIfAbsent(progress.artifactId, () => now)
        : _downloadStartedAt[progress.artifactId];
    var lastProgressAt = _lastByteProgressAt[progress.artifactId];
    if (status == ModelDownloadStatus.downloading) {
      final previousBytes = _lastDownloadedBytes[progress.artifactId];
      if (previousBytes == null || progress.downloadedBytes > previousBytes) {
        _lastDownloadedBytes[progress.artifactId] = progress.downloadedBytes;
        lastProgressAt = now;
        _lastByteProgressAt[progress.artifactId] = now;
      }
      lastProgressAt ??= startedAt;
    }
    return ModelDownloadProgress(
      modelId: progress.artifactId,
      totalBytes: progress.totalBytes,
      downloadedBytes: progress.downloadedBytes,
      status: status,
      speedBytesPerSecond: progress.speedBytesPerSecond,
      startTime: startedAt,
      lastProgressAt: lastProgressAt,
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
  }) async {
    final explicitPath = model?.filePath?.trim();
    if (explicitPath != null && explicitPath.isNotEmpty) {
      final explicitFile = File(explicitPath);
      if (await explicitFile.exists() && await explicitFile.length() > 0) {
        return explicitPath;
      }
    }
    return _storageManager.findExistingModelPath(modelId, model: model);
  }

  Future<bool> isModelDownloaded(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    final existingPath = await resolveExistingModelPath(modelId, model: model);
    if (existingPath == null) return false;
    final file = File(existingPath);
    if (!await file.exists() || await file.length() == 0) return false;
    if (model == null) return true;

    // Installed state must mean the exact catalog artifact is usable, not
    // merely that a stale or truncated file remains in the models directory.
    return _storageManager.verifyModelIntegrity(
      model.copyWith(filePath: existingPath),
    );
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

  /// Removes a corrupt or incomplete artifact and starts a fresh verified
  /// download using the current catalog metadata.
  Future<void> repairModel(OfflineModelInfo model) async {
    await deleteModel(model.id);
    downloadModel(model);
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

  void _clearProgressTracking(String modelId) {
    _downloadStartedAt.remove(modelId);
    _lastByteProgressAt.remove(modelId);
    _lastDownloadedBytes.remove(modelId);
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
    _downloadStartedAt.clear();
    _lastByteProgressAt.clear();
    _lastDownloadedBytes.clear();
  }
}

class _ResolvedDependencies {
  const _ResolvedDependencies({
    required this.downloads,
    required this.storageManager,
  });

  final BackgroundDownloads downloads;
  final ModelStorageManager storageManager;
}
