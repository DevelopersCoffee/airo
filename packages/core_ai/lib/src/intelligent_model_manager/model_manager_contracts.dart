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
