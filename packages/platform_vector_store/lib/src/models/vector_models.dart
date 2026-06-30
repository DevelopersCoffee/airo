
class VectorIndex {
  final String name;
  final int dimensions;
  VectorIndex(this.name, this.dimensions);
}

class VectorQuery {
  final List<double> vector;
  final int topK;
  VectorQuery(this.vector, this.topK);
}

class VectorSearchResult {
  final String id;
  final double score;
  final Map<String, dynamic> metadata;
  VectorSearchResult(this.id, this.score, this.metadata);
}
