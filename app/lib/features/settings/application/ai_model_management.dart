import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../agent_chat/application/assistant_model_preferences.dart';
import '../../agent_chat/domain/models/assistant_model_selection.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;

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
  final service = ModelDownloadService();
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
  ActiveDownloadsNotifier(this._ref) : super({});

  final Ref _ref;
  final Map<String, StreamSubscription<ModelDownloadProgress>> _subscriptions =
      {};

  void startDownload(OfflineModelInfo model) {
    final service = _ref.read(modelDownloadServiceProvider);
    final stream = service.downloadModel(model);

    _subscriptions[model.id]?.cancel();
    _subscriptions[model.id] = stream.listen((progress) async {
      state = {...state, model.id: progress};

      if (progress.isComplete) {
        final registry = _ref.read(modelRegistryProvider);
        final modelPath = await service.getModelPath(model.id, model: model);
        registry.markAsDownloaded(model.id, modelPath);
      }

      if (progress.isComplete ||
          progress.isFailed ||
          progress.status == ModelDownloadStatus.cancelled) {
        _subscriptions[model.id]?.cancel();
        _subscriptions.remove(model.id);

        Future.delayed(const Duration(seconds: 2), () {
          state = Map.from(state)..remove(model.id);
        });
      }
    });
  }

  void cancelDownload(String modelId) {
    final service = _ref.read(modelDownloadServiceProvider);
    service.cancelDownload(modelId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
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
