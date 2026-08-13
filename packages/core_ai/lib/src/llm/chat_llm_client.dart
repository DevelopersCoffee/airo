import 'package:core_domain/core_domain.dart';

/// Configuration for LLM generation.
class GenerationConfig {
  final double temperature;
  final int topK;
  final double topP;
  final int maxOutputTokens;
  final List<String>? stopSequences;

  const GenerationConfig({
    this.temperature = 0.7,
    this.topK = 40,
    this.topP = 0.95,
    this.maxOutputTokens = 1024,
    this.stopSequences,
  });

  GenerationConfig copyWith({
    double? temperature,
    int? topK,
    double? topP,
    int? maxOutputTokens,
    List<String>? stopSequences,
  }) {
    return GenerationConfig(
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      stopSequences: stopSequences ?? this.stopSequences,
    );
  }
}

/// Chat message for conversation context.
class ChatMessage {
  final String role;
  final String content;
  final DateTime? timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  factory ChatMessage.user(String content) =>
      ChatMessage(role: 'user', content: content, timestamp: DateTime.now());

  factory ChatMessage.assistant(String content) => ChatMessage(
    role: 'assistant',
    content: content,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.system(String content) =>
      ChatMessage(role: 'system', content: content);
}

/// Result of LLM generation.
class GenerationResult {
  final String content;
  final List<String> chunks;
  final int? tokenCount;
  final Duration? latency;

  const GenerationResult({
    required this.content,
    this.chunks = const [],
    this.tokenCount,
    this.latency,
  });
}

/// Abstract LLM client interface for the conversational (chat/classify/
/// summarize) surface used by [AIRouter] and its supporting router
/// utilities (`ModelHealthChecker`, `PromptExecutor`).
///
/// This is a deliberately distinct contract from [LLMClient] (declared in
/// `llm_client.dart` in this same directory): that interface is the one
/// implemented by the concrete provider clients (`GeminiApiClient`,
/// `GeminiNanoClient`, `GGUFModelClient`, `OpenAICompatibleClient`) and
/// routed by [LLMRouterImpl] via the public [LLMRouter] contract. `core_ai`
/// historically grew two independent client abstractions that never got
/// reconciled into one shape; unifying their method signatures is a larger,
/// higher-risk behavioral change than this refactor covers; see
/// https://github.com/DevelopersCoffee/airo/issues/1671 for the scoped fix
/// (relocate both stacks under `src/llm/`, remove the naming collision, and
/// dedupe their shared data types) that keeps both call sites working.
///
/// Implementations can be swapped between on-device (Nano) and cloud (API).
abstract interface class ChatLLMClient {
  /// Check if the client is available and ready.
  Future<bool> isAvailable();

  /// Initialize the client.
  Future<Result<void>> initialize();

  /// Generate text from a prompt.
  Future<Result<GenerationResult>> generateText(
    String prompt, {
    GenerationConfig? config,
  });

  /// Generate text with streaming response.
  Stream<Result<String>> generateTextStream(
    String prompt, {
    GenerationConfig? config,
  });

  /// Chat with conversation history.
  Future<Result<GenerationResult>> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  });

  /// Chat with streaming response.
  Stream<Result<String>> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  });

  /// Classify text into categories.
  Future<Result<String>> classify(
    String text,
    List<String> categories, {
    GenerationConfig? config,
  });

  /// Summarize text.
  Future<Result<String>> summarize(
    String text, {
    int? maxLength,
    GenerationConfig? config,
  });

  /// Dispose resources.
  Future<void> dispose();
}
