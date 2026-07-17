import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/ai_model_management.dart';

/// Provider for [ModelStorageManager].
final modelStorageManagerProvider = Provider<ModelStorageManager>((ref) {
  return ModelStorageManager();
});

/// Provider for [IntelligentModelManager].
final intelligentModelManagerProvider = Provider<IntelligentModelManager>((ref) {
  final storageManager = ref.watch(modelStorageManagerProvider);
  final registry = ref.watch(modelRegistryProvider);
  final downloadService = ref.watch(modelDownloadServiceProvider);

  return IntelligentModelManager(
    storageManager,
    registry,
    downloadService,
  );
});

/// Rebuilding provider of the [ModelEntry] list, reacting to registry and download changes.
final intelligentModelsListProvider = FutureProvider<List<ModelEntry>>((ref) async {
  final manager = ref.watch(intelligentModelManagerProvider);
  // Rebuild the list if the model registry changes.
  ref.watch(modelRegistryEventsProvider);
  // Rebuild the list if active download progress is updated.
  ref.watch(activeDownloadsProvider);

  return manager.listModels();
});
