import 'dart:async';
import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:dio/dio.dart';

import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';

/// OpenAI-compatible client for local servers such as LM Studio, Ollama,
/// llama.cpp server, and compatible private gateways.
class OpenAICompatibleClient implements LLMClient {
  OpenAICompatibleClient({
    required String baseUrl,
    required String model,
    String? apiKey,
    Dio? dio,
    Duration timeout = const Duration(seconds: 45),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
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
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/models',
        options: Options(headers: _headers, receiveTimeout: _config.timeout),
      );
      return response.statusCode != null && response.statusCode! < 400;
    } on DioException {
      return false;
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
        options: Options(headers: _headers, receiveTimeout: _config.timeout),
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
        ServerFailure(
          message: 'Remote model request failed: ${error.message}',
          cause: error,
        ),
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
        options: Options(
          headers: _headers,
          responseType: ResponseType.stream,
          receiveTimeout: _config.timeout,
        ),
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
      yield '[Remote model error: ${error.message}]';
    }
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {}

  String _extractText(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final message = (choices.first as Map)['message'];
    return message is Map ? message['content'] as String? ?? '' : '';
  }
}
