import 'package:core_domain/core_domain.dart';
import 'llm_client.dart';

/// Fake LLM client for testing and development.
///
/// Returns configurable responses for testing different scenarios.
class FakeLLMClient implements LLMClient {
  /// Default response for generateText.
  String defaultResponse;

  /// Delay to simulate network/processing latency.
  Duration latency;

  /// Whether the client should simulate being unavailable.
  bool simulateUnavailable;

  /// Whether the client should simulate errors.
  bool simulateError;

  /// Error message when simulating errors.
  String errorMessage;

  /// Responses for specific prompts (prompt -> response).
  final Map<String, String> promptResponses;

  /// Classification responses (text -> category).
  final Map<String, String> classificationResponses;

  /// Track calls for verification in tests.
  final List<String> generateTextCalls = [];
  final List<List<ChatMessage>> chatCalls = [];
  final List<String> classifyCalls = [];
  final List<String> summarizeCalls = [];

  FakeLLMClient({
    this.defaultResponse = 'This is a fake response.',
    this.latency = Duration.zero,
    this.simulateUnavailable = false,
    this.simulateError = false,
    this.errorMessage = 'Simulated error',
    Map<String, String>? promptResponses,
    Map<String, String>? classificationResponses,
  }) : promptResponses = promptResponses ?? {},
       classificationResponses = classificationResponses ?? {};

  @override
  Future<bool> isAvailable() async {
    await Future.delayed(latency);
    return !simulateUnavailable;
  }

  @override
  Future<Result<void>> initialize() async {
    await Future.delayed(latency);
    if (simulateUnavailable) {
      return Err(UnknownError('Client unavailable'), StackTrace.current);
    }
    return Ok(null);
  }

  @override
  Future<Result<GenerationResult>> generateText(
    String prompt, {
    GenerationConfig? config,
  }) async {
    generateTextCalls.add(prompt);
    await Future.delayed(latency);

    if (simulateError) {
      return Err(UnknownError(errorMessage), StackTrace.current);
    }

    final response = promptResponses[prompt] ?? defaultResponse;
    return Ok(GenerationResult(content: response, latency: latency));
  }

  @override
  Stream<Result<String>> generateTextStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    generateTextCalls.add(prompt);

    if (simulateError) {
      yield Err(UnknownError(errorMessage), StackTrace.current);
      return;
    }

    final response = promptResponses[prompt] ?? defaultResponse;
    final words = response.split(' ');

    for (final word in words) {
      await Future.delayed(latency);
      yield Ok('$word ');
    }
  }

  @override
  Future<Result<GenerationResult>> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    chatCalls.add(messages);
    await Future.delayed(latency);

    if (simulateError) {
      return Err(UnknownError(errorMessage), StackTrace.current);
    }

    final lastMessage = messages.isNotEmpty ? messages.last.content : '';
    final response = promptResponses[lastMessage] ?? defaultResponse;
    return Ok(GenerationResult(content: response, latency: latency));
  }

  @override
  Stream<Result<String>> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    chatCalls.add(messages);

    if (simulateError) {
      yield Err(UnknownError(errorMessage), StackTrace.current);
      return;
    }

    final lastMessage = messages.isNotEmpty ? messages.last.content : '';
    final response = promptResponses[lastMessage] ?? defaultResponse;
    final words = response.split(' ');

    for (final word in words) {
      await Future.delayed(latency);
      yield Ok('$word ');
    }
  }

  @override
  Future<Result<String>> classify(
    String text,
    List<String> categories, {
    GenerationConfig? config,
  }) async {
    classifyCalls.add(text);
    await Future.delayed(latency);

    if (simulateError) {
      return Err(UnknownError(errorMessage), StackTrace.current);
    }

    final category =
        classificationResponses[text] ??
        (categories.isNotEmpty ? categories.first : 'unknown');
    return Ok(category);
  }

  @override
  Future<Result<String>> summarize(
    String text, {
    int? maxLength,
    GenerationConfig? config,
  }) async {
    summarizeCalls.add(text);
    await Future.delayed(latency);

    if (simulateError) {
      return Err(UnknownError(errorMessage), StackTrace.current);
    }

    final summary =
        'Summary of: ${text.substring(0, text.length.clamp(0, 50))}...';
    return Ok(summary);
  }

  @override
  Future<void> dispose() async {
    // Nothing to dispose
  }

  /// Reset all tracked calls.
  void reset() {
    generateTextCalls.clear();
    chatCalls.clear();
    classifyCalls.clear();
    summarizeCalls.clear();
  }
}
