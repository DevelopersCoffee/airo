import 'dart:convert';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Injectable primitive channel boundary for local embedding operations.
abstract interface class TextEmbeddingPlatformClient {
  Future<Map<String, Object?>> invoke(
    String method,
    Map<String, Object?> arguments,
  );
}

/// Production method-channel implementation of [TextEmbeddingPlatformClient].
final class MethodChannelTextEmbeddingPlatformClient
    implements TextEmbeddingPlatformClient {
  MethodChannelTextEmbeddingPlatformClient({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'dev.airo.platform_text_embeddings/methods';

  final MethodChannel _channel;

  @override
  Future<Map<String, Object?>> invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final response = await _channel.invokeMethod<Object?>(method, arguments);
    if (response is! Map) {
      throw const FormatException('Invalid platform response.');
    }
    return response.map((key, value) => MapEntry(key.toString(), value));
  }
}

/// Result of opening a platform text-embedding session.
sealed class TextEmbeddingProviderOpenResult {
  const TextEmbeddingProviderOpenResult();
}

/// A successfully initialized provider.
final class TextEmbeddingProviderReady extends TextEmbeddingProviderOpenResult {
  const TextEmbeddingProviderReady({required this.provider});

  final MediaPipeTextEmbeddingProvider provider;

  @override
  String toString() {
    return 'TextEmbeddingProviderReady('
        'modelId: ${provider.model.modelId}, '
        'dimensions: ${provider.model.dimensions})';
  }
}

/// A redacted initialization failure.
final class TextEmbeddingProviderOpenFailure
    extends TextEmbeddingProviderOpenResult {
  const TextEmbeddingProviderOpenFailure({required this.failure});

  final TextEmbeddingFailure failure;

  @override
  String toString() =>
      'TextEmbeddingProviderOpenFailure(${failure.code.stableId})';
}

/// An Android MediaPipe provider backed by an opaque native session.
final class MediaPipeTextEmbeddingProvider
    implements LocalTextEmbeddingProvider {
  MediaPipeTextEmbeddingProvider._({
    required this.model,
    required this._client,
    required this._sessionId,
  });

  static const maxInputBytes = 50 * 1024;
  static final _sessionIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  @override
  final TextEmbeddingModelDescriptor model;

  final TextEmbeddingPlatformClient _client;
  final String _sessionId;
  Future<void>? _closeFuture;
  bool _closed = false;

  /// Opens a verified caller-owned model without taking ownership of its file.
  static Future<TextEmbeddingProviderOpenResult> open({
    required String modelPath,
    required TextEmbeddingModelDescriptor model,
    TextEmbeddingPlatformClient? client,
    bool? isAndroid,
  }) async {
    final platformSupported =
        isAndroid ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (!platformSupported) {
      return const TextEmbeddingProviderOpenFailure(
        failure: TextEmbeddingFailure(
          code: TextEmbeddingFailureCode.platformUnavailable,
        ),
      );
    }
    if (modelPath.trim().isEmpty) {
      return const TextEmbeddingProviderOpenFailure(
        failure: TextEmbeddingFailure(
          code: TextEmbeddingFailureCode.invalidInput,
        ),
      );
    }

    final platformClient = client ?? MethodChannelTextEmbeddingPlatformClient();
    try {
      final response = await platformClient.invoke('initialize', {
        'modelPath': modelPath,
        'model': model.toJson(),
      });
      if (response['status'] == 'ready') {
        final sessionId = response['sessionId'];
        if (sessionId is String && _sessionIdPattern.hasMatch(sessionId)) {
          return TextEmbeddingProviderReady(
            provider: MediaPipeTextEmbeddingProvider._(
              model: model,
              client: platformClient,
              sessionId: sessionId,
            ),
          );
        }
      }
      return TextEmbeddingProviderOpenFailure(
        failure: TextEmbeddingFailure(
          code: _failureCode(
            response['code'],
            fallback: TextEmbeddingFailureCode.initializationFailed,
          ),
        ),
      );
    } catch (_) {
      return const TextEmbeddingProviderOpenFailure(
        failure: TextEmbeddingFailure(
          code: TextEmbeddingFailureCode.initializationFailed,
        ),
      );
    }
  }

  @override
  Future<TextEmbeddingOutcome> embed(String text) async {
    if (_closed) {
      return const TextEmbeddingFailure(
        code: TextEmbeddingFailureCode.providerClosed,
      );
    }
    if (text.trim().isEmpty || utf8.encode(text).length > maxInputBytes) {
      return const TextEmbeddingFailure(
        code: TextEmbeddingFailureCode.invalidInput,
      );
    }

    try {
      final response = await _client.invoke('embed', {
        'sessionId': _sessionId,
        'text': text,
      });
      if (response['status'] == 'success') {
        final rawValues = response['values'];
        if (rawValues is List && rawValues.every((value) => value is num)) {
          return TextEmbeddingSuccess(
            model: model,
            values: rawValues.cast<num>(),
          );
        }
      } else if (response['status'] == 'failure') {
        return TextEmbeddingFailure(
          code: _failureCode(
            response['code'],
            fallback: TextEmbeddingFailureCode.inferenceFailed,
          ),
        );
      }
    } catch (_) {
      // Convert every platform/runtime exception into a stable redacted code.
    }
    return const TextEmbeddingFailure(
      code: TextEmbeddingFailureCode.inferenceFailed,
    );
  }

  @override
  Future<void> close() {
    return _closeFuture ??= _close();
  }

  Future<void> _close() async {
    _closed = true;
    try {
      await _client.invoke('close', {'sessionId': _sessionId});
    } catch (_) {
      // Close is best-effort and idempotent; native detach is the final guard.
    }
  }

  static TextEmbeddingFailureCode _failureCode(
    Object? value, {
    required TextEmbeddingFailureCode fallback,
  }) {
    if (value is String) {
      for (final code in TextEmbeddingFailureCode.values) {
        if (code.stableId == value) {
          return code;
        }
      }
    }
    return fallback;
  }
}
