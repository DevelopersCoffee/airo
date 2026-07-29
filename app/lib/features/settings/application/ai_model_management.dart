import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../agent_chat/application/assistant_model_preferences.dart';
import '../../agent_chat/domain/models/assistant_model_selection.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;

import 'ai_preferences_settings.dart';

/// Provider for the model registry singleton.
final modelRegistryProvider = Provider<ModelRegistry>((ref) {
  final registry = ModelRegistry();
  registry.registerModels(ModelCatalog.bundledModels);
  unawaited(
    _hydrateDownloadedModels(registry, ref.read(modelDownloadServiceProvider)),
  );
  ref.onDispose(registry.dispose);
  return registry;
});

final modelRegistryEventsProvider = StreamProvider<ModelRegistryEvent>((ref) {
  final registry = ref.watch(modelRegistryProvider);
  return registry.changes;
});

Future<void> _hydrateDownloadedModels(
  ModelRegistry registry,
  ModelDownloadService service,
) async {
  for (final model in ModelCatalog.bundledModels) {
    final existingPath = await service.resolveExistingModelPath(
      model.id,
      model: model,
    );
    final trimmedPath = existingPath?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      continue;
    }
    registry.markAsDownloaded(model.id, trimmedPath);
  }
}

const String _selectedModelKey = 'selected_offline_model_id';

final selectedModelIdProvider =
    StateNotifierProvider<SelectedModelNotifier, String?>((ref) {
      return SelectedModelNotifier(ref);
    });

class SelectedModelNotifier extends StateNotifier<String?> {
  SelectedModelNotifier(this._ref) : super(null) {
    _loadFromStorage();
  }

  final Ref _ref;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = prefs.getString(_selectedModelKey);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_selectedModelKey);
    }
  }

  Future<void> setSelectedModel(String? modelId) async {
    state = modelId;
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      if (modelId != null) {
        await prefs.setString(_selectedModelKey, modelId);
      } else {
        await prefs.remove(_selectedModelKey);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (modelId != null) {
        await prefs.setString(_selectedModelKey, modelId);
      } else {
        await prefs.remove(_selectedModelKey);
      }
    }
  }
}

final selectedModelProvider = Provider<OfflineModelInfo?>((ref) {
  final selectedId = ref.watch(selectedModelIdProvider);
  if (selectedId == null) return null;

  final registry = ref.watch(modelRegistryProvider);
  final models = registry.downloadedModels;
  return models.where((m) => m.id == selectedId).firstOrNull;
});

final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  // Capture the root when the queue is created so changing preferences cannot
  // interrupt an active platform download. Existing internal artifacts remain
  // discoverable when the external root is selected.
  final settings = ref.read(aiPreferencesSettingsProvider);
  final location =
      settings.downloadLocation == AIDownloadLocationPreference.appManaged
      ? ModelStorageLocation.applicationExternal
      : ModelStorageLocation.applicationDocuments;
  final service = ModelDownloadService(storageLocation: location);
  ref.onDispose(() => service.dispose());
  return service;
});

final activeDownloadsProvider =
    StateNotifierProvider<
      ActiveDownloadsNotifier,
      Map<String, ModelDownloadProgress>
    >((ref) => ActiveDownloadsNotifier(ref));

class ActiveDownloadsNotifier
    extends StateNotifier<Map<String, ModelDownloadProgress>> {
  ActiveDownloadsNotifier(this._ref) : super({}) {
    final service = _ref.read(modelDownloadServiceProvider);
    _globalSubscription = service.globalProgressStream.listen(_applyProgress);
    unawaited(
      service.restoreQueue(catalogModels: ModelCatalog.bundledModels).then((
        entries,
      ) {
        for (final progress in entries) {
          _applyProgress(progress);
        }
      }),
    );
  }

  final Ref _ref;
  StreamSubscription<ModelDownloadProgress>? _globalSubscription;

  void startDownload(OfflineModelInfo model) {
    final service = _ref.read(modelDownloadServiceProvider);
    service.downloadModel(model);
  }

  Future<void> pauseDownload(String modelId) {
    final service = _ref.read(modelDownloadServiceProvider);
    return service.pauseDownload(modelId);
  }

  Future<void> resumeDownload(String modelId) {
    final service = _ref.read(modelDownloadServiceProvider);
    return service.resumeDownload(modelId);
  }

  Future<void> retryDownload(String modelId) {
    final service = _ref.read(modelDownloadServiceProvider);
    final model = _ref.read(modelRegistryProvider).getModel(modelId);
    return service.retryDownload(modelId, model: model);
  }

  Future<void> cancelDownload(String modelId) {
    final service = _ref.read(modelDownloadServiceProvider);
    return service.cancelDownload(modelId);
  }

  Future<void> _applyProgress(ModelDownloadProgress progress) async {
    state = {...state, progress.modelId: progress};
    if (progress.isComplete) {
      final registry = _ref.read(modelRegistryProvider);
      final model = registry.getModel(progress.modelId);
      if (model != null) {
        final service = _ref.read(modelDownloadServiceProvider);
        final modelPath = await service.getModelPath(model.id, model: model);
        registry.markAsDownloaded(model.id, modelPath);
      }
    }
    if (progress.isComplete ||
        progress.status == ModelDownloadStatus.cancelled) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          state = Map.from(state)..remove(progress.modelId);
        }
      });
    }
  }

  @override
  void dispose() {
    _globalSubscription?.cancel();
    super.dispose();
  }
}

Future<void> activateOfflineModel(WidgetRef ref, OfflineModelInfo model) async {
  await ref.read(selectedModelIdProvider.notifier).setSelectedModel(model.id);
  await ref
      .read(selectedAssistantModelIdProvider.notifier)
      .select(assistantModelIdForOfflineModel(model.id));
}

Future<void> clearOfflineModelSelections(
  WidgetRef ref,
  OfflineModelInfo model,
) async {
  if (ref.read(selectedModelIdProvider) == model.id) {
    await ref.read(selectedModelIdProvider.notifier).setSelectedModel(null);
  }
  final assistantModelId = assistantModelIdForOfflineModel(model.id);
  if (ref.read(selectedAssistantModelIdProvider) == assistantModelId) {
    await ref.read(selectedAssistantModelIdProvider.notifier).select(null);
  }
}
