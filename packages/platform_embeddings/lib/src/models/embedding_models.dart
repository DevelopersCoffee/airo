
class EmbeddingRequest {
  final String text;
  EmbeddingRequest(this.text);
}

class EmbeddingResult {
  final List<double> vector;
  EmbeddingResult(this.vector);
}

class EmbeddingBatch {
  final List<EmbeddingResult> results;
  EmbeddingBatch(this.results);
}
