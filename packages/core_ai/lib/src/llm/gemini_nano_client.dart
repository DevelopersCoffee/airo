import 'dart:async';
import 'dart:developer' as developer;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';

import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_response.dart';
import '../device/memory_budget_manager.dart';
import '../utils/token_counter.dart';

// Re-export memory types for consumers
export '../device/memory_budget_manager.dart' show MemoryCheckResult, ModelType;
export '../device/memory_severity.dart' show MemorySeverity;

/// LLM client implementation for Gemini Nano (on-device).
///
/// Uses platform channel to communicate with native AI Core SDK.
/// Includes memory checks before loading to prevent OOM crashes.
class GeminiNanoClient implements LLMClient {
  GeminiNanoClient({
    LLMConfig? config,
    MemoryBudgetManager? memoryBudgetManager,
  }) : _config = config ?? LLMConfig.geminiNano,
       _memoryBudgetManager = memoryBudgetManager ?? MemoryBudgetManager();

  static const _channel = MethodChannel('com.airo.gemini_nano');
  static const _eventChannel = EventChannel('com.airo.gemini_nano/stream');

  /// Estimated Gemini Nano model size in bytes (~2.5GB).
  /// This is used for memory budget calculations.
  static const int estimatedModelSizeBytes = 2500 * 1024 * 1024;

  final LLMConfig _config;
  final MemoryBudgetManager _memoryBudgetManager;
  bool _isInitialized = false;
  MemoryCheckResult? _lastMemoryCheck;

  @override
  LLMConfig get config => _config;

  @override
  int get maxContextLength => TokenCounter.geminiNanoMaxContextTokens;

  /// Gets the last memory check result, if available.
  MemoryCheckResult? get lastMemoryCheck => _lastMemoryCheck;

  /// Performs a memory check for loading Gemini Nano.
  ///
  /// Returns a [MemoryCheckResult] with severity and recommendations.
  Future<MemoryCheckResult> checkMemoryForLoading({
    bool forceRefresh = false,
  }) async {
    _lastMemoryCheck = await _memoryBudgetManager.checkModelFile(
      fileSizeBytes: estimatedModelSizeBytes,
      type: ModelType.text,
      forceRefresh: forceRefresh,
    );
    return _lastMemoryCheck!;
  }

  /// Initializes the Gemini Nano model.
  ///
  /// Performs a memory check before initialization. If memory is insufficient
  /// (blocked severity), initialization will fail. If memory is low (warning
  /// or critical), initialization will proceed with a logged warning.
  Future<bool> initialize({bool skipMemoryCheck = false}) async {
    if (_isInitialized) return true;

    // Perform memory check before loading
    if (!skipMemoryCheck) {
      final memoryCheck = await checkMemoryForLoading();

      if (!memoryCheck.canLoad) {
        developer.log(
          'Gemini Nano initialization blocked: ${memoryCheck.severity.description}. '
          'Estimated usage: ${memoryCheck.estimatedUsageMB.toStringAsFixed(0)}MB, '
          'Available: ${memoryCheck.memoryInfo.availableMB.toStringAsFixed(0)}MB',
          name: 'GeminiNanoClient',
          level: 1000, // Warning level
        );
        return false;
      }

      if (memoryCheck.shouldWarn) {
        developer.log(
          'Warning: ${memoryCheck.severity.title}. '
          '${memoryCheck.severity.description}. '
          'Estimated usage: ${memoryCheck.estimatedUsageMB.toStringAsFixed(0)}MB, '
          'Budget: ${memoryCheck.budgetMB.toStringAsFixed(0)}MB',
          name: 'GeminiNanoClient',
          level: 900, // Info level
        );
      }
    }

    try {
      final result = await _channel.invokeMethod<bool>('initialize', {
        'temperature': _config.temperature,
        'topK': _config.topK,
        'maxOutputTokens': _config.maxOutputTokens,
      });
      _isInitialized = result ?? false;
      return _isInitialized;
    } catch (e) {
      developer.log(
        'Gemini Nano initialization failed: $e',
        name: 'GeminiNanoClient',
        error: e,
      );
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
      final result = await _channel.invokeMethod<String>('generateContent', {
        'prompt': prompt,
      });
      stopwatch.stop();

      if (result == null) {
        return const Failure(
          ServerFailure(message: 'Empty response from Gemini Nano'),
        );
      }

      return Success(
        LLMResponse(
          text: result,
          provider: 'gemini-nano',
          promptTokens: estimateTokens(prompt),
          completionTokens: estimateTokens(result),
          latencyMs: stopwatch.elapsedMilliseconds,
          finishReason: 'stop',
        ),
      );
    } on PlatformException catch (e) {
      return Failure(
        ServerFailure(message: 'Gemini Nano error: ${e.message}', cause: e),
      );
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
      // Start streaming generation (method name matches Android plugin)
      await _channel.invokeMethod('generateContentStream', {'prompt': prompt});

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
  ///
  /// [config] - Optional LLM configuration.
  /// [checkMemory] - If true (default), checks memory availability.
  /// [onMemoryWarning] - Optional callback for memory warnings.
  ///
  /// Returns null if the device doesn't support Gemini Nano or
  /// if memory is insufficient (when checkMemory is true).
  static Future<GeminiNanoClient?> createIfAvailable({
    LLMConfig? config,
    bool checkMemory = true,
    void Function(MemoryCheckResult)? onMemoryWarning,
  }) async {
    final client = GeminiNanoClient(config: config);

    if (!await client.isAvailable()) {
      return null;
    }

    // Perform memory check if requested
    if (checkMemory) {
      final memoryCheck = await client.checkMemoryForLoading();

      if (!memoryCheck.canLoad) {
        return null; // Memory insufficient
      }

      if (memoryCheck.shouldWarn && onMemoryWarning != null) {
        onMemoryWarning(memoryCheck);
      }
    }

    return client;
  }
}
