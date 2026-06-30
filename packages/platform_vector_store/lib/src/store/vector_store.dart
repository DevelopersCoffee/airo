
import '../models/vector_models.dart';

abstract class VectorStore {
  Future<void> createIndex(VectorIndex index);
  Future<void> upsert(VectorIndex index, String id, List<double> vector, Map<String, dynamic> metadata);
  Future<List<VectorSearchResult>> search(VectorIndex index, VectorQuery query);
}
