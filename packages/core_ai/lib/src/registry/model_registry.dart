import 'dart:async';
import 'dart:developer' as developer;

import '../device/device_capability_service.dart';
import '../device/memory_budget_manager.dart';
import '../device/memory_severity.dart';
import '../models/model_credibility.dart';
import '../models/offline_model_info.dart';

/// Result of a device compatibility check for a model.
class ModelCompatibilityResult {
  const ModelCompatibilityResult({
    required this.isCompatible,
    required this.memorySeverity,
    this.reason,
    this.availableMemoryMB = 0,
    this.requiredMemoryMB = 0,
  });

  /// Whether the model can run on this device.
  final bool isCompatible;

  /// Memory severity level for loading this model.
  final MemorySeverity memorySeverity;

  /// Reason for incompatibility (if not compatible).
  final String? reason;

  /// Available memory in MB.
  final double availableMemoryMB;

  /// Required memory in MB.
  final double requiredMemoryMB;

  factory ModelCompatibilityResult.compatible(MemorySeverity severity) {
    return ModelCompatibilityResult(
      isCompatible: true,
      memorySeverity: severity,
    );
  }

  factory ModelCompatibilityResult.incompatible(String reason) {
    return ModelCompatibilityResult(
      isCompatible: false,
      memorySeverity: MemorySeverity.blocked,
      reason: reason,
    );
  }
}

/// Service for managing the registry of available offline LLM models.
///
/// Provides methods to:
/// - Register and unregister models
/// - Query available models with filtering
/// - Check device compatibility
/// - Track downloaded vs available models
class ModelRegistry {
  ModelRegistry({
    this._loadMemoryInfo,
    DeviceCapabilityService? deviceCapabilityService,
    MemoryBudgetManager? memoryBudgetManager,
  }) : _deviceService = deviceCapabilityService ?? DeviceCapabilityService(),
       _memoryBudgetManager =
           memoryBudgetManager ??
           MemoryBudgetManager(
             deviceCapability:
                 deviceCapabilityService ?? DeviceCapabilityService(),
           );

  final DeviceCapabilityService _deviceService;
  final Future<MemoryInfo> Function()? _loadMemoryInfo;
  final MemoryBudgetManager _memoryBudgetManager;
  final Map<String, OfflineModelInfo> _models = {};
  final _changeController = StreamController<ModelRegistryEvent>.broadcast();

  /// Stream of registry change events.
  Stream<ModelRegistryEvent> get changes => _changeController.stream;

  /// Gets all registered models.
  List<OfflineModelInfo> get allModels => List.unmodifiable(_models.values);

  /// Gets only downloaded (locally available) models.
  List<OfflineModelInfo> get downloadedModels =>
      _models.values.where((m) => m.isDownloaded).toList();

  /// Gets only models available for download.
  List<OfflineModelInfo> get availableModels =>
      _models.values.where((m) => !m.isDownloaded).toList();

  /// Number of registered models.
  int get modelCount => _models.length;

  /// Number of downloaded models.
  int get downloadedCount => downloadedModels.length;

  /// Registers a model in the registry.
  void registerModel(OfflineModelInfo model) {
    final isNew = !_models.containsKey(model.id);
    _models[model.id] = model;

    developer.log(
      '${isNew ? 'Registered' : 'Updated'} model: ${model.name}',
      name: 'ModelRegistry',
    );

    _changeController.add(
      isNew
          ? ModelRegistryEvent.added(model)
          : ModelRegistryEvent.updated(model),
    );
  }

  /// Registers multiple models at once.
  void registerModels(Iterable<OfflineModelInfo> models) {
    for (final model in models) {
      registerModel(model);
    }
  }

  /// Unregisters a model from the registry.
  bool unregisterModel(String modelId) {
    final model = _models.remove(modelId);
    if (model != null) {
      developer.log('Unregistered model: ${model.name}', name: 'ModelRegistry');
      _changeController.add(ModelRegistryEvent.removed(model));
      return true;
    }
    return false;
  }

  /// Gets a model by its ID.
  OfflineModelInfo? getModel(String modelId) => _models[modelId];

  /// Checks if a model is registered.
  bool hasModel(String modelId) => _models.containsKey(modelId);

  /// Queries models with optional filters.
  List<OfflineModelInfo> queryModels({
    ModelFamily? family,
    ModelCredibility? minCredibility,
    ModelQuantization? quantization,
    bool? downloaded,
    bool? supportsVision,
    ModelModality? modality,
    ModelCapability? capability,
    String? language,
    int? maxFileSizeMB,
    String? searchQuery,
  }) {
    return _models.values.where((model) {
      if (family != null && model.family != family) return false;
      if (minCredibility != null &&
          model.credibility.trustScore < minCredibility.trustScore) {
        return false;
      }
      if (quantization != null && model.quantization != quantization) {
        return false;
      }
      if (downloaded != null && model.isDownloaded != downloaded) return false;
      if (supportsVision == true && !model.supportsVision) return false;
      if (modality != null && !model.modalities.contains(modality)) {
        return false;
      }
      if (capability != null && !model.capabilities.contains(capability)) {
        return false;
      }
      if (language != null && !model.languages.contains(language)) return false;
      if (maxFileSizeMB != null && model.fileSizeMB > maxFileSizeMB) {
        return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!model.name.toLowerCase().contains(query) &&
            !(model.description?.toLowerCase().contains(query) ?? false) &&
            !model.tags.any((t) => t.toLowerCase().contains(query))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Checks if a model is compatible with the current device.
  Future<ModelCompatibilityResult> checkCompatibility(
    OfflineModelInfo model,
  ) async {
    try {
      final memoryInfo =
          await (_loadMemoryInfo?.call() ?? _deviceService.getMemoryInfo());
      final requiredBytes = model.estimatedMinMemoryBytes;

      if (!memoryInfo.isAvailable) {
        return ModelCompatibilityResult(
          isCompatible: true,
          memorySeverity: MemorySeverity.warning,
          requiredMemoryMB: requiredBytes / (1024 * 1024),
        );
      }

      final severity = _memoryBudgetManager.checkMemoryForModel(
        requiredBytes,
        memoryInfo,
      );
      final requiredMemoryMB = requiredBytes / (1024 * 1024);
      final availableMemoryMB = memoryInfo.availableMB;

      if (severity == MemorySeverity.blocked) {
        final budgetBytes = _memoryBudgetManager.calculateBudget(memoryInfo);
        return ModelCompatibilityResult(
          isCompatible: false,
          memorySeverity: severity,
          reason:
              'Insufficient device memory budget. Need '
              '${_formatMemory(requiredBytes)}, but this device budget is '
              '${_formatMemory(budgetBytes)}.',
          availableMemoryMB: availableMemoryMB,
          requiredMemoryMB: requiredMemoryMB,
        );
      }

      final lowTransientMemory = memoryInfo.availableBytes < requiredBytes;
      final reason = lowTransientMemory
          ? 'This package fits the device budget, but only '
                '${_formatMemory(memoryInfo.availableBytes)} is currently free. '
                'It needs ${_formatMemory(requiredBytes)} available to warm up cleanly.'
          : null;

      return ModelCompatibilityResult(
        isCompatible: true,
        memorySeverity: severity,
        reason: reason,
        availableMemoryMB: availableMemoryMB,
        requiredMemoryMB: requiredMemoryMB,
      );
    } catch (e) {
      developer.log(
        'Error checking compatibility: $e',
        name: 'ModelRegistry',
        level: 900,
      );
      // Return compatible with warning on error
      return ModelCompatibilityResult.compatible(MemorySeverity.warning);
    }
  }

  String _formatMemory(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    if (megabytes >= 1024) {
      return '${(megabytes / 1024).toStringAsFixed(1)} GB';
    }
    return '${megabytes.toStringAsFixed(0)} MB';
  }

  /// Gets compatible models for the current device.
  Future<List<OfflineModelInfo>> getCompatibleModels() async {
    final results = <OfflineModelInfo>[];
    for (final model in _models.values) {
      final compat = await checkCompatibility(model);
      if (compat.isCompatible) {
        results.add(model);
      }
    }
    return results;
  }

  /// Updates a model's download status.
  void markAsDownloaded(String modelId, String filePath) {
    final model = _models[modelId];
    if (model != null) {
      final updated = model.copyWith(filePath: filePath);
      _models[modelId] = updated;
      _changeController.add(ModelRegistryEvent.updated(updated));
    }
  }

  /// Marks a model as not downloaded (file deleted).
  void markAsRemoved(String modelId) {
    final model = _models[modelId];
    if (model != null) {
      final updated = model.copyWith(filePath: null);
      _models[modelId] = updated;
      _changeController.add(ModelRegistryEvent.updated(updated));
    }
  }

  /// Clears all registered models.
  void clear() {
    _models.clear();
    _changeController.add(const ModelRegistryEvent.cleared());
  }

  /// Disposes of resources.
  void dispose() {
    _changeController.close();
  }
}

/// Events emitted by the ModelRegistry.
sealed class ModelRegistryEvent {
  const ModelRegistryEvent();

  const factory ModelRegistryEvent.added(OfflineModelInfo model) =
      ModelAddedEvent;
  const factory ModelRegistryEvent.updated(OfflineModelInfo model) =
      ModelUpdatedEvent;
  const factory ModelRegistryEvent.removed(OfflineModelInfo model) =
      ModelRemovedEvent;
  const factory ModelRegistryEvent.cleared() = RegistryClearedEvent;
}

class ModelAddedEvent extends ModelRegistryEvent {
  const ModelAddedEvent(this.model);
  final OfflineModelInfo model;
}

class ModelUpdatedEvent extends ModelRegistryEvent {
  const ModelUpdatedEvent(this.model);
  final OfflineModelInfo model;
}

class ModelRemovedEvent extends ModelRegistryEvent {
  const ModelRemovedEvent(this.model);
  final OfflineModelInfo model;
}

class RegistryClearedEvent extends ModelRegistryEvent {
  const RegistryClearedEvent();
}
