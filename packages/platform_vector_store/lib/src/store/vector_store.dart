
import '../models/vector_models.dart';

abstract class VectorStore {
  Future<void> createIndex(VectorIndex index);
  Future<void> upsert(VectorIndex index, VectorDocument document, List<double> vector);
  Future<List<VectorSearchResult>> search(VectorIndex index, VectorQuery query);
}
