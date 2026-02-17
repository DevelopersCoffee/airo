/// Model download service for downloading GGUF models.
///
/// Handles downloading models with progress tracking, pause/resume support,
/// and storage management.
library;

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/offline_model_info.dart';
import 'model_download_progress.dart';

/// Service for downloading AI models.
class ModelDownloadService {
  ModelDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamController<ModelDownloadProgress>> _progressStreams =
      {};

  /// Downloads a model and returns a stream of progress updates.
  Stream<ModelDownloadProgress> downloadModel(OfflineModelInfo model) {
    if (_progressStreams.containsKey(model.id)) {
      return _progressStreams[model.id]!.stream;
    }

    final controller = StreamController<ModelDownloadProgress>.broadcast();
    _progressStreams[model.id] = controller;

    _startDownload(model, controller);

    return controller.stream;
  }

  Future<void> _startDownload(
    OfflineModelInfo model,
    StreamController<ModelDownloadProgress> controller,
  ) async {
    if (model.downloadUrl == null || model.downloadUrl!.isEmpty) {
      controller.add(
        ModelDownloadProgress.failed(model.id, 'No download URL available'),
      );
      await _cleanup(model.id);
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[model.id] = cancelToken;

    // Emit starting status
    controller.add(
      ModelDownloadProgress.starting(model.id, model.fileSizeBytes),
    );

    try {
      // Get storage directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(appDir.path, 'models'));
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final fileName = '${model.id}.gguf';
      final filePath = path.join(modelsDir.path, fileName);
      final tempPath = '$filePath.tmp';

      // Track progress with speed calculation
      int lastBytes = 0;
      DateTime lastTime = DateTime.now();
      double currentSpeed = 0;

      await _dio.download(
        model.downloadUrl!,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;

          // Update speed every 500ms
          if (elapsed >= 500) {
            final bytesPerMs = (received - lastBytes) / elapsed;
            currentSpeed = bytesPerMs * 1000; // Convert to bytes/second
            lastBytes = received;
            lastTime = now;
          }

          controller.add(
            ModelDownloadProgress(
              modelId: model.id,
              totalBytes: total > 0 ? total : model.fileSizeBytes,
              downloadedBytes: received,
              status: ModelDownloadStatus.downloading,
              speedBytesPerSecond: currentSpeed,
            ),
          );
        },
      );

      // Rename temp file to final
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(filePath);
      }

      // Emit completed status
      controller.add(
        ModelDownloadProgress.completed(model.id, model.fileSizeBytes),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        controller.add(
          ModelDownloadProgress(
            modelId: model.id,
            totalBytes: model.fileSizeBytes,
            downloadedBytes: 0,
            status: ModelDownloadStatus.cancelled,
          ),
        );
      } else {
        controller.add(
          ModelDownloadProgress.failed(
            model.id,
            e.message ?? 'Download failed',
          ),
        );
      }
    } catch (e) {
      controller.add(ModelDownloadProgress.failed(model.id, e.toString()));
    } finally {
      await _cleanup(model.id);
    }
  }

  /// Cancels a download in progress.
  void cancelDownload(String modelId) {
    _cancelTokens[modelId]?.cancel('User cancelled');
  }

  /// Gets the path where a model would be stored.
  Future<String> getModelPath(String modelId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'models', '$modelId.gguf');
  }

  /// Checks if a model is already downloaded.
  Future<bool> isModelDownloaded(String modelId) async {
    final filePath = await getModelPath(modelId);
    return File(filePath).exists();
  }

  /// Deletes a downloaded model.
  /// Returns true if deleted successfully, false if file doesn't exist.
  Future<bool> deleteModel(String modelId) async {
    final filePath = await getModelPath(modelId);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
      return true;
    }

    // Also try to delete temp file if exists
    final tempFile = File('$filePath.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    return false;
  }

  /// Gets the total storage used by downloaded models.
  Future<int> getStorageUsed() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'models'));

    if (!await modelsDir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in modelsDir.list()) {
      if (entity is File && entity.path.endsWith('.gguf')) {
        final stat = await entity.stat();
        totalBytes += stat.size;
      }
    }
    return totalBytes;
  }

  Future<void> _cleanup(String modelId) async {
    _cancelTokens.remove(modelId);
    await _progressStreams[modelId]?.close();
    _progressStreams.remove(modelId);
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    for (final controller in _progressStreams.values) {
      await controller.close();
    }
    _progressStreams.clear();
    _cancelTokens.clear();
  }
}
