import 'dart:async';
import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:dio/dio.dart';

import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';

/// Normalizes a host-only OpenAI-compatible endpoint to its conventional v1
/// API root while preserving explicit paths such as `/v1` or `/api`.
String normalizeOpenAICompatibleBaseUrl(String value) {
  final trimmed = value.trim().replaceFirst(RegExp(r'/+$'), '');
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) return trimmed;
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  if (path.isEmpty || path == '/') {
    return uri.replace(path: '/v1').toString().replaceFirst(RegExp(r'/+$'), '');
  }
  return trimmed;
}

/// Result of probing an OpenAI-compatible local or private inference server.
enum RemoteServerHealth {
  ready,
  unauthorized,
  notFound,
  unavailable,
  invalidResponse,
  modelMissing,
}

/// Structured diagnostics for a remote runtime connection.
class RemoteServerDiagnostics {
  const RemoteServerDiagnostics({
    required this.health,
    required this.baseUrl,
    this.statusCode,
    this.modelIds = const [],
    this.message,
  });

  final RemoteServerHealth health;
  final String baseUrl;
  final int? statusCode;
  final List<String> modelIds;
  final String? message;

  bool get isReady => health == RemoteServerHealth.ready;
}

/// OpenAI-compatible client for local servers such as LM Studio, Ollama,
/// llama.cpp server, and compatible private gateways.
class OpenAICompatibleClient implements LLMClient {
  OpenAICompatibleClient({
    required String baseUrl,
    required String model,
    String? apiKey,
    Dio? dio,
    Duration timeout = const Duration(seconds: 45),
  }) : _baseUrl = normalizeOpenAICompatibleBaseUrl(baseUrl),
       _model = model,
       _apiKey = apiKey,
       _dio = dio ?? Dio(),
       _config = LLMConfig(
         provider: 'openai-compatible',
         apiKey: apiKey,
         modelName: model,
         timeout: timeout,
       );

  final String _baseUrl;
  final String _model;
  final String? _apiKey;
  final Dio _dio;
  final LLMConfig _config;

  @override
  LLMConfig get config => _config;

  @override
  int get maxContextLength => 32768;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey?.trim().isNotEmpty == true)
      'Authorization': 'Bearer ${_apiKey!.trim()}',
  };

  @override
  Future<bool> isAvailable() async {
    final diagnostics = await diagnose();
    return diagnostics.isReady;
  }

  /// Probes the server and returns actionable connection and model details.
  Future<RemoteServerDiagnostics> diagnose() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/models',
        options: _requestOptions(),
      );
      final statusCode = response.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return RemoteServerDiagnostics(
          health: RemoteServerHealth.unauthorized,
          baseUrl: _baseUrl,
          statusCode: statusCode,
          message: 'The server rejected the API key or credentials.',
        );
      }
      if (statusCode == 404) {
        return RemoteServerDiagnostics(
          health: RemoteServerHealth.notFound,
          baseUrl: _baseUrl,
          statusCode: statusCode,
          message:
              'The server is reachable, but its OpenAI-compatible /models endpoint was not found. Check the /v1 base path.',
        );
      }
      if (statusCode == null || statusCode >= 400) {
        return RemoteServerDiagnostics(
          health: RemoteServerHealth.unavailable,
          baseUrl: _baseUrl,
          statusCode: statusCode,
          message: 'The server returned HTTP ${statusCode ?? 'unknown'}.',
        );
      }
      final modelIds = _extractModelIds(response.data);
      final configuredModel = _model.trim();
      if (modelIds.isNotEmpty &&
          configuredModel.isNotEmpty &&
          !modelIds.contains(configuredModel)) {
        return RemoteServerDiagnostics(
          health: RemoteServerHealth.modelMissing,
          baseUrl: _baseUrl,
          statusCode: statusCode,
          modelIds: modelIds,
          message:
              'The server is reachable, but it did not report the configured model "$configuredModel".',
        );
      }
      return RemoteServerDiagnostics(
        health: modelIds.isEmpty
            ? RemoteServerHealth.invalidResponse
            : RemoteServerHealth.ready,
        baseUrl: _baseUrl,
        statusCode: statusCode,
        modelIds: modelIds,
        message: modelIds.isEmpty
            ? 'The server responded, but did not return any model ids.'
            : null,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final health = switch (statusCode) {
        401 || 403 => RemoteServerHealth.unauthorized,
        404 => RemoteServerHealth.notFound,
        _ => RemoteServerHealth.unavailable,
      };
      final message = switch (statusCode) {
        401 || 403 => 'The server rejected the API key or credentials.',
        404 =>
          'The server is reachable, but its OpenAI-compatible /models endpoint was not found. Check the /v1 base path.',
        _ => _remoteErrorMessage(error),
      };
      return RemoteServerDiagnostics(
        health: health,
        baseUrl: _baseUrl,
        statusCode: statusCode,
        message: message,
      );
    }
  }

  Future<Result<void>> initialize() async {
    if (_baseUrl.isEmpty || _model.trim().isEmpty) {
      return Failure(
        ValidationFailure(message: 'A server URL and model name are required.'),
      );
    }
    return const Success(null);
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/chat/completions',
        data: {
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': _config.temperature,
          'max_tokens': _config.maxOutputTokens,
          'top_p': _config.topP,
        },
        options: _requestOptions(),
      );
      final data = response.data;
      final text = _extractText(data);
      stopwatch.stop();
      return Success(
        LLMResponse(
          text: text,
          provider: 'openai-compatible',
          promptTokens: estimateTokens(prompt),
          completionTokens: estimateTokens(text),
          latencyMs: stopwatch.elapsedMilliseconds,
          finishReason:
              data?['choices'] is List && (data!['choices'] as List).isNotEmpty
              ? ((data['choices'] as List).first as Map)['finish_reason']
                    as String?
              : null,
        ),
      );
    } on DioException catch (error) {
      return Failure(
        ServerFailure(message: _remoteErrorMessage(error), cause: error),
      );
    } on Object catch (error) {
      return Failure(
        ServerFailure(
          message: 'Invalid remote model response: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '$_baseUrl/chat/completions',
        data: {
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': _config.temperature,
          'max_tokens': _config.maxOutputTokens,
          'stream': true,
        },
        options: _requestOptions(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) return;
      await for (final line
          in utf8.decoder.bind(body.stream).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final value = line.substring(5).trim();
        if (value == '[DONE]') break;
        try {
          final json = jsonDecode(value) as Map<String, dynamic>;
          final delta =
              ((json['choices'] as List?)?.firstOrNull as Map?)?['delta'];
          final content = delta is Map ? delta['content'] as String? : null;
          if (content != null && content.isNotEmpty) yield content;
        } on Object {
          // Ignore keep-alives and malformed provider-specific SSE frames.
        }
      }
    } on DioException catch (error) {
      yield '[Remote model error: ${_remoteErrorMessage(error)}]';
    }
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {}

  Options _requestOptions({ResponseType? responseType}) {
    return Options(
      headers: _headers,
      responseType: responseType,
      connectTimeout: _config.timeout,
      sendTimeout: _config.timeout,
      receiveTimeout: _config.timeout,
    );
  }

  String _extractText(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final message = (choices.first as Map)['message'];
    return message is Map ? message['content'] as String? ?? '' : '';
  }

  static List<String> _extractModelIds(Map<String, dynamic>? data) {
    final rawModels = data?['data'];
    if (rawModels is! List) return const [];
    return rawModels
        .whereType<Map>()
        .map((model) => model['id'])
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  static String _remoteErrorMessage(DioException error) {
    final status = error.response?.statusCode;
    final suffix = status == null ? '' : ' (HTTP $status)';
    return 'Remote model request failed$suffix: ${error.message ?? 'connection unavailable'}. '
        'Verify the server is reachable and its OpenAI-compatible /v1 endpoint is enabled.';
  }
}
