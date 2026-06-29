import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/offline_model_info.dart';

/// Manages storage, SHA-256 integrity check, and space validation.
class ModelStorageManager {
  ModelStorageManager({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.airo.model_download');

  static const supportedArtifactExtensions = <String>[
    '.litertlm',
    '.gguf',
    '.bin',
    '.task',
    '.onnx',
  ];

  final MethodChannel _channel;

  /// Gets the directory where models are stored.
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Gets the expected destination path for a given model.
  Future<String> getModelPath(String modelId, {OfflineModelInfo? model}) async {
    final dir = await getModelsDirectory();
    return path.join(dir.path, '$modelId${_artifactExtensionFor(model)}');
  }

  /// Returns candidate file paths for the model, preferring the expected extension first.
  Future<List<String>> getCandidateModelPaths(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    final dir = await getModelsDirectory();
    final expectedExtension = _artifactExtensionFor(model);
    return [
      path.join(dir.path, '$modelId$expectedExtension'),
      for (final extension in supportedArtifactExtensions)
        if (extension != expectedExtension)
          path.join(dir.path, '$modelId$extension'),
    ];
  }

  /// Finds an existing on-disk model artifact, including legacy incorrectly named files.
  Future<String?> findExistingModelPath(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    for (final candidate in await getCandidateModelPaths(
      modelId,
      model: model,
    )) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  /// Calculates the SHA-256 hash of a file in a streaming fashion.
  Future<String> calculateSHA256(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', file.path);
    }
    final stream = file.openRead();
    final output = await sha256.bind(stream).first;
    return output.toString();
  }

  /// Verifies a model file's integrity using its expected SHA-256 hash.
  Future<bool> verifyModelIntegrity(OfflineModelInfo model) async {
    final filePath =
        model.filePath ??
        await findExistingModelPath(model.id, model: model) ??
        await getModelPath(model.id, model: model);
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    if (model.sha256 == null || model.sha256!.isEmpty) {
      // If no expected hash is defined, we can't perform SHA verification,
      // but if the size matches we consider it acceptable.
      final stat = await file.stat();
      return stat.size == model.fileSizeBytes;
    }

    try {
      final hash = await calculateSHA256(file);
      return hash.toLowerCase() == model.sha256!.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Checks if the device has enough free space for the model file, plus a safety margin.
  Future<bool> hasEnoughDiskSpace(int requiredBytes) async {
    try {
      final int? freeBytes = await _channel.invokeMethod<int>(
        'getFreeDiskSpace',
      );
      if (freeBytes == null) {
        return true; // Fallback if native call returns null
      }
      // Require the requested bytes plus a 500 MB safety threshold
      const int safetyMargin = 500 * 1024 * 1024;
      return freeBytes >= (requiredBytes + safetyMargin);
    } catch (_) {
      return true; // Fallback if native platform call fails
    }
  }

  /// Scans the models directory and deletes any files that are not registered in [catalogModels].
  /// This detects and cleans up old temporary files and orphaned model artifacts.
  Future<List<String>> cleanupOrphanedFiles(
    List<OfflineModelInfo> catalogModels,
  ) async {
    final dir = await getModelsDirectory();
    if (!await dir.exists()) return [];

    final validIds = catalogModels.map((m) => m.id).toSet();
    final deletedPaths = <String>[];

    await for (final entity in dir.list()) {
      if (entity is File) {
        final fileName = path.basename(entity.path);

        // Match both final files (<id>.<ext>) and temp files (<id>.<ext>.tmp)
        String? modelId;
        for (final extension in supportedArtifactExtensions) {
          if (fileName.endsWith(extension)) {
            modelId = fileName.substring(0, fileName.length - extension.length);
            break;
          }
          final tempSuffix = '$extension.tmp';
          if (fileName.endsWith(tempSuffix)) {
            modelId = fileName.substring(
              0,
              fileName.length - tempSuffix.length,
            );
            break;
          }
        }

        if (modelId != null) {
          if (!validIds.contains(modelId)) {
            await entity.delete();
            deletedPaths.add(entity.path);
          }
        }
      }
    }
    return deletedPaths;
  }

  String _artifactExtensionFor(OfflineModelInfo? model) {
    final explicitPath = model?.filePath?.trim().toLowerCase();
    if (explicitPath != null && explicitPath.isNotEmpty) {
      for (final extension in supportedArtifactExtensions) {
        if (explicitPath.endsWith(extension)) return extension;
      }
    }

    final downloadPath = Uri.tryParse(
      model?.downloadUrl ?? '',
    )?.path.toLowerCase();
    if (downloadPath != null && downloadPath.isNotEmpty) {
      for (final extension in supportedArtifactExtensions) {
        if (downloadPath.endsWith(extension)) return extension;
      }
    }

    return '.gguf';
  }
}
