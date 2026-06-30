
import '../models/embedding_models.dart';

abstract class EmbeddingCache {
  Future<EmbeddingResult?> get(String hash);
  Future<void> put(String hash, EmbeddingResult result);
}
