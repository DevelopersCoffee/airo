
class VectorDocument {
  // Raw vector is internal to the store implementation, typically not exposed
  
  VectorDocument({required this.id, required this.metadata});
  final String id;
  final Map<String, dynamic> metadata;
}

class VectorIndex {
  VectorIndex(this.name, this.dimensions);
  final String name;
  final int dimensions;
}

class VectorQuery {
  VectorQuery(this.vector, this.topK);
  final List<double> vector;
  final int topK;
}

class VectorSearchResult {
  VectorSearchResult(this.id, this.score, this.metadata);
  final String id;
  final double score;
  final Map<String, dynamic> metadata;
}
