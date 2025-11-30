import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';

import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../utils/token_counter.dart';

/// LLM client implementation for Gemini Nano (on-device).
///
/// Uses platform channel to communicate with native AI Core SDK.
class GeminiNanoClient implements LLMClient {
  GeminiNanoClient({LLMConfig? config})
      : _config = config ?? LLMConfig.geminiNano;

  static const _channel = MethodChannel('com.airo.superapp/gemini_nano');
  static const _eventChannel =
      EventChannel('com.airo.superapp/gemini_nano_stream');

  final LLMConfig _config;
  bool _isInitialized = false;

  @override
  LLMConfig get config => _config;

  @override
  int get maxContextLength => TokenCounter.geminiNanoMaxContextTokens;

  /// Initializes the Gemini Nano model.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final result = await _channel.invokeMethod<bool>('initialize', {
        'temperature': _config.temperature,
        'topK': _config.topK,
        'maxOutputTokens': _config.maxOutputTokens,
      });
      _isInitialized = result ?? false;
      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return const Failure(
          ServerFailure(message: 'Gemini Nano not available on this device'),
        );
      }
    }

    try {
      final stopwatch = Stopwatch()..start();
      final result = await _channel.invokeMethod<String>(
        'generateContent',
        {'prompt': prompt},
      );
      stopwatch.stop();

      if (result == null) {
        return const Failure(
          ServerFailure(message: 'Empty response from Gemini Nano'),
        );
      }

      return Success(LLMResponse(
        text: result,
        provider: 'gemini-nano',
        promptTokens: estimateTokens(prompt),
        completionTokens: estimateTokens(result),
        latencyMs: stopwatch.elapsedMilliseconds,
        finishReason: 'stop',
      ));
    } on PlatformException catch (e) {
      return Failure(ServerFailure(
        message: 'Gemini Nano error: ${e.message}',
        cause: e,
      ));
    }
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        yield '[Error: Gemini Nano not available]';
        return;
      }
    }

    try {
      // Start streaming generation
      await _channel.invokeMethod('startStreamGeneration', {'prompt': prompt});

      // Listen to stream
      await for (final chunk in _eventChannel.receiveBroadcastStream()) {
        if (chunk is String) {
          yield chunk;
        }
      }
    } on PlatformException catch (e) {
      yield '[Error: ${e.message}]';
    }
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _isInitialized = false;
    } catch (e) {
      // Ignore disposal errors
    }
  }
}

/// Factory for creating Gemini Nano client with device checks.
class GeminiNanoClientFactory {
  /// Creates a client if the device supports Gemini Nano.
  static Future<GeminiNanoClient?> createIfAvailable({
    LLMConfig? config,
  }) async {
    final client = GeminiNanoClient(config: config);
    if (await client.isAvailable()) {
      return client;
    }
    return null;
  }
}

