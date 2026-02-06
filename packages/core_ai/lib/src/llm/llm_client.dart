import 'package:core_domain/core_domain.dart';

import 'llm_config.dart';
import 'llm_response.dart';

/// Abstract interface for LLM (Large Language Model) clients.
///
/// Implementations can wrap different LLM providers like
/// Gemini Nano (on-device) or Gemini API (cloud).
abstract class LLMClient {
  /// Configuration for this client
  LLMConfig get config;

  /// Generates a text response for the given prompt.
  Future<Result<LLMResponse>> generate(String prompt);

  /// Generates a streaming text response.
  Stream<String> generateStream(String prompt);

  /// Checks if the LLM is available (initialized and ready).
  Future<bool> isAvailable();

  /// Estimates token count for the given text.
  int estimateTokens(String text);

  /// Maximum context length in tokens
  int get maxContextLength;

  /// Disposes of resources used by this client.
  Future<void> dispose();
}

/// Provider type for LLM routing decisions
enum LLMProvider {
  /// On-device Gemini Nano
  geminiNano,

  /// Cloud-based Gemini API
  geminiApi,

  /// GGUF model via llama.cpp
  gguf,

  /// Fallback/mock for testing
  mock,
}

/// Router for selecting appropriate LLM based on request characteristics
abstract class LLMRouter {
  /// Routes to the best available LLM client based on the request
  Future<LLMClient> route({
    required String prompt,
    bool preferOnDevice = true,
    bool requiresVision = false,
  });

  /// Gets a specific provider
  LLMClient? getProvider(LLMProvider provider);
}
