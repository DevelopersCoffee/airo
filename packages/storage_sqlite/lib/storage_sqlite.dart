library storage_sqlite;

import 'package:platform_vector_store/platform_vector_store.dart';

class SqliteVectorStore implements AiroVectorStore {
  @override
  String get name => 'sqlite_vector';

  @override
  Future<void> createIndex(VectorIndex index) async {}

  @override
  Future<List<VectorSearchResult>> search(VectorIndex index, VectorQuery query) async { return []; }

  @override
  Future<void> upsert(VectorIndex index, VectorDocument document, List<double> vector) async {}
}
