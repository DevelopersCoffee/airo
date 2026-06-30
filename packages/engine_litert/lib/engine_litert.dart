library engine_litert;

import 'package:platform_runtime/platform_runtime.dart';
import 'package:platform_embeddings/platform_embeddings.dart';
import 'package:platform_identity/platform_identity.dart';

class LiteRtInferenceProvider implements InferenceProvider, EmbeddingProvider {
  @override
  String get name => 'litert';

  @override
  EngineId get engineId => const EngineId('litert_engine_1');

  @override
  Future<EmbeddingBatch> generateEmbeddings(EmbeddingRequest request) async {
    return EmbeddingBatch([]);
  }
}
