import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database_native.dart';
import 'ai_storage_dashboard.dart';

Future<AIStorageDashboardSummary> loadAIStorageDashboardSummary() {
  return const _AIStorageDashboardIoService().loadSummary();
}

class _AIStorageDashboardIoService {
  const _AIStorageDashboardIoService();

  static const _diskChannel = MethodChannel('com.airo.model_download');

  Future<AIStorageDashboardSummary> loadSummary() async {
    final documents = await getApplicationDocumentsDirectory();
    final temporary = await _safeDirectory(getTemporaryDirectory);
    final databasePath = await AppDatabase.resolveDatabasePath();
    final availableSpace = await _availableDiskSpace();

    final categories = <AIStorageDashboardCategory>[
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.installedModels,
        label: 'Installed models',
        bytes: await _directorySize(
          Directory(path.join(documents.path, 'models')),
        ),
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.meetingStorage,
        label: 'Meeting storage',
        bytes: await _sumSizes([
          Directory(path.join(documents.path, 'meeting_audio')),
          Directory(path.join(documents.path, 'recordings')),
        ]),
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.embeddingStorage,
        label: 'Embedding storage',
        bytes: await _sumSizes([
          Directory(path.join(documents.path, 'embeddings')),
          Directory(path.join(documents.path, 'meeting_embeddings')),
        ]),
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.databaseSize,
        label: 'Database size',
        bytes: await _sumSizes([
          File(databasePath),
          File('$databasePath-wal'),
          File('$databasePath-shm'),
        ]),
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.audioCache,
        label: 'Audio cache',
        bytes: await _sumSizes([
          Directory(path.join(documents.path, 'audio_cache')),
          if (temporary != null)
            Directory(path.join(temporary.path, 'audio_cache')),
        ]),
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.availableSpace,
        label: 'Available space',
        bytes: availableSpace ?? 0,
        available: availableSpace != null,
      ),
    ];

    return AIStorageDashboardSummary(categories: categories);
  }

  Future<int?> _availableDiskSpace() async {
    try {
      return await _diskChannel.invokeMethod<int>('getFreeDiskSpace');
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _safeDirectory(Future<Directory> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  Future<int> _sumSizes(Iterable<FileSystemEntity> entities) async {
    var total = 0;
    for (final entity in entities) {
      total += await _entitySize(entity);
    }
    return total;
  }

  Future<int> _entitySize(FileSystemEntity entity) async {
    if (entity is File) {
      if (!await entity.exists()) return 0;
      return entity.length();
    }
    if (entity is Directory) {
      return _directorySize(entity);
    }
    return 0;
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
