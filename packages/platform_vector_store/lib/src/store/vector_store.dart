
import 'package:platform_storage/platform_storage.dart';

import '../models/vector_models.dart';

abstract class AiroVectorStore implements VectorStore {
  Future<void> createIndex(VectorIndex index);
  Future<void> upsert(VectorIndex index, VectorDocument document, List<double> vector);
  Future<List<VectorSearchResult>> search(VectorIndex index, VectorQuery query);
}
