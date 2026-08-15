import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_mind/feature_mind.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;

import 'ai_preferences_settings.dart';

/// Tags a registry entry whose bytes another runtime owns.
///
/// The model explorer's verbs — activate, warm, benchmark, delete — all speak
/// to the LiteRT/llama.cpp chat runtime this screen drives. A tagged entry is
/// acquired and loaded elsewhere (today: the Airo Mind scribe), so the screen
/// reports its install state and offers none of those actions.
///
/// It lives here rather than beside the Mind catalog that applies it because
/// `lib/core/mind/**` resolves only under `pubspec_mind.yaml` — the phone,
/// TV and Coins flavours have no `feature_mind`, and a settings screen that
/// imported it would stop compiling for three of the four apps.
const String mindScribeModelTag = 'mind-scribe';

/// Provider for the model registry singleton.
final modelRegistryProvider = Provider<ModelRegistry>((ref) {
  final registry = ModelRegistry();
    registry.registerModels(ModelCatalog.bundledModels);
    unawaited(
      hydrateDownloadedModels(registry, ref.read(modelDownloadServiceProvider)),
    );
    unawaited(hydratePublicHuggingFaceModels(registry));
  ref.onDispose(registry.dispose);
  return registry;
});

final modelRegistryEventsProvider = StreamProvider<ModelRegistryEvent>((ref) {
  final registry = ref.watch(modelRegistryProvider);
  return registry.changes;
});

/// Marks catalog models the download service can prove are installed.
///
/// Public because shells that override [modelRegistryProvider] with a wider
/// catalog still owe the bundled models the same truthful install state —
/// re-implementing this check per shell is how they drift apart.
Future<void> hydrateDownloadedModels(
  ModelRegistry registry,
  ModelDownloadService service,
) async {
  for (final model in ModelCatalog.bundledModels) {
    // A path alone is not proof of an installed model. Require the download
    // service to validate size/checksum before the registry exposes it to the
    // picker or runtime health center.
    if (!await service.isModelDownloaded(model.id, model: model)) {
      continue;
    }
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
  // Rotate the storage adapter only when the location changes. The platform
  // queue is durable and survives this Dart-side adapter rotation, while new
  // downloads use the selected root immediately. Existing internal artifacts
  // remain discoverable when the external root is selected.
  final locationPreference = ref.watch(
    aiPreferencesSettingsProvider.select(
      (settings) => settings.downloadLocation,
    ),
  );
  final location = locationPreference == AIDownloadLocationPreference.appManaged
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
