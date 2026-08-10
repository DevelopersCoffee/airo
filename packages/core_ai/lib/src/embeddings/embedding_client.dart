import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads an on-device text embedding model and turns text into vectors.
///
/// Backed by a **separate** native plugin from `LiteRtLmClient`'s
/// (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`):
/// EmbeddingGemma is not published as a `.litertlm` package, so it cannot go
/// through `LiteRtLmPlugin.kt`'s `Engine`/`Conversation` API. This wraps
/// Google's AI Edge RAG SDK (`GeckoEmbeddingModel`) instead, over its own
/// method channel.
abstract class EmbeddingClient {
  /// Loads the model. [modelPath] and [tokenizerPath] are supplied by the
  /// caller (the already-downloaded files' locations) — this client never
  /// acquires a model itself, the same boundary `ModelProvider` draws for
  /// every other model in this app.
  Future<void> initialize({
    required String modelPath,
    required String tokenizerPath,
    bool useGpu = false,
  });

  /// True once [initialize] has succeeded and the model is ready to embed.
  Future<bool> isReady();

  /// Turns [text] into its embedding vector. Throws if [initialize] has not
  /// succeeded — callers that want a non-throwing "is this available" check
  /// should call [isReady] first (mirrors `EmbeddingService`'s contract,
  /// which is where that check actually lives for real callers).
  Future<List<double>> embed({required String text});
}

/// Channel name is distinct from `com.airo.litert_lm`: a different plugin,
/// a different SDK, a different failure mode (this one can be entirely
/// absent from a build without affecting chat at all).
class MethodChannelEmbeddingClient implements EmbeddingClient {
  MethodChannelEmbeddingClient({
    this.operationTimeout = const Duration(seconds: 30),
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.airo.embedding');

  final Duration operationTimeout;
  final MethodChannel _channel;

  @override
  Future<void> initialize({
    required String modelPath,
    required String tokenizerPath,
    bool useGpu = false,
  }) async {
    await _channel
        .invokeMethod<void>('initialize', {
          'modelPath': modelPath,
          'tokenizerPath': tokenizerPath,
          'useGpu': useGpu,
        })
        .timeout(operationTimeout);
  }

  @override
  Future<bool> isReady() async {
    try {
      final ready = await _channel
          .invokeMethod<bool>('isReady')
          .timeout(operationTimeout);
      return ready ?? false;
    } on PlatformException catch (e) {
      debugPrint('Embedding isReady check failed: ${e.message}');
      return false;
    } on MissingPluginException {
      // No plugin registered for this build (the stub flavor, or a flavor
      // that never wires the channel at all) -- not ready, not an error.
      return false;
    } on TimeoutException {
      debugPrint('Embedding isReady check timed out.');
      return false;
    }
  }

  @override
  Future<List<double>> embed({required String text}) async {
    final result = await _channel
        .invokeMethod<List<Object?>>('embed', {'text': text})
        .timeout(operationTimeout);
    if (result == null) {
      throw StateError('Embedding plugin returned no vector for "$text"');
    }
    return result.cast<num>().map((v) => v.toDouble()).toList();
  }
}
