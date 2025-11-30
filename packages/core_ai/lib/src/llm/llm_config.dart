import 'package:meta/meta.dart';

/// Configuration for an LLM client
@immutable
class LLMConfig {
  const LLMConfig({
    required this.provider,
    this.apiKey,
    this.modelName,
    this.temperature = 0.7,
    this.maxOutputTokens = 1024,
    this.topK = 40,
    this.topP = 0.95,
    this.stopSequences = const [],
    this.timeout = const Duration(seconds: 30),
  });

  /// Provider name (e.g., "gemini-nano", "gemini-api")
  final String provider;

  /// API key for cloud providers (null for on-device)
  final String? apiKey;

  /// Model name/identifier
  final String? modelName;

  /// Temperature for response randomness (0.0 - 1.0)
  final double temperature;

  /// Maximum tokens in the response
  final int maxOutputTokens;

  /// Top-K sampling parameter
  final int topK;

  /// Top-P (nucleus) sampling parameter
  final double topP;

  /// Sequences that stop generation
  final List<String> stopSequences;

  /// Request timeout
  final Duration timeout;

  /// Creates a copy with modified fields
  LLMConfig copyWith({
    String? provider,
    String? apiKey,
    String? modelName,
    double? temperature,
    int? maxOutputTokens,
    int? topK,
    double? topP,
    List<String>? stopSequences,
    Duration? timeout,
  }) =>
      LLMConfig(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
        modelName: modelName ?? this.modelName,
        temperature: temperature ?? this.temperature,
        maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
        topK: topK ?? this.topK,
        topP: topP ?? this.topP,
        stopSequences: stopSequences ?? this.stopSequences,
        timeout: timeout ?? this.timeout,
      );

  /// Default config for Gemini Nano (on-device)
  static const LLMConfig geminiNano = LLMConfig(
    provider: 'gemini-nano',
    maxOutputTokens: 1024,  // Nano has limited output
    temperature: 0.7,
  );

  /// Default config for Gemini API (cloud)
  static LLMConfig geminiApi({required String apiKey}) => LLMConfig(
        provider: 'gemini-api',
        apiKey: apiKey,
        modelName: 'gemini-1.5-flash',
        maxOutputTokens: 2048,
        temperature: 0.7,
      );
}

