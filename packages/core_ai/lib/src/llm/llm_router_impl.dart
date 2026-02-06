import 'dart:developer' as developer;

import 'package:core_domain/core_domain.dart';

import 'active_model_service.dart';
import 'gemini_api_client.dart';
import 'gemini_nano_client.dart';
import 'gguf_model_client.dart';
import 'gguf_model_config.dart';
import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';

/// Callback for memory-related events during LLM routing.
typedef MemoryWarningCallback = void Function(MemoryCheckResult memoryCheck);

/// Implementation of LLM router for selecting appropriate provider.
///
/// Includes memory-aware routing for on-device models and GGUF support.
class LLMRouterImpl implements LLMRouter {
  LLMRouterImpl({
    this.geminiNanoClient,
    this.geminiApiClient,
    this.mockClient,
    this.preferOnDevice = true,
    this.onMemoryWarning,
    ActiveModelService? activeModelService,
  }) : _activeModelService = activeModelService ?? ActiveModelService.instance;

  final GeminiNanoClient? geminiNanoClient;
  final GeminiApiClient? geminiApiClient;
  final LLMClient? mockClient;
  final bool preferOnDevice;
  final ActiveModelService _activeModelService;

  /// Currently loaded GGUF client (managed by ActiveModelService).
  GGUFModelClient? _ggufClient;

  /// Optional callback for memory warnings during on-device model loading.
  final MemoryWarningCallback? onMemoryWarning;

  /// Creates router with automatic client initialization.
  ///
  /// [geminiApiKey] - API key for Gemini Cloud API.
  /// [nanoConfig] - Configuration for Gemini Nano.
  /// [apiConfig] - Configuration for Gemini API.
  /// [preferOnDevice] - Whether to prefer on-device inference.
  /// [checkMemory] - Whether to check memory before creating Nano client.
  /// [onMemoryWarning] - Callback for memory warnings.
  static Future<LLMRouterImpl> create({
    String? geminiApiKey,
    LLMConfig? nanoConfig,
    LLMConfig? apiConfig,
    bool preferOnDevice = true,
    bool checkMemory = true,
    MemoryWarningCallback? onMemoryWarning,
  }) async {
    GeminiNanoClient? nanoClient;
    GeminiApiClient? apiClient;

    // Try to create Nano client if available (with memory check)
    nanoClient = await GeminiNanoClientFactory.createIfAvailable(
      config: nanoConfig,
      checkMemory: checkMemory,
      onMemoryWarning: (memoryCheck) {
        developer.log(
          'Memory warning for Gemini Nano: ${memoryCheck.severity.title}',
          name: 'LLMRouterImpl',
        );
        onMemoryWarning?.call(memoryCheck);
      },
    );

    // Create API client if key provided
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      apiClient = GeminiApiClient(apiKey: geminiApiKey, config: apiConfig);
    }

    return LLMRouterImpl(
      geminiNanoClient: nanoClient,
      geminiApiClient: apiClient,
      preferOnDevice: preferOnDevice,
      onMemoryWarning: onMemoryWarning,
    );
  }

  @override
  Future<LLMClient> route({
    required String prompt,
    bool preferOnDevice = true,
    bool requiresVision = false,
  }) async {
    // Vision requires cloud API
    if (requiresVision) {
      if (geminiApiClient != null) {
        return geminiApiClient!;
      }
      throw StateError(
        'Vision requires Gemini API but no API client available',
      );
    }

    // Check if prompt fits in Nano context
    final tokenCount = TokenCounter.estimate(prompt);
    final fitsInNano = tokenCount <= TokenCounter.geminiNanoMaxPromptTokens;

    // Prefer on-device if available and prompt fits
    if (preferOnDevice && fitsInNano && geminiNanoClient != null) {
      if (await geminiNanoClient!.isAvailable()) {
        return geminiNanoClient!;
      }
    }

    // Fall back to API
    if (geminiApiClient != null) {
      return geminiApiClient!;
    }

    // Fall back to mock for testing
    if (mockClient != null) {
      return mockClient!;
    }

    throw StateError('No LLM client available');
  }

  @override
  LLMClient? getProvider(LLMProvider provider) => switch (provider) {
    LLMProvider.geminiNano => geminiNanoClient,
    LLMProvider.geminiApi => geminiApiClient,
    LLMProvider.gguf => _ggufClient,
    LLMProvider.mock => mockClient,
  };

  /// Gets availability status of all providers.
  Future<Map<LLMProvider, bool>> getAvailability() async {
    final results = <LLMProvider, bool>{};

    if (geminiNanoClient != null) {
      results[LLMProvider.geminiNano] = await geminiNanoClient!.isAvailable();
    } else {
      results[LLMProvider.geminiNano] = false;
    }

    if (geminiApiClient != null) {
      results[LLMProvider.geminiApi] = await geminiApiClient!.isAvailable();
    } else {
      results[LLMProvider.geminiApi] = false;
    }

    results[LLMProvider.mock] = mockClient != null;

    return results;
  }

  /// Disposes all clients.
  Future<void> dispose() async {
    await geminiNanoClient?.dispose();
    await geminiApiClient?.dispose();
    await mockClient?.dispose();
    await _ggufClient?.dispose();
    // Note: ActiveModelService.dispose() should be called separately
    // as it's a singleton that may be shared across routers.
  }

  /// Loads a GGUF model and creates a client for it.
  ///
  /// Returns the [GGUFModelClient] for the loaded model.
  /// If another GGUF model is loaded, it will be unloaded first.
  Future<Result<GGUFModelClient>> loadGGUFModel(
    GGUFModelConfig config, {
    ModelLoadProgressCallback? onProgress,
    ModelMemoryWarningCallback? onMemoryWarning,
  }) async {
    developer.log(
      'Loading GGUF model: ${config.modelName}',
      name: 'LLMRouterImpl',
    );

    // Create client (will use ActiveModelService for loading)
    final client = GGUFModelClient(
      modelConfig: config,
      activeModelService: _activeModelService,
    );

    // Ensure model is loaded
    final loadResult = await client.ensureLoaded(
      onProgress: onProgress,
      onMemoryWarning: (memoryCheck) {
        developer.log(
          'Memory warning for GGUF: ${memoryCheck.severity.title}',
          name: 'LLMRouterImpl',
        );
        onMemoryWarning?.call(memoryCheck);
      },
    );

    if (loadResult is Err<ActiveModelInfo>) {
      return Err(loadResult.error, loadResult.stack);
    }

    _ggufClient = client;
    return Ok(client);
  }

  /// Gets the currently loaded GGUF client, if any.
  GGUFModelClient? get ggufClient => _ggufClient;

  /// Whether a GGUF model is currently loaded and ready.
  bool get hasGGUFModel => _activeModelService.hasActiveModel;

  /// Stream of GGUF model state changes.
  Stream<ActiveModelInfo?> get ggufModelStateStream =>
      _activeModelService.stateStream;

  /// Unloads the current GGUF model.
  Future<void> unloadGGUFModel() async {
    await _activeModelService.unloadModel();
    _ggufClient = null;
  }
}

/// Mock LLM client for testing.
class MockLLMClient implements LLMClient {
  MockLLMClient({
    this.mockResponse = 'Mock response',
    this.isAvailableValue = true,
  });

  final String mockResponse;
  final bool isAvailableValue;

  @override
  LLMConfig get config => const LLMConfig(provider: 'mock');

  @override
  int get maxContextLength => 4096;

  @override
  Future<bool> isAvailable() async => isAvailableValue;

  @override
  Future<Result<LLMResponse>> generate(String prompt) async => Success(
    LLMResponse(
      text: mockResponse,
      provider: 'mock',
      promptTokens: estimateTokens(prompt),
      completionTokens: estimateTokens(mockResponse),
      latencyMs: 0,
    ),
  );

  @override
  Stream<String> generateStream(String prompt) async* {
    for (final word in mockResponse.split(' ')) {
      yield '$word ';
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {}
}
