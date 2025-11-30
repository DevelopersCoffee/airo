import 'dart:async';
import 'dart:convert';

import 'package:core_domain/core_domain.dart';

import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';

/// LLM client implementation for Gemini API (cloud).
///
/// Uses HTTP to communicate with Google's Gemini API.
class GeminiApiClient implements LLMClient {
  GeminiApiClient({
    required String apiKey,
    LLMConfig? config,
    HttpClientFactory? httpClientFactory,
  })  : _apiKey = apiKey,
        _config = config ?? LLMConfig.geminiApi(apiKey: apiKey),
        _httpClientFactory = httpClientFactory ?? _defaultHttpFactory;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  final String _apiKey;
  final LLMConfig _config;
  final HttpClientFactory _httpClientFactory;

  @override
  LLMConfig get config => _config;

  @override
  int get maxContextLength => TokenCounter.geminiApiMaxContextTokens;

  @override
  Future<bool> isAvailable() async => _apiKey.isNotEmpty;

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    if (_apiKey.isEmpty) {
      return const Failure(
        AuthFailure(message: 'Gemini API key not configured'),
      );
    }

    try {
      final stopwatch = Stopwatch()..start();

      final response = await _makeRequest(
        'models/${_config.modelName ?? 'gemini-1.5-flash'}:generateContent',
        {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': _config.temperature,
            'topK': _config.topK,
            'topP': _config.topP,
            'maxOutputTokens': _config.maxOutputTokens,
            if (_config.stopSequences.isNotEmpty)
              'stopSequences': _config.stopSequences,
          },
        },
      );

      stopwatch.stop();

      if (response.isFailure) {
        return Failure(response.failure);
      }

      final data = response.value;
      final text = _extractText(data);
      final usage = data['usageMetadata'] as Map<String, dynamic>?;

      return Success(LLMResponse(
        text: text,
        provider: 'gemini-api',
        promptTokens: usage?['promptTokenCount'] as int?,
        completionTokens: usage?['candidatesTokenCount'] as int?,
        latencyMs: stopwatch.elapsedMilliseconds,
        finishReason: _extractFinishReason(data),
        metadata: data,
      ));
    } catch (e) {
      return Failure(UnexpectedFailure(message: e.toString(), cause: e));
    }
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (_apiKey.isEmpty) {
      yield '[Error: API key not configured]';
      return;
    }

    try {
      // For streaming, we need to use SSE endpoint
      // This is a simplified implementation - real streaming would use
      // streamGenerateContent endpoint with SSE parsing
      final result = await generate(prompt);
      if (result.isSuccess) {
        yield result.value.text;
      } else {
        yield '[Error: ${result.failure.message}]';
      }
    } catch (e) {
      yield '[Error: $e]';
    }
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {
    // No resources to dispose for HTTP client
  }

  Future<Result<Map<String, dynamic>>> _makeRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final client = _httpClientFactory();
      final uri = Uri.parse('$_baseUrl/$endpoint?key=$_apiKey');

      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return Success(jsonDecode(response.body) as Map<String, dynamic>);
      }

      return Failure(ServerFailure(
        message: 'API error: ${response.statusCode}',
        statusCode: response.statusCode,
      ));
    } catch (e) {
      return Failure(NetworkFailure(message: e.toString()));
    }
  }

  String _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    return parts[0]['text'] as String? ?? '';
  }

  String? _extractFinishReason(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    return candidates[0]['finishReason'] as String?;
  }
}

/// Factory function for creating HTTP clients.
/// Allows injection of mock clients for testing.
typedef HttpClientFactory = HttpClient Function();

HttpClient _defaultHttpFactory() => HttpClient();

/// Minimal HTTP client interface for dependency injection.
abstract class HttpClient {
  Future<HttpResponse> post(
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  });
}

/// HTTP response wrapper.
class HttpResponse {
  const HttpResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}

