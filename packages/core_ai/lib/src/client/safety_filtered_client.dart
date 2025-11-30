import 'package:core_domain/core_domain.dart';
import 'llm_client.dart';
import 'safety_guardrails.dart';

/// LLM client wrapper that applies safety guardrails to inputs and outputs.
///
/// Wraps any LLMClient and filters both prompts and responses through
/// safety rules before processing.
class SafetyFilteredClient implements LLMClient {
  final LLMClient _delegate;
  final SafetyGuardrails _guardrails;

  SafetyFilteredClient({
    required LLMClient delegate,
    required SafetyGuardrails guardrails,
  })  : _delegate = delegate,
        _guardrails = guardrails;

  /// Create with default safety guardrails.
  factory SafetyFilteredClient.withDefaults(LLMClient delegate) {
    return SafetyFilteredClient(
      delegate: delegate,
      guardrails: SafetyGuardrails.withDefaults(),
    );
  }

  @override
  Future<bool> isAvailable() => _delegate.isAvailable();

  @override
  Future<Result<void>> initialize() => _delegate.initialize();

  @override
  Future<Result<GenerationResult>> generateText(
    String prompt, {
    GenerationConfig? config,
  }) async {
    // Check input
    final inputCheck = _guardrails.checkInput(prompt);
    if (inputCheck.isErr) {
      return Err(inputCheck.getErrorOrNull()!, StackTrace.current);
    }

    // Generate
    final result = await _delegate.generateText(prompt, config: config);

    // Check output
    return result.flatMap((genResult) {
      final outputCheck = _guardrails.checkOutput(genResult.content);
      if (outputCheck.isErr) {
        return Err(outputCheck.getErrorOrNull()!, StackTrace.current);
      }
      return Ok(genResult);
    });
  }

  @override
  Stream<Result<String>> generateTextStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    // Check input
    final inputCheck = _guardrails.checkInput(prompt);
    if (inputCheck.isErr) {
      yield Err(inputCheck.getErrorOrNull()!, StackTrace.current);
      return;
    }

    // Stream output (note: streaming output filtering is limited)
    yield* _delegate.generateTextStream(prompt, config: config);
  }

  @override
  Future<Result<GenerationResult>> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    // Check all user messages
    for (final message in messages.where((m) => m.role == 'user')) {
      final inputCheck = _guardrails.checkInput(message.content);
      if (inputCheck.isErr) {
        return Err(inputCheck.getErrorOrNull()!, StackTrace.current);
      }
    }

    // Generate
    final result = await _delegate.chat(messages, config: config);

    // Check output
    return result.flatMap((genResult) {
      final outputCheck = _guardrails.checkOutput(genResult.content);
      if (outputCheck.isErr) {
        return Err(outputCheck.getErrorOrNull()!, StackTrace.current);
      }
      return Ok(genResult);
    });
  }

  @override
  Stream<Result<String>> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    // Check all user messages
    for (final message in messages.where((m) => m.role == 'user')) {
      final inputCheck = _guardrails.checkInput(message.content);
      if (inputCheck.isErr) {
        yield Err(inputCheck.getErrorOrNull()!, StackTrace.current);
        return;
      }
    }

    yield* _delegate.chatStream(messages, config: config);
  }

  @override
  Future<Result<String>> classify(
    String text,
    List<String> categories, {
    GenerationConfig? config,
  }) async {
    final inputCheck = _guardrails.checkInput(text);
    if (inputCheck.isErr) {
      return Err(inputCheck.getErrorOrNull()!, StackTrace.current);
    }
    return _delegate.classify(text, categories, config: config);
  }

  @override
  Future<Result<String>> summarize(
    String text, {
    int? maxLength,
    GenerationConfig? config,
  }) async {
    final inputCheck = _guardrails.checkInput(text);
    if (inputCheck.isErr) {
      return Err(inputCheck.getErrorOrNull()!, StackTrace.current);
    }
    return _delegate.summarize(text, maxLength: maxLength, config: config);
  }

  @override
  Future<void> dispose() => _delegate.dispose();
}

