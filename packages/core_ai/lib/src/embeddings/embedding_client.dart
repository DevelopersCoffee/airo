import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/offline_model_info.dart';

/// How the native embedder should treat [EmbeddingClient.embed]'s text.
///
/// Maps to Google's AI Edge RAG SDK `EmbedData.TaskType`. Query vs document
/// asymmetry improves retrieval quality over always using semantic
/// similarity — the plugin originally always used `SEMANTIC_SIMILARITY`
/// and flagged this as a follow-up for `SemanticSearchRanker`.
enum EmbeddingTaskType {
  /// Short search query text.
  retrievalQuery('retrievalQuery'),

  /// Meeting chunk / document text being indexed.
  retrievalDocument('retrievalDocument'),

  /// Symmetric similarity (legacy default).
  semanticSimilarity('semanticSimilarity');

  const EmbeddingTaskType(this.wireName);

  /// Value sent across the method channel / understood by Kotlin.
  final String wireName;
}

/// A `.litertlm` embedding package, such as EmbeddingGemma 2.
bool isLiteRtEmbeddingPackage(OfflineModelInfo? model, {String? modelPath}) {
  final source =
      '${model?.id ?? ''} ${model?.filePath ?? ''} ${model?.downloadUrl ?? ''} ${modelPath ?? ''}'
          .toLowerCase();
  return source.contains('.litertlm') || source.contains('litertlm');
}

/// EmbeddingGemma 2 expects these prefixes. The older TFLite embedder uses
/// Gecko task types instead, so only the LiteRT path applies this.
String liteRtEmbeddingPrompt(String text, EmbeddingTaskType taskType) {
  final body = text.trim();
  final prefix = switch (taskType) {
    EmbeddingTaskType.retrievalQuery => 'task: search query | text: ',
    EmbeddingTaskType.retrievalDocument => 'task: search result | text: ',
    EmbeddingTaskType.semanticSimilarity =>
      'task: sentence similarity | text: ',
  };
  return '$prefix$body';
}

/// Loads an on-device text embedding model and turns text into vectors.
///
/// EmbeddingGemma 2 is a `.litertlm` package and goes through LiteRT-LM's
/// `EmbeddingEngine`. The older EmbeddingGemma 300M `.tflite` file still
/// goes through the AI Edge RAG SDK on `com.airo.embedding`.
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
  Future<List<double>> embed({
    required String text,
    EmbeddingTaskType taskType = EmbeddingTaskType.semanticSimilarity,
  });

  /// Embeds a local image or audio file with EmbeddingGemma 2.
  ///
  /// Exactly one of [imagePath] and [audioPath] is set. The text-only 300M
  /// embedder does not implement this.
  Future<List<double>> embedMedia({String? imagePath, String? audioPath}) {
    throw UnsupportedError(
      'This embedder only accepts text. Image and audio need EmbeddingGemma 2.',
    );
  }
}

/// Channel name is distinct from `com.airo.litert_lm`: a different plugin,
/// a different SDK, a different failure mode (this one can be entirely
/// absent from a build without affecting chat at all).
class MethodChannelEmbeddingClient implements EmbeddingClient {
  MethodChannelEmbeddingClient({
    this.operationTimeout = const Duration(seconds: 30),
    MethodChannel? channel,
    MethodChannel? liteRtChannel,
  }) : _channel = channel ?? const MethodChannel('com.airo.embedding'),
       _liteRtChannel =
           liteRtChannel ?? const MethodChannel('com.airo.litert_lm');

  final Duration operationTimeout;
  final MethodChannel _channel;
  final MethodChannel _liteRtChannel;
  bool _liteRt = false;

  @override
  Future<void> initialize({
    required String modelPath,
    required String tokenizerPath,
    bool useGpu = false,
  }) async {
    _liteRt = isLiteRtEmbeddingPackage(null, modelPath: modelPath);
    final channel = _liteRt ? _liteRtChannel : _channel;
    await channel
        .invokeMethod<void>(_liteRt ? 'embedInitialize' : 'initialize', {
          'modelPath': modelPath,
          if (!_liteRt) 'tokenizerPath': tokenizerPath,
          'useGpu': useGpu,
        })
        .timeout(operationTimeout);
  }

  @override
  Future<bool> isReady() async {
    try {
      final ready = await (_liteRt ? _liteRtChannel : _channel)
          .invokeMethod<bool>(_liteRt ? 'embedReady' : 'isReady')
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
  Future<List<double>> embed({
    required String text,
    EmbeddingTaskType taskType = EmbeddingTaskType.semanticSimilarity,
  }) async {
    final channel = _liteRt ? _liteRtChannel : _channel;
    final result = await channel
        .invokeMethod<List<Object?>>(_liteRt ? 'embedText' : 'embed', {
          'text': _liteRt ? liteRtEmbeddingPrompt(text, taskType) : text,
          'taskType': taskType.wireName,
        })
        .timeout(operationTimeout);
    if (result == null) {
      throw StateError('Embedding plugin returned no vector for "$text"');
    }
    return result.cast<num>().map((v) => v.toDouble()).toList();
  }

  @override
  Future<List<double>> embedMedia({
    String? imagePath,
    String? audioPath,
  }) async {
    if (!_liteRt) {
      throw UnsupportedError(
        'Image and audio embeddings need an EmbeddingGemma 2 package.',
      );
    }
    final result = await _liteRtChannel
        .invokeMethod<List<Object?>>('embedMedia', {
          'imagePath': ?imagePath,
          'audioPath': ?audioPath,
        })
        .timeout(operationTimeout);
    if (result == null) {
      throw StateError('Embedding plugin returned no vector for the media.');
    }
    return result.cast<num>().map((v) => v.toDouble()).toList();
  }
}
