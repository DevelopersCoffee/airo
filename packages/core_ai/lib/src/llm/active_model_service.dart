import 'dart:async';
import 'dart:developer' as developer;

import 'package:core_domain/core_domain.dart';

import '../device/memory_budget_manager.dart';
import '../device/memory_severity.dart';
import 'gguf_model_config.dart';

/// Callback for model loading progress updates.
typedef ModelLoadProgressCallback =
    void Function(double progress, String status);

/// Callback for memory warning events.
typedef ModelMemoryWarningCallback = void Function(MemoryCheckResult result);

/// State of the active model.
enum ActiveModelState {
  /// No model is loaded.
  unloaded,

  /// Model is currently loading.
  loading,

  /// Model is loaded and ready for inference.
  ready,

  /// Model loading or inference failed.
  error,

  /// Model is being unloaded.
  unloading,
}

/// Information about the currently active model.
class ActiveModelInfo {
  const ActiveModelInfo({
    required this.config,
    required this.state,
    this.loadedAt,
    this.memoryUsageBytes,
    this.tokensPerSecond,
    this.errorMessage,
  });

  /// Configuration of the active model.
  final GGUFModelConfig config;

  /// Current state of the model.
  final ActiveModelState state;

  /// When the model was loaded.
  final DateTime? loadedAt;

  /// Current memory usage in bytes.
  final int? memoryUsageBytes;

  /// Inference speed in tokens per second.
  final double? tokensPerSecond;

  /// Error message if state is error.
  final String? errorMessage;

  /// Whether the model is ready for inference.
  bool get isReady => state == ActiveModelState.ready;

  /// Whether the model is currently loading.
  bool get isLoading => state == ActiveModelState.loading;

  ActiveModelInfo copyWith({
    GGUFModelConfig? config,
    ActiveModelState? state,
    DateTime? loadedAt,
    int? memoryUsageBytes,
    double? tokensPerSecond,
    String? errorMessage,
  }) => ActiveModelInfo(
    config: config ?? this.config,
    state: state ?? this.state,
    loadedAt: loadedAt ?? this.loadedAt,
    memoryUsageBytes: memoryUsageBytes ?? this.memoryUsageBytes,
    tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Singleton service for managing the active LLM model lifecycle.
///
/// Ensures only one model is loaded at a time to prevent memory issues.
/// Implements the singleton pattern from the reference implementation.
class ActiveModelService {
  ActiveModelService._internal({MemoryBudgetManager? memoryBudgetManager})
    : _memoryBudgetManager = memoryBudgetManager ?? MemoryBudgetManager();

  static ActiveModelService? _instance;

  /// Gets the singleton instance of ActiveModelService.
  static ActiveModelService get instance {
    _instance ??= ActiveModelService._internal();
    return _instance!;
  }

  /// Creates a new instance for testing purposes.
  /// In production, use [instance] instead.
  factory ActiveModelService.forTesting({
    MemoryBudgetManager? memoryBudgetManager,
  }) {
    return ActiveModelService._internal(
      memoryBudgetManager: memoryBudgetManager,
    );
  }

  /// Resets the singleton instance (for testing only).
  static void resetInstance() {
    _instance = null;
  }

  final MemoryBudgetManager _memoryBudgetManager;

  ActiveModelInfo? _activeModel;
  final _stateController = StreamController<ActiveModelInfo?>.broadcast();

  /// Stream of active model state changes.
  Stream<ActiveModelInfo?> get stateStream => _stateController.stream;

  /// Gets the currently active model info, or null if no model is loaded.
  ActiveModelInfo? get activeModel => _activeModel;

  /// Whether a model is currently loaded and ready.
  bool get hasActiveModel =>
      _activeModel != null && _activeModel!.state == ActiveModelState.ready;

  /// Whether a model is currently loading.
  bool get isLoading =>
      _activeModel != null && _activeModel!.state == ActiveModelState.loading;

  /// Loads a model with the given configuration.
  ///
  /// If another model is already loaded, it will be unloaded first.
  /// Returns a [Result] indicating success or failure.
  Future<Result<ActiveModelInfo>> loadModel(
    GGUFModelConfig config, {
    ModelLoadProgressCallback? onProgress,
    ModelMemoryWarningCallback? onMemoryWarning,
  }) async {
    developer.log(
      'Loading model: ${config.modelName}',
      name: 'ActiveModelService',
    );

    // Unload existing model if any
    if (_activeModel != null &&
        _activeModel!.state != ActiveModelState.unloaded) {
      await unloadModel();
    }

    // Check memory budget before loading
    final memoryCheck = await _memoryBudgetManager.checkModelFile(
      fileSizeBytes: config.estimatedMemoryBytes,
      type: ModelType.text,
    );

    if (memoryCheck.severity == MemorySeverity.blocked) {
      final error =
          'Insufficient memory to load model: ${memoryCheck.severity.description}. '
          'Estimated usage: ${memoryCheck.estimatedUsageMB.toStringAsFixed(0)}MB, '
          'Budget: ${memoryCheck.budgetMB.toStringAsFixed(0)}MB';
      developer.log(error, name: 'ActiveModelService', level: 1000);
      return Err(StateError(error), StackTrace.current);
    }

    if (memoryCheck.severity.shouldWarn) {
      onMemoryWarning?.call(memoryCheck);
    }

    // Update state to loading
    _activeModel = ActiveModelInfo(
      config: config,
      state: ActiveModelState.loading,
    );
    _stateController.add(_activeModel);
    onProgress?.call(0.0, 'Initializing model...');

    try {
      // Simulate model loading (actual implementation will use FFI)
      // TODO: Replace with actual llama.cpp FFI loading
      onProgress?.call(0.3, 'Loading model weights...');
      await Future.delayed(const Duration(milliseconds: 100));

      onProgress?.call(0.6, 'Initializing context...');
      await Future.delayed(const Duration(milliseconds: 100));

      onProgress?.call(0.9, 'Warming up...');
      await Future.delayed(const Duration(milliseconds: 50));

      // Update state to ready
      _activeModel = ActiveModelInfo(
        config: config,
        state: ActiveModelState.ready,
        loadedAt: DateTime.now(),
        memoryUsageBytes: config.estimatedMemoryBytes,
      );
      _stateController.add(_activeModel);
      onProgress?.call(1.0, 'Model ready');

      developer.log(
        'Model loaded successfully: ${config.modelName}',
        name: 'ActiveModelService',
      );

      return Ok(_activeModel!);
    } catch (e, stack) {
      developer.log(
        'Failed to load model: $e',
        name: 'ActiveModelService',
        level: 1000,
        error: e,
        stackTrace: stack,
      );

      _activeModel = ActiveModelInfo(
        config: config,
        state: ActiveModelState.error,
        errorMessage: e.toString(),
      );
      _stateController.add(_activeModel);

      return Err(e, stack);
    }
  }

  /// Unloads the currently active model.
  Future<void> unloadModel() async {
    if (_activeModel == null) return;

    developer.log(
      'Unloading model: ${_activeModel!.config.modelName}',
      name: 'ActiveModelService',
    );

    _activeModel = _activeModel!.copyWith(state: ActiveModelState.unloading);
    _stateController.add(_activeModel);

    try {
      // TODO: Replace with actual llama.cpp FFI cleanup
      await Future.delayed(const Duration(milliseconds: 50));

      _activeModel = null;
      _stateController.add(null);

      developer.log('Model unloaded', name: 'ActiveModelService');
    } catch (e, stack) {
      developer.log(
        'Error unloading model: $e',
        name: 'ActiveModelService',
        level: 900,
        error: e,
        stackTrace: stack,
      );
      // Force unload even on error
      _activeModel = null;
      _stateController.add(null);
    }
  }

  /// Switches to a different model.
  ///
  /// Convenience method that unloads the current model and loads the new one.
  Future<Result<ActiveModelInfo>> switchModel(
    GGUFModelConfig config, {
    ModelLoadProgressCallback? onProgress,
    ModelMemoryWarningCallback? onMemoryWarning,
  }) async {
    await unloadModel();
    return loadModel(
      config,
      onProgress: onProgress,
      onMemoryWarning: onMemoryWarning,
    );
  }

  /// Updates performance metrics for the active model.
  void updateMetrics({double? tokensPerSecond, int? memoryUsageBytes}) {
    if (_activeModel == null || _activeModel!.state != ActiveModelState.ready) {
      return;
    }

    _activeModel = _activeModel!.copyWith(
      tokensPerSecond: tokensPerSecond ?? _activeModel!.tokensPerSecond,
      memoryUsageBytes: memoryUsageBytes ?? _activeModel!.memoryUsageBytes,
    );
    _stateController.add(_activeModel);
  }

  /// Disposes of resources.
  Future<void> dispose() async {
    await unloadModel();
    await _stateController.close();
  }
}
