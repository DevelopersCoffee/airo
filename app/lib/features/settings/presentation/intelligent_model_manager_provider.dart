import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/local_runtime_preloader_service.dart';
import '../../../core/services/model_preload_preferences.dart';
import '../../agent_chat/application/assistant_model_preferences.dart';
import '../../agent_chat/domain/models/assistant_model_selection.dart';
import '../application/ai_model_management.dart';

/// Bridges Airo's runtime preloader to the reusable model-manager contract.
///
/// This adapter is public so the release coverage gate can exercise every
/// runtime outcome without loading a real model.
class AiroModelWarmupGateway implements ModelWarmupGateway {
  AiroModelWarmupGateway(this._preloader);

  final LocalRuntimePreloaderService _preloader;

  @override
  Set<String> get residentModelIds =>
      _preloader.currentResidents.map((resident) => resident.id).toSet();

  @override
  Future<ModelWarmupResult> warm(OfflineModelInfo model) async {
    final report = await _preloader.warmModel(model);
    final entry = report.entries.first;
    final status = switch (entry.status) {
      ModelPreloadEntryStatus.warmed =>
        entry.reason == 'already_resident'
            ? ModelWarmupStatus.alreadyResident
            : ModelWarmupStatus.warmed,
      ModelPreloadEntryStatus.skipped => ModelWarmupStatus.unavailable,
      ModelPreloadEntryStatus.failed => ModelWarmupStatus.failed,
    };
    return ModelWarmupResult(
      modelId: model.id,
      status: status,
      detail: entry.reason,
    );
  }
}

/// Keeps the offline-model and assistant-model selections in sync.
///
/// This adapter is public so its persistence behavior can be verified without
/// driving the model-manager screen.
class AiroModelActivationGateway implements ModelActivationGateway {
  AiroModelActivationGateway(this._ref);

  final Ref _ref;

  @override
  Future<void> activate(OfflineModelInfo model) async {
    await _ref
        .read(selectedModelIdProvider.notifier)
        .setSelectedModel(model.id);
    await _ref
        .read(selectedAssistantModelIdProvider.notifier)
        .select(assistantModelIdForOfflineModel(model.id));
  }

  @override
  Future<void> clear(OfflineModelInfo model) async {
    if (_ref.read(selectedModelIdProvider) == model.id) {
      await _ref.read(selectedModelIdProvider.notifier).setSelectedModel(null);
    }
    final assistantModelId = assistantModelIdForOfflineModel(model.id);
    if (_ref.read(selectedAssistantModelIdProvider) == assistantModelId) {
      await _ref.read(selectedAssistantModelIdProvider.notifier).select(null);
    }
  }
}

/// Provider for [ModelStorageManager].
final modelStorageManagerProvider = Provider<ModelStorageManager>((ref) {
  return ModelStorageManager();
});

/// Provider for [IntelligentModelManager].
final intelligentModelManagerProvider = Provider<IntelligentModelManager>((
  ref,
) {
  final storageManager = ref.watch(modelStorageManagerProvider);
  final registry = ref.watch(modelRegistryProvider);
  final downloadService = ref.watch(modelDownloadServiceProvider);
  final preloadPreferences = SharedPreferencesModelPreloadPreferences();
  final preloader = LocalRuntimePreloaderService(
    preloadPreferences: preloadPreferences,
    selectedModelId: () => ref.read(selectedModelIdProvider),
  );

  return IntelligentModelManager(
    storageManager,
    registry,
    downloadService,
    preloadPreferences: preloadPreferences,
    warmupGateway: AiroModelWarmupGateway(preloader),
    activationGateway: AiroModelActivationGateway(ref),
  );
});

final intelligentModelManagerSnapshotProvider =
    FutureProvider<ModelManagerSnapshot>((ref) async {
      final manager = ref.watch(intelligentModelManagerProvider);
      // Rebuild the list if the model registry changes.
      ref.watch(modelRegistryEventsProvider);
      final selectedModelId = ref.watch(selectedModelIdProvider);

      return manager.snapshot(activeModelId: selectedModelId);
    });

/// Compatibility projection for callers that only need the catalog list.
final intelligentModelsListProvider = Provider<AsyncValue<List<ModelEntry>>>((
  ref,
) {
  return ref
      .watch(intelligentModelManagerSnapshotProvider)
      .whenData((snapshot) => snapshot.models);
});
