import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import '../models/offline_model_info.dart';
import '../storage/model_storage_manager.dart';
import 'model_download_progress.dart';

/// Service for downloading AI models delegating to native platforms for background capability.
class ModelDownloadService {
  ModelDownloadService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    ModelStorageManager? storageManager,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('com.airo.model_download'),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.airo.model_download/progress'),
       _storageManager =
           storageManager ??
           ModelStorageManager(
             channel:
                 methodChannel ??
                 const MethodChannel('com.airo.model_download'),
           );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final ModelStorageManager _storageManager;

  StreamSubscription? _progressSubscription;
  final Map<String, StreamController<ModelDownloadProgress>> _progressStreams =
      {};
  final StreamController<ModelDownloadProgress> _globalProgressController =
      StreamController<ModelDownloadProgress>.broadcast();

  /// Stream of all progress updates.
  Stream<ModelDownloadProgress> get globalProgressStream {
    _ensureProgressSubscription();
    return _globalProgressController.stream;
  }

  // FIFO Queue implementation
  final List<OfflineModelInfo> _queue = [];
  OfflineModelInfo? _activeModel;

  void _ensureProgressSubscription() {
    if (_progressSubscription != null) return;
    _progressSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onProgressUpdate,
      onError: (err) {
        if (_activeModel != null) {
          final modelId = _activeModel!.id;
          _emitProgress(
            ModelDownloadProgress.failed(modelId, 'Native event error: $err'),
          );
          _handleDownloadFinished(modelId);
        }
      },
    );
  }

  void _onProgressUpdate(dynamic event) {
    if (event is! Map) return;
    final map = event.cast<String, dynamic>();
    final modelId = map['modelId'] as String?;
    if (modelId == null) return;

    final statusStr = map['status'] as String? ?? 'failed';
    final status = _statusFromString(statusStr);
    final downloaded = map['downloadedBytes'] as int? ?? 0;
    final total = map['totalBytes'] as int? ?? 0;
    final speed = (map['speedBytesPerSecond'] as num?)?.toDouble() ?? 0.0;
    final error = map['error'] as String?;

    final progress = ModelDownloadProgress(
      modelId: modelId,
      totalBytes: total,
      downloadedBytes: downloaded,
      status: status,
      speedBytesPerSecond: speed,
      error: error,
    );

    _emitProgress(progress);

    if (status == ModelDownloadStatus.completed ||
        status == ModelDownloadStatus.failed ||
        status == ModelDownloadStatus.cancelled) {
      _handleDownloadFinished(modelId);
    }
  }

  ModelDownloadStatus _statusFromString(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'pending':
        return ModelDownloadStatus.pending;
      case 'downloading':
        return ModelDownloadStatus.downloading;
      case 'paused':
        return ModelDownloadStatus.paused;
      case 'completed':
        return ModelDownloadStatus.completed;
      case 'failed':
        return ModelDownloadStatus.failed;
      case 'cancelled':
        return ModelDownloadStatus.cancelled;
      case 'verifying':
        return ModelDownloadStatus.verifying;
      default:
        return ModelDownloadStatus.failed;
    }
  }

  StreamController<ModelDownloadProgress> _getOrCreateController(
    String modelId,
  ) {
    if (_progressStreams.containsKey(modelId)) {
      return _progressStreams[modelId]!;
    }
    final controller = StreamController<ModelDownloadProgress>.broadcast();
    _progressStreams[modelId] = controller;
    return controller;
  }

  void _emitProgress(ModelDownloadProgress progress) {
    if (!_globalProgressController.isClosed) {
      _globalProgressController.add(progress);
    }
    final controller = _progressStreams[progress.modelId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  /// Downloads a model and returns a stream of progress updates.
  Stream<ModelDownloadProgress> downloadModel(OfflineModelInfo model) {
    _ensureProgressSubscription();
    final controller = _getOrCreateController(model.id);

    // If it's already the active model or queued, just return the stream
    if (_activeModel?.id == model.id) {
      return controller.stream;
    }
    if (_queue.any((m) => m.id == model.id)) {
      return controller.stream;
    }

    scheduleMicrotask(() {
      _startDownloadOrQueue(model);
    });
    return controller.stream;
  }

  Future<void> _startDownloadOrQueue(OfflineModelInfo model) async {
    // 1. Verify space and integrity first
    final hasIntegrity = await _storageManager.verifyModelIntegrity(model);
    if (hasIntegrity) {
      final controller = _getOrCreateController(model.id);
      controller.add(
        ModelDownloadProgress.completed(model.id, model.fileSizeBytes),
      );
      return;
    }

    final hasSpace = await _storageManager.hasEnoughDiskSpace(
      model.fileSizeBytes,
    );
    if (!hasSpace) {
      final controller = _getOrCreateController(model.id);
      controller.add(
        ModelDownloadProgress.failed(model.id, 'Insufficient disk space.'),
      );
      return;
    }

    if (_activeModel != null) {
      // Put in FIFO queue
      _queue.add(model);
      _emitProgress(
        ModelDownloadProgress.starting(model.id, model.fileSizeBytes),
      );
      return;
    }

    // Start download immediately
    _activeModel = model;
    _emitProgress(
      ModelDownloadProgress(
        modelId: model.id,
        totalBytes: model.fileSizeBytes,
        downloadedBytes: 0,
        status: ModelDownloadStatus.downloading,
        startTime: DateTime.now(),
      ),
    );

    try {
      final filePath = await _storageManager.getModelPath(model.id);
      await _methodChannel.invokeMethod('startDownload', {
        'modelId': model.id,
        'url': model.downloadUrl,
        'filePath': filePath,
      });
    } catch (e) {
      _emitProgress(ModelDownloadProgress.failed(model.id, e.toString()));
      _handleDownloadFinished(model.id);
    }
  }

  void _handleDownloadFinished(String modelId) {
    if (_activeModel?.id == modelId) {
      _activeModel = null;
      _cleanupController(modelId);
      _processQueue();
    }
  }

  void _processQueue() {
    if (_queue.isNotEmpty && _activeModel == null) {
      final nextModel = _queue.removeAt(0);
      _startDownloadOrQueue(nextModel);
    }
  }

  /// Cancels a download in progress.
  Future<void> cancelDownload(String modelId) async {
    _ensureProgressSubscription();
    // If it's in the queue, remove and mark cancelled
    final queueIndex = _queue.indexWhere((m) => m.id == modelId);
    if (queueIndex != -1) {
      _queue.removeAt(queueIndex);
      _emitProgress(
        ModelDownloadProgress(
          modelId: modelId,
          totalBytes: 0,
          downloadedBytes: 0,
          status: ModelDownloadStatus.cancelled,
        ),
      );
      _cleanupController(modelId);
      return;
    }

    // If it is active, tell native to cancel
    if (_activeModel?.id == modelId) {
      try {
        await _methodChannel.invokeMethod('cancelDownload', {
          'modelId': modelId,
        });
      } catch (e) {
        _emitProgress(
          ModelDownloadProgress.failed(modelId, 'Cancel failed: $e'),
        );
        _handleDownloadFinished(modelId);
      }
    }
  }

  /// Gets the path where a model would be stored.
  Future<String> getModelPath(String modelId) async {
    return _storageManager.getModelPath(modelId);
  }

  /// Checks if a model is already downloaded.
  Future<bool> isModelDownloaded(String modelId) async {
    final path = await getModelPath(modelId);
    final file = File(path);
    if (!await file.exists()) return false;

    // Check integrity if size matches catalog spec roughly
    final stat = await file.stat();
    return stat.size > 0;
  }

  /// Deletes a downloaded model.
  /// Returns true if deleted successfully, false if file doesn't exist.
  Future<bool> deleteModel(String modelId) async {
    await cancelDownload(modelId);
    final filePath = await getModelPath(modelId);
    final file = File(filePath);

    var deleted = false;
    if (await file.exists()) {
      await file.delete();
      deleted = true;
    }

    // Also delete temp file if exists
    final tempFile = File('$filePath.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
      deleted = true;
    }

    return deleted;
  }

  /// Gets the total storage used by downloaded models.
  Future<int> getStorageUsed() async {
    final dir = await _storageManager.getModelsDirectory();
    if (!await dir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.gguf')) {
        final stat = await entity.stat();
        totalBytes += stat.size;
      }
    }
    return totalBytes;
  }

  void _cleanupController(String modelId) {
    final controller = _progressStreams.remove(modelId);
    controller?.close();
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    await _globalProgressController.close();
    for (final controller in _progressStreams.values) {
      await controller.close();
    }
    _progressStreams.clear();
    _queue.clear();
    _activeModel = null;
  }
}
