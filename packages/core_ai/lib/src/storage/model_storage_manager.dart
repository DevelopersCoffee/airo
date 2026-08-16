import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:platform_downloads/platform_downloads.dart';

import '../models/offline_model_info.dart';
import '../intelligent_model_manager/model_install_receipt.dart';

/// Root used for model artifacts.
enum ModelStorageLocation {
  applicationDocuments,

  /// Application support: private, not user-visible, and not backed up to
  /// iCloud. For artifacts that are machinery rather than the user's files —
  /// on iOS the documents directory is browsable in Files and syncs, which a
  /// half-gigabyte model has no business doing.
  applicationSupport,

  applicationExternal,
}

/// Manages storage, SHA-256 integrity check, and space validation.
class ModelStorageManager {
  ModelStorageManager({
    BackgroundDownloads? downloads,
    this.location = ModelStorageLocation.applicationDocuments,
  }) : _downloads = downloads ?? createBackgroundDownloads();

  static const supportedArtifactExtensions = <String>[
    '.litertlm',
    '.gguf',
    '.bin',
    '.task',
    '.onnx',
  ];

  /// Default on-device ceiling for downloaded model artifacts.
  ///
  /// A heuristic pending a dedicated device-tier storage policy (#1631
  /// tracks device-tier gating more broadly) -- 8 GB accommodates two or
  /// three mid-size quantized models without silently consuming a phone's
  /// entire free space. [enforceStorageQuota] is what makes this a real
  /// ceiling rather than a suggestion: it deletes files, not just evicts a
  /// RAM-resident cache entry.
  static const int defaultStorageBudgetBytes = 8 * 1024 * 1024 * 1024;

  final BackgroundDownloads _downloads;
  final ModelStorageLocation location;

  /// Gets the directory where models are stored.
  Future<Directory> getModelsDirectory() async {
    final appDir = await _storageRootDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<Directory> _storageRootDirectory() async {
    switch (location) {
      case ModelStorageLocation.applicationExternal:
        final external = await getExternalStorageDirectory();
        if (external != null) return external;
        return getApplicationDocumentsDirectory();
      case ModelStorageLocation.applicationSupport:
        return getApplicationSupportDirectory();
      case ModelStorageLocation.applicationDocuments:
        return getApplicationDocumentsDirectory();
    }
  }

  Future<List<Directory>> _candidateModelDirectories() async {
    final primary = await getModelsDirectory();
    if (location != ModelStorageLocation.applicationExternal) return [primary];
    final documentsRoot = await getApplicationDocumentsDirectory();
    final legacy = Directory(path.join(documentsRoot.path, 'models'));
    if (path.equals(primary.path, legacy.path)) return [primary];
    return [primary, legacy];
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
    final directories = await _candidateModelDirectories();
    final expectedExtension = _artifactExtensionFor(model);
    return [
      for (final dir in directories) ...[
        path.join(dir.path, '$modelId$expectedExtension'),
        for (final extension in supportedArtifactExtensions)
          if (extension != expectedExtension)
            path.join(dir.path, '$modelId$extension'),
      ],
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

  /// Returns a stable fingerprint for update comparison without fetching data.
  String catalogFingerprint(OfflineModelInfo model) {
    final input = <String>[
      model.id,
      model.version ?? '',
      model.downloadUrl ?? '',
      model.fileSizeBytes.toString(),
      model.sha256?.toLowerCase() ?? '',
    ].join('\n');
    return sha256.convert(utf8.encode(input)).toString();
  }

  Future<File> _receiptFile(String modelId) async {
    final directory = await getModelsDirectory();
    return File(path.join(directory.path, '$modelId.install.json'));
  }

  /// Atomically records the exact catalog artifact installed for [model].
  Future<ModelInstallReceipt> writeInstallReceipt(
    OfflineModelInfo model, {
    DateTime? installedAt,
  }) async {
    final receipt = ModelInstallReceipt(
      modelId: model.id,
      catalogFingerprint: catalogFingerprint(model),
      installedAt: (installedAt ?? DateTime.now()).toUtc(),
      version: model.version,
      sha256: model.sha256?.toLowerCase(),
    );
    final destination = await _receiptFile(model.id);
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(jsonEncode(receipt.toJson()), flush: true);
    await temporary.rename(destination.path);
    return receipt;
  }

  /// Reads a receipt, returning null for legacy, missing, or corrupt metadata.
  Future<ModelInstallReceipt?> readInstallReceipt(String modelId) async {
    final file = await _receiptFile(modelId);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return ModelInstallReceipt.fromJson(decoded.cast<String, Object?>());
    } on Object {
      return null;
    }
  }

  Future<void> deleteInstallReceipt(String modelId) async {
    final file = await _receiptFile(modelId);
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  }

  /// Checks if the device has enough free space for the model file, plus a safety margin.
  Future<bool> hasEnoughDiskSpace(int requiredBytes) async {
    try {
      final freeBytes = await _downloads.getAvailableBytes();
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

  /// Total bytes currently occupied by installed (fully written) model
  /// artifacts -- the real, on-disk figure, not a catalog estimate.
  ///
  /// Excludes `.tmp`/`.part` staging files: an in-flight download is not
  /// "installed" and must not count against the quota it is trying to fit
  /// inside of.
  Future<int> installedArtifactsTotalBytes() async {
    var totalBytes = 0;
    for (final artifact in await _installedArtifacts()) {
      totalBytes += artifact.sizeBytes;
    }
    return totalBytes;
  }

  /// Deletes installed model artifacts, oldest first, until total on-disk
  /// usage is at or under [maxTotalBytes].
  ///
  /// This is disk-level eviction: unlike [ModelResidencyManager] (which only
  /// evicts a model from RAM so a new one fits in the memory budget), this
  /// removes the file from storage, so a device's quota is an enforceable
  /// ceiling instead of a cache that leaves every download on disk forever.
  ///
  /// Oldest is approximated by each artifact's filesystem modification time
  /// (i.e. roughly "installed longest ago"), since `atime` is unreliable
  /// across platforms (several mount models disable it). [protectedModelIds]
  /// (typically the model about to be downloaded, or one a caller knows is
  /// actively in use) is never evicted, even if it is the oldest artifact on
  /// disk -- eviction does not delete a protected file to satisfy a quota it
  /// never agreed to; if that leaves usage over [maxTotalBytes], the
  /// remainder is left in place and reported as unreachable via the returned
  /// list falling short of covering the shortfall.
  ///
  /// Returns the ids of every model actually deleted, oldest evicted first.
  Future<List<String>> enforceStorageQuota({
    int maxTotalBytes = defaultStorageBudgetBytes,
    Set<String> protectedModelIds = const {},
  }) async {
    final artifacts = await _installedArtifacts();
    var totalBytes = artifacts.fold<int>(0, (sum, a) => sum + a.sizeBytes);
    if (totalBytes <= maxTotalBytes) return const [];

    artifacts.sort((a, b) => a.modified.compareTo(b.modified));

    final evictedIds = <String>[];
    for (final artifact in artifacts) {
      if (totalBytes <= maxTotalBytes) break;
      if (protectedModelIds.contains(artifact.modelId)) continue;

      final file = File(artifact.path);
      if (await file.exists()) {
        await file.delete();
      }
      await deleteInstallReceipt(artifact.modelId);
      totalBytes -= artifact.sizeBytes;
      evictedIds.add(artifact.modelId);
    }
    return evictedIds;
  }

  /// Scans the models directory for completed (non-`.tmp`/`.part`) artifact
  /// files, resolving each to the model id its file name encodes.
  Future<List<_InstalledArtifact>> _installedArtifacts() async {
    final dir = await getModelsDirectory();
    if (!await dir.exists()) return [];

    final artifacts = <_InstalledArtifact>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final fileName = path.basename(entity.path);
      if (fileName.endsWith('.tmp') || fileName.endsWith('.part')) continue;

      String? modelId;
      for (final extension in supportedArtifactExtensions) {
        if (fileName.endsWith(extension)) {
          modelId = fileName.substring(0, fileName.length - extension.length);
          break;
        }
      }
      if (modelId == null) continue;

      final stat = await entity.stat();
      artifacts.add(
        _InstalledArtifact(
          modelId: modelId,
          path: entity.path,
          sizeBytes: stat.size,
          modified: stat.modified,
        ),
      );
    }
    return artifacts;
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

/// A completed model artifact found on disk during an eviction scan.
class _InstalledArtifact {
  const _InstalledArtifact({
    required this.modelId,
    required this.path,
    required this.sizeBytes,
    required this.modified,
  });

  final String modelId;
  final String path;
  final int sizeBytes;
  final DateTime modified;
}
