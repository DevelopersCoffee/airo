library engine_litert;

import 'package:platform_execution/platform_execution.dart';
import 'package:platform_backend/platform_backend.dart';
import 'package:platform_embeddings/platform_embeddings.dart';
import 'package:platform_identity/platform_identity.dart';

class LiteRtInferenceProvider implements EmbeddingProvider {
  @override
  String get name => 'litert';

  @override
  EngineId get engineId => const EngineId('litert_engine_1');

  @override
  Future<EmbeddingBatch> generateEmbeddings(EmbeddingRequest request) async {
    return EmbeddingBatch([]);
  }
}
