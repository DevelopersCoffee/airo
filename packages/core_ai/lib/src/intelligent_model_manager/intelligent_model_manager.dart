import 'model_entry.dart';
import '../storage/model_storage_manager.dart';
import '../registry/model_registry.dart';
import '../download/model_download_service.dart';

/// Service for managing AI models with registry, download, and storage dependencies.
class IntelligentModelManager {
  final ModelStorageManager _storageManager;
  final ModelRegistry _registry;
  final ModelDownloadService _downloadService;

  IntelligentModelManager(
    this._storageManager,
    this._registry,
    this._downloadService,
  );

  /// Lists all models registered in the catalog with their current download status.
  Future<List<ModelEntry>> listModels() async {
    final models = _registry.allModels;
    final entries = <ModelEntry>[];

    for (final model in models) {
      final existingPath = await _storageManager.findExistingModelPath(
        model.id,
        model: model,
      );
      final isDownloaded = existingPath != null;

      entries.add(
        ModelEntry(
          id: model.id,
          name: model.name,
          version: model.version ?? '1.0.0',
          description: model.description ?? '',
          sizeBytes: model.fileSizeBytes,
          localPath: existingPath,
          isDownloaded: isDownloaded,
        ),
      );
    }
    return entries;
  }

  /// Initiates download of a model by its ID.
  Future<void> downloadModel(String modelId) async {
    final model = _registry.getModel(modelId);
    if (model == null) {
      throw ArgumentError('Model $modelId not found in registry');
    }
    _downloadService.downloadModel(model);
  }

  /// Deletes a model from local storage and updates its status in the registry.
  Future<void> deleteModel(String modelId) async {
    await _downloadService.deleteModel(modelId);
    _registry.markAsRemoved(modelId);
  }
}
