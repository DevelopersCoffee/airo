import 'package:core_domain/core_domain.dart';

import '../client/llm_client.dart';
import '../provider/ai_provider.dart';
import 'fallback_chain.dart';
import 'model_health_checker.dart';

/// Strategy for selecting which AI provider to use.
enum AIRoutingStrategy {
  /// Always use on-device AI (Gemini Nano).
  onDeviceOnly,

  /// Always use cloud AI (Gemini API).
  cloudOnly,

  /// Prefer on-device, fallback to cloud if unavailable.
  onDevicePreferred,

  /// Prefer cloud, fallback to on-device if unavailable.
  cloudPreferred,

  /// Prefer an offline-capable runtime, fallback to cloud if needed.
  offlinePreferred,

  /// Prefer a specific configured provider, then fallback to the next best.
  specificModel,

  /// Let user choose.
  userChoice,
}

/// Explicit local-only policy for privacy-sensitive companion requests.
class LocalOnlyAiPolicy {
  const LocalOnlyAiPolicy({this.onDeviceMaxPromptLength = 1024});

  final int onDeviceMaxPromptLength;

  AIRouterConfig toRouterConfig() {
    return AIRouterConfig.localOnly(
      onDeviceMaxPromptLength: onDeviceMaxPromptLength,
    );
  }
}

/// Configuration for AI routing.
class AIRouterConfig {
  /// Default routing strategy.
  final AIRoutingStrategy defaultStrategy;

  /// User's preferred provider (for userChoice strategy).
  final AIProvider? userPreference;

  /// Maximum prompt length for on-device processing.
  /// Longer prompts will be routed to cloud.
  final int onDeviceMaxPromptLength;

  /// Whether to automatically fallback on errors.
  final bool autoFallback;

  /// Specific provider to prefer when using [AIRoutingStrategy.specificModel].
  final AIProvider? specificModel;

  /// Health checker used before provider selection and fallback.
  final ModelHealthChecker healthChecker;

  const AIRouterConfig({
    this.defaultStrategy = AIRoutingStrategy.onDevicePreferred,
    this.userPreference,
    this.onDeviceMaxPromptLength = 1024,
    this.autoFallback = true,
    this.specificModel,
    this.healthChecker = const ModelHealthChecker(),
  });

  const AIRouterConfig.localOnly({this.onDeviceMaxPromptLength = 1024})
    : defaultStrategy = AIRoutingStrategy.onDeviceOnly,
      userPreference = null,
      autoFallback = false,
      specificModel = null,
      healthChecker = const ModelHealthChecker();

  bool get isLocalOnly => defaultStrategy == AIRoutingStrategy.onDeviceOnly;
}

/// Routes AI requests to appropriate provider based on strategy.
class AIRouter implements LLMClient {
  final LLMClient? onDeviceClient;
  final LLMClient? cloudClient;
  final AIRouterConfig config;

  AIRouter({
    this.onDeviceClient,
    this.cloudClient,
    this.config = const AIRouterConfig(),
  });

  AppError _unavailableError() {
    if (config.isLocalOnly) {
      return AIError(
        'Local-only AI is active, but no on-device model is available.',
      );
    }
    return UnknownError('No AI provider available');
  }

  Future<AIProvider?> _selectProvider({String? prompt}) async {
    final promptTooLong =
        prompt != null && prompt.length > config.onDeviceMaxPromptLength;
    final preferredOrder = switch (config.defaultStrategy) {
      AIRoutingStrategy.onDeviceOnly => const [AIProvider.nano],
      AIRoutingStrategy.cloudOnly => const [AIProvider.cloud],
      AIRoutingStrategy.onDevicePreferred => [
        if (!promptTooLong) AIProvider.nano,
        AIProvider.cloud,
        AIProvider.nano,
      ],
      AIRoutingStrategy.cloudPreferred => const [
        AIProvider.cloud,
        AIProvider.nano,
      ],
      AIRoutingStrategy.offlinePreferred => const [
        AIProvider.nano,
        AIProvider.cloud,
      ],
      AIRoutingStrategy.specificModel => [
        if (config.specificModel != null) config.specificModel!,
        if (config.specificModel != AIProvider.nano && !promptTooLong)
          AIProvider.nano,
        if (config.specificModel != AIProvider.cloud) AIProvider.cloud,
      ],
      AIRoutingStrategy.userChoice => [
        if (config.userPreference != null) config.userPreference!,
        if (!promptTooLong) AIProvider.nano,
        AIProvider.cloud,
      ],
    };

    final fallbackChain = FallbackChain(preferredOrder);
    for (final provider in fallbackChain.chain) {
      final health = await config.healthChecker.check(
        provider,
        _clientForProvider(provider),
      );
      if (health.isHealthy) {
        return provider;
      }
    }
    return null;
  }

  LLMClient? _clientForProvider(AIProvider? provider) {
    if (provider == null) {
      return null;
    }
    if (provider == AIProvider.cloud) {
      return cloudClient;
    }
    if (provider.isOnDevice) {
      return onDeviceClient;
    }
    return null;
  }

  FallbackChain _fallbackChainFor(AIProvider primary, {String? prompt}) {
    final promptTooLong =
        prompt != null && prompt.length > config.onDeviceMaxPromptLength;
    return FallbackChain([
      primary,
      if (primary != AIProvider.nano && !promptTooLong) AIProvider.nano,
      if (primary != AIProvider.cloud) AIProvider.cloud,
    ]);
  }

  Future<Result<T>> _executeWithFallback<T>(
    String prompt,
    Future<Result<T>> Function(LLMClient client) request,
  ) async {
    final primaryProvider = await _selectProvider(prompt: prompt);
    final primaryClient = _clientForProvider(primaryProvider);
    if (primaryProvider == null || primaryClient == null) {
      return Err(_unavailableError(), StackTrace.current);
    }

    final result = await request(primaryClient);
    if (!result.isErr || !config.autoFallback || config.isLocalOnly) {
      return result;
    }

    for (final provider in _fallbackChainFor(
      primaryProvider,
      prompt: prompt,
    ).alternativesFor(primaryProvider)) {
      final client = _clientForProvider(provider);
      final health = await config.healthChecker.check(provider, client);
      if (!health.isHealthy || client == null) {
        continue;
      }
      return request(client);
    }

    return result;
  }

  /// Get the appropriate client based on strategy and availability.
  Future<LLMClient?> _selectClient({String? prompt}) async {
    final provider = await _selectProvider(prompt: prompt);
    return _clientForProvider(provider);
  }

  @override
  Future<bool> isAvailable() async {
    final client = await _selectClient();
    return client != null && await client.isAvailable();
  }

  @override
  Future<Result<void>> initialize() async {
    final results = <Result<void>>[];

    if (onDeviceClient != null) {
      results.add(await onDeviceClient!.initialize());
    }
    if (cloudClient != null) {
      results.add(await cloudClient!.initialize());
    }

    if (results.any((r) => r.isOk)) {
      return Ok(null);
    }
    return Err(UnknownError('No AI providers available'), StackTrace.current);
  }

  @override
  Future<Result<GenerationResult>> generateText(
    String prompt, {
    GenerationConfig? config,
  }) async {
    return _executeWithFallback(
      prompt,
      (client) => client.generateText(prompt, config: config),
    );
  }

  @override
  Stream<Result<String>> generateTextStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    final client = await _selectClient(prompt: prompt);
    if (client == null) {
      yield Err(_unavailableError(), StackTrace.current);
      return;
    }

    yield* client.generateTextStream(prompt, config: config);
  }

  @override
  Future<Result<GenerationResult>> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    final prompt = messages.map((m) => m.content).join(' ');
    return _executeWithFallback(
      prompt,
      (client) => client.chat(messages, config: config),
    );
  }

  @override
  Stream<Result<String>> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    final prompt = messages.map((m) => m.content).join(' ');
    final client = await _selectClient(prompt: prompt);
    if (client == null) {
      yield Err(_unavailableError(), StackTrace.current);
      return;
    }
    yield* client.chatStream(messages, config: config);
  }

  @override
  Future<Result<String>> classify(
    String text,
    List<String> categories, {
    GenerationConfig? config,
  }) async {
    return _executeWithFallback(
      text,
      (client) => client.classify(text, categories, config: config),
    );
  }

  @override
  Future<Result<String>> summarize(
    String text, {
    int? maxLength,
    GenerationConfig? config,
  }) async {
    return _executeWithFallback(
      text,
      (client) => client.summarize(text, maxLength: maxLength, config: config),
    );
  }

  @override
  Future<void> dispose() async {
    await onDeviceClient?.dispose();
    await cloudClient?.dispose();
  }
}
