import 'dart:async';
import 'dart:developer' as developer;

import 'package:core_domain/core_domain.dart';

import 'active_model_service.dart';
import 'gguf_model_config.dart';
import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';
import 'openai_compatible_client.dart';

/// LLM client implementation for GGUF models (llama.cpp compatible).
///
/// Uses the [ActiveModelService] to manage model lifecycle and
/// provides inference capabilities through llama.cpp FFI.
class GGUFModelClient implements LLMClient {
  static const localBackendUnavailableMessage =
      'Local GGUF inference is unavailable because the llama.cpp native backend is not installed. '
      'Configure an OpenAI-compatible llama.cpp, Ollama, or LM Studio server instead.';

  GGUFModelClient({
    required GGUFModelConfig modelConfig,
    LLMConfig? llmConfig,
    ActiveModelService? activeModelService,
    OpenAICompatibleClient? remoteClient,
  }) : _modelConfig = modelConfig,
       _llmConfig = llmConfig ?? _defaultConfig(modelConfig),
       _activeModelService = activeModelService ?? ActiveModelService.instance,
       _remoteClient =
           remoteClient ??
           (modelConfig.hasRemoteServer
               ? OpenAICompatibleClient(
                   baseUrl: modelConfig.serverUrl!,
                   model: modelConfig.modelName,
                   apiKey: modelConfig.serverApiKey,
                 )
               : null);

  final GGUFModelConfig _modelConfig;
  final LLMConfig _llmConfig;
  final ActiveModelService _activeModelService;
  final OpenAICompatibleClient? _remoteClient;

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
    if (_remoteClient != null) {
      return Failure(
        ValidationFailure(
          message: 'Remote GGUF server models do not load into local memory.',
        ),
      );
    }
    return Failure(ValidationFailure(message: localBackendUnavailableMessage));
  }

  @override
  Future<bool> isAvailable() async {
    if (_remoteClient != null) return _remoteClient.isAvailable();
    // A path is only an artifact; do not claim readiness without a native
    // llama.cpp execution backend.
    return false;
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    if (_remoteClient != null) return _remoteClient.generate(prompt);
    return Failure(ValidationFailure(message: localBackendUnavailableMessage));
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (_remoteClient != null) {
      yield* _remoteClient.generateStream(prompt);
      return;
    }
    yield '[Error: $localBackendUnavailableMessage]';
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {
    await _remoteClient?.dispose();
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
