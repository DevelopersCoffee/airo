import 'dart:async';
import 'dart:developer' as developer;

import 'package:core_domain/core_domain.dart';

import 'active_model_service.dart';
import 'gguf_model_config.dart';
import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';

/// LLM client implementation for GGUF models (llama.cpp compatible).
///
/// Uses the [ActiveModelService] to manage model lifecycle and
/// provides inference capabilities through llama.cpp FFI.
class GGUFModelClient implements LLMClient {
  GGUFModelClient({
    required GGUFModelConfig modelConfig,
    LLMConfig? llmConfig,
    ActiveModelService? activeModelService,
  }) : _modelConfig = modelConfig,
       _llmConfig = llmConfig ?? _defaultConfig(modelConfig),
       _activeModelService = activeModelService ?? ActiveModelService.instance;

  final GGUFModelConfig _modelConfig;
  final LLMConfig _llmConfig;
  final ActiveModelService _activeModelService;

  /// Creates a default LLMConfig from GGUFModelConfig.
  static LLMConfig _defaultConfig(GGUFModelConfig config) {
    return LLMConfig(
      provider: 'gguf-${config.provider.name}',
      modelName: config.modelName,
      temperature: config.temperature,
      maxOutputTokens: config.maxTokens,
      topK: config.topK,
      topP: config.topP,
    );
  }

  @override
  LLMConfig get config => _llmConfig;

  @override
  int get maxContextLength => _modelConfig.contextSize;

  /// Gets the GGUF model configuration.
  GGUFModelConfig get modelConfig => _modelConfig;

  /// Ensures the model is loaded and ready.
  Future<Result<ActiveModelInfo>> ensureLoaded({
    ModelLoadProgressCallback? onProgress,
    ModelMemoryWarningCallback? onMemoryWarning,
  }) async {
    // Check if our model is already loaded
    final active = _activeModelService.activeModel;
    if (active != null &&
        active.isReady &&
        active.config.modelPath == _modelConfig.modelPath) {
      return Ok(active);
    }

    // Load our model (will unload any existing model)
    return _activeModelService.loadModel(
      _modelConfig,
      onProgress: onProgress,
      onMemoryWarning: onMemoryWarning,
    );
  }

  @override
  Future<bool> isAvailable() async {
    // Check if model file exists and service can load it
    final active = _activeModelService.activeModel;
    if (active != null &&
        active.isReady &&
        active.config.modelPath == _modelConfig.modelPath) {
      return true;
    }
    // For now, assume model is available if path is set
    // TODO: Add actual file existence check
    return _modelConfig.modelPath.isNotEmpty;
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    // Ensure model is loaded
    final loadResult = await ensureLoaded();
    if (loadResult is Err<ActiveModelInfo>) {
      return Failure(
        ServerFailure(
          message: 'Failed to load model: ${loadResult.error}',
          cause: loadResult.error as Object?,
        ),
      );
    }

    try {
      final stopwatch = Stopwatch()..start();

      // TODO: Replace with actual llama.cpp FFI inference
      // Stub implementation for now
      developer.log(
        'Generating response for prompt (${prompt.length} chars)',
        name: 'GGUFModelClient',
      );

      // Simulate inference time
      await Future.delayed(const Duration(milliseconds: 200));
      final result =
          '[GGUF Model Response - ${_modelConfig.modelName}] '
          'Inference not yet implemented. Prompt received: ${prompt.substring(0, prompt.length.clamp(0, 50))}...';

      stopwatch.stop();

      // Update performance metrics
      final tokensGenerated = estimateTokens(result);
      final tokensPerSecond =
          tokensGenerated / (stopwatch.elapsedMilliseconds / 1000);
      _activeModelService.updateMetrics(tokensPerSecond: tokensPerSecond);

      return Success(
        LLMResponse(
          text: result,
          provider: 'gguf-${_modelConfig.provider.name}',
          promptTokens: estimateTokens(prompt),
          completionTokens: tokensGenerated,
          latencyMs: stopwatch.elapsedMilliseconds,
          finishReason: 'stop',
        ),
      );
    } catch (e, stack) {
      developer.log(
        'GGUF inference failed: $e',
        name: 'GGUFModelClient',
        level: 1000,
        error: e,
        stackTrace: stack,
      );
      return Failure(
        ServerFailure(message: 'GGUF inference error: $e', cause: e),
      );
    }
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    // Ensure model is loaded
    final loadResult = await ensureLoaded();
    if (loadResult is Err<ActiveModelInfo>) {
      yield '[Error: Failed to load model: ${loadResult.error}]';
      return;
    }

    try {
      developer.log(
        'Streaming response for prompt (${prompt.length} chars)',
        name: 'GGUFModelClient',
      );

      // TODO: Replace with actual llama.cpp FFI streaming inference
      // Stub implementation that simulates streaming
      final words =
          '[GGUF Streaming - ${_modelConfig.modelName}] '
                  'Streaming inference not yet implemented.'
              .split(' ');

      for (final word in words) {
        await Future.delayed(const Duration(milliseconds: 50));
        yield '$word ';
      }
    } catch (e) {
      developer.log(
        'GGUF streaming failed: $e',
        name: 'GGUFModelClient',
        level: 1000,
        error: e,
      );
      yield '[Error: $e]';
    }
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {
    // Don't automatically unload the model on dispose
    // The ActiveModelService manages the model lifecycle
    developer.log(
      'GGUFModelClient disposed (model remains loaded)',
      name: 'GGUFModelClient',
    );
  }

  /// Unloads the model from memory.
  ///
  /// This is a convenience method that delegates to [ActiveModelService].
  Future<void> unloadModel() async {
    await _activeModelService.unloadModel();
  }
}
