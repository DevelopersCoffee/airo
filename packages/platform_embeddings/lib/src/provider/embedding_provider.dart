
import 'package:platform_identity/platform_identity.dart';
import '../models/embedding_models.dart';

abstract class EmbeddingProvider {
  EngineId get engineId;
  Future<EmbeddingBatch> generateEmbeddings(EmbeddingRequest request);
}
