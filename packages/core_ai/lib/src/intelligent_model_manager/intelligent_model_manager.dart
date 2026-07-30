import '../download/model_download_service.dart';
import '../models/model_credibility.dart';
import '../models/offline_model_info.dart';
import '../registry/model_registry.dart';
import '../storage/model_storage_manager.dart';
import 'model_entry.dart';
import 'model_manager_contracts.dart';

/// Unified, reusable lifecycle service for catalog models.
class IntelligentModelManager {
  factory IntelligentModelManager(
    ModelStorageManager storageManager,
    ModelRegistry registry,
    ModelDownloadService downloadService, {
    ModelWarmupGateway? warmupGateway,
    ModelPreloadPreferences? preloadPreferences,
    ModelActivationGateway? activationGateway,
  }) {
    return IntelligentModelManager._(
      storageManager,
      registry,
      downloadService,
      warmupGateway,
      preloadPreferences ?? const EmptyModelPreloadPreferences(),
      activationGateway,
    );
  }

  IntelligentModelManager._(
    this._storageManager,
    this._registry,
    this._downloadService,
    this._warmupGateway,
    this._preloadPreferences,
    this._activationGateway,
  );

  final ModelStorageManager _storageManager;
  final ModelRegistry _registry;
  final ModelDownloadService _downloadService;
  final ModelWarmupGateway? _warmupGateway;
  final ModelPreloadPreferences _preloadPreferences;
  final ModelActivationGateway? _activationGateway;
  Set<String>? _recommendedModelIds;

  /// Returns all manager sections from one consistent refresh operation.
  Future<ModelManagerSnapshot> snapshot({String? activeModelId}) async {
    final recommendedIdsFuture = _loadRecommendedModelIds();
    final preloadIdsFuture = _preloadPreferences.loadModelIds();
    final queueFuture = _downloadService.restoreQueue(
      catalogModels: _registry.allModels,
    );
    final storageUsedBytesFuture = _downloadService.getStorageUsed();
    final recommendedIds = await recommendedIdsFuture;
    final preloadIds = await preloadIdsFuture;
    final queue = await queueFuture;
    final storageUsedBytes = await storageUsedBytesFuture;

    final models = await listModels(
      activeModelId: activeModelId,
      recommendedModelIds: recommendedIds,
      preloadModelIds: preloadIds,
      residentModelIds: _warmupGateway?.residentModelIds ?? const <String>{},
    );
    return ModelManagerSnapshot(
      models: models,
      downloadQueue: queue,
      storageUsedBytes: storageUsedBytes,
    );
  }

  Future<Set<String>> _loadRecommendedModelIds() async {
    final cached = _recommendedModelIds;
    if (cached != null) return cached;
    final compatible = [...await _registry.getCompatibleModels()]
      ..sort((left, right) {
        final leftOfficial = left.credibility == ModelCredibility.official
            ? 0
            : 1;
        final rightOfficial = right.credibility == ModelCredibility.official
            ? 0
            : 1;
        final trustOrder = leftOfficial.compareTo(rightOfficial);
        if (trustOrder != 0) return trustOrder;
        return left.fileSizeBytes.compareTo(right.fileSizeBytes);
      });
    return _recommendedModelIds = compatible
        .take(3)
        .map((model) => model.id)
        .toSet();
  }

  /// Lists catalog models with truthful install and update state.
  Future<List<ModelEntry>> listModels({
    String? activeModelId,
    Set<String> recommendedModelIds = const <String>{},
    Set<String> preloadModelIds = const <String>{},
    Set<String> residentModelIds = const <String>{},
  }) async {
    final entries = <ModelEntry>[];
    for (final model in _registry.allModels) {
      final existingPath = await _storageManager.findExistingModelPath(
        model.id,
        model: model,
      );
      final receipt = existingPath == null
          ? null
          : await _storageManager.readInstallReceipt(model.id);
      final updateState = existingPath == null
          ? ModelUpdateState.notInstalled
          : receipt == null
          ? ModelUpdateState.unknown
          : receipt.catalogFingerprint ==
                _storageManager.catalogFingerprint(model)
          ? ModelUpdateState.upToDate
          : ModelUpdateState.updateAvailable;

      entries.add(
        ModelEntry(
          id: model.id,
          name: model.name,
          version: model.version ?? 'Unversioned',
          installedVersion: receipt?.version,
          description: model.description ?? '',
          sizeBytes: model.fileSizeBytes,
          isDownloaded: existingPath != null,
          isActive: model.id == activeModelId,
          isRecommended: recommendedModelIds.contains(model.id),
          preloadFrequentlyUsed: preloadModelIds.contains(model.id),
          isResident: residentModelIds.contains(model.id),
          updateState: updateState,
        ),
      );
    }
    return entries;
  }

  Future<void> downloadModel(String modelId) async {
    final model = _requireModel(modelId);
    _downloadService.downloadModel(model);
  }

  /// Uses the same verified download path; the prior artifact is replaced only
  /// after native verification and atomic promotion succeeds.
  Future<void> updateModel(String modelId) => downloadModel(modelId);

  Future<void> pauseDownload(String modelId) =>
      _downloadService.pauseDownload(modelId);

  Future<void> resumeDownload(String modelId) =>
      _downloadService.resumeDownload(modelId);

  Future<void> retryDownload(String modelId) {
    final model = _requireModel(modelId);
    return _downloadService.retryDownload(modelId, model: model);
  }

  /// Clears stale/partial files before starting a clean verified download.
  Future<void> repairModel(String modelId) {
    final model = _requireModel(modelId);
    return _downloadService.repairModel(model);
  }

  Future<void> cancelDownload(String modelId) =>
      _downloadService.cancelDownload(modelId);

  Future<void> setPreloadFrequentlyUsed(String modelId, bool enabled) async {
    _requireModel(modelId);
    await _preloadPreferences.setEnabled(modelId, enabled);
  }

  Future<void> activateModel(String modelId) async {
    final model = _requireModel(modelId);
    final installed = await _storageManager.findExistingModelPath(
      model.id,
      model: model,
    );
    if (installed == null) {
      throw StateError('Model $modelId is not installed');
    }
    final gateway = _activationGateway;
    if (gateway == null) {
      throw UnsupportedError('No model activation adapter is available');
    }
    await gateway.activate(model.copyWith(filePath: installed));
  }

  Future<ModelWarmupResult> warmModel(String modelId) async {
    final model = _requireModel(modelId);
    final installed = await _storageManager.findExistingModelPath(
      model.id,
      model: model,
    );
    if (installed == null) {
      return ModelWarmupResult(
        modelId: modelId,
        status: ModelWarmupStatus.unavailable,
        detail: 'model_not_installed',
      );
    }
    final gateway = _warmupGateway;
    if (gateway == null) {
      return ModelWarmupResult(
        modelId: modelId,
        status: ModelWarmupStatus.unavailable,
        detail: 'runtime_adapter_unavailable',
      );
    }
    return gateway.warm(model.copyWith(filePath: installed));
  }

  /// Checks the live artifact location instead of trusting persisted model
  /// metadata. Diagnostics use this before showing a model as downloaded.
  Future<bool> isModelInstalled(String modelId) async {
    final model = _requireModel(modelId);
    return await _storageManager.findExistingModelPath(
          model.id,
          model: model,
        ) !=
        null;
  }

  Future<void> deleteModel(String modelId) async {
    final model = _requireModel(modelId);
    await _downloadService.deleteModel(modelId);
    await _preloadPreferences.setEnabled(modelId, false);
    await _activationGateway?.clear(model);
    _registry.markAsRemoved(modelId);
  }

  OfflineModelInfo _requireModel(String modelId) {
    final model = _registry.getModel(modelId);
    if (model == null) {
      throw ArgumentError('Model $modelId not found in registry');
    }
    return model;
  }
}
