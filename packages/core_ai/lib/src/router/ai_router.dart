import 'package:core_domain/core_domain.dart';

import '../client/llm_client.dart';
import '../provider/ai_provider.dart';

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

  const AIRouterConfig({
    this.defaultStrategy = AIRoutingStrategy.onDevicePreferred,
    this.userPreference,
    this.onDeviceMaxPromptLength = 1024,
    this.autoFallback = true,
  });

  const AIRouterConfig.localOnly({this.onDeviceMaxPromptLength = 1024})
    : defaultStrategy = AIRoutingStrategy.onDeviceOnly,
      userPreference = null,
      autoFallback = false;

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

  /// Get the appropriate client based on strategy and availability.
  Future<LLMClient?> _selectClient({String? prompt}) async {
    final strategy = config.defaultStrategy;

    // Check if prompt is too long for on-device
    final promptTooLong =
        prompt != null && prompt.length > config.onDeviceMaxPromptLength;

    switch (strategy) {
      case AIRoutingStrategy.onDeviceOnly:
        if (onDeviceClient != null && await onDeviceClient!.isAvailable()) {
          return onDeviceClient;
        }
        return null;

      case AIRoutingStrategy.cloudOnly:
        if (cloudClient != null && await cloudClient!.isAvailable()) {
          return cloudClient;
        }
        return null;

      case AIRoutingStrategy.onDevicePreferred:
        if (!promptTooLong &&
            onDeviceClient != null &&
            await onDeviceClient!.isAvailable()) {
          return onDeviceClient;
        }
        if (cloudClient != null && await cloudClient!.isAvailable()) {
          return cloudClient;
        }
        return onDeviceClient;

      case AIRoutingStrategy.cloudPreferred:
        if (cloudClient != null && await cloudClient!.isAvailable()) {
          return cloudClient;
        }
        if (onDeviceClient != null && await onDeviceClient!.isAvailable()) {
          return onDeviceClient;
        }
        return cloudClient;

      case AIRoutingStrategy.userChoice:
        final preferred = config.userPreference;
        if (preferred == AIProvider.nano) {
          return onDeviceClient ?? cloudClient;
        } else if (preferred == AIProvider.cloud) {
          return cloudClient ?? onDeviceClient;
        }
        // Default to on-device preferred
        return onDeviceClient ?? cloudClient;
    }
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

    // Return success if at least one initialized
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
    final client = await _selectClient(prompt: prompt);
    if (client == null) {
      return Err(_unavailableError(), StackTrace.current);
    }

    final result = await client.generateText(prompt, config: config);

    // Try fallback on error unless the request is explicitly local-only.
    if (result.isErr && this.config.autoFallback && !this.config.isLocalOnly) {
      final fallback = client == onDeviceClient ? cloudClient : onDeviceClient;
      if (fallback != null && await fallback.isAvailable()) {
        return fallback.generateText(prompt, config: config);
      }
    }

    return result;
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
    final client = await _selectClient(prompt: prompt);
    if (client == null) {
      return Err(_unavailableError(), StackTrace.current);
    }
    return client.chat(messages, config: config);
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
    final client = await _selectClient(prompt: text);
    if (client == null) {
      return Err(_unavailableError(), StackTrace.current);
    }
    return client.classify(text, categories, config: config);
  }

  @override
  Future<Result<String>> summarize(
    String text, {
    int? maxLength,
    GenerationConfig? config,
  }) async {
    final client = await _selectClient(prompt: text);
    if (client == null) {
      return Err(_unavailableError(), StackTrace.current);
    }
    return client.summarize(text, maxLength: maxLength, config: config);
  }

  @override
  Future<void> dispose() async {
    await onDeviceClient?.dispose();
    await cloudClient?.dispose();
  }
}
