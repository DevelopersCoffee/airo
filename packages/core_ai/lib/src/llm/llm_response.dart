import 'package:meta/meta.dart';

/// Response from an LLM generation request
@immutable
class LLMResponse {
  const LLMResponse({
    required this.text,
    required this.provider,
    this.promptTokens,
    this.completionTokens,
    this.latencyMs,
    this.finishReason,
    this.metadata,
  });

  /// Generated text content
  final String text;

  /// Which provider generated this response
  final String provider;

  /// Number of tokens in the prompt
  final int? promptTokens;

  /// Number of tokens in the completion
  final int? completionTokens;

  /// Time taken to generate in milliseconds
  final int? latencyMs;

  /// Reason generation finished (e.g., "stop", "max_tokens")
  final String? finishReason;

  /// Additional metadata from the provider
  final Map<String, dynamic>? metadata;

  /// Total tokens used (prompt + completion)
  int? get totalTokens => promptTokens != null && completionTokens != null
      ? promptTokens! + completionTokens!
      : null;

  @override
  String toString() =>
      'LLMResponse(provider: $provider, tokens: $totalTokens, latency: ${latencyMs}ms)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMResponse &&
          other.text == text &&
          other.provider == provider &&
          other.promptTokens == promptTokens &&
          other.completionTokens == completionTokens;

  @override
  int get hashCode => Object.hash(text, provider, promptTokens, completionTokens);
}

