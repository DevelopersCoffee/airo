
abstract class EmbeddingInput {
  const EmbeddingInput();
}

class TextEmbeddingInput extends EmbeddingInput {
  const TextEmbeddingInput(this.text);
  final String text;
}

class EmbeddingRequest {
  const EmbeddingRequest(this.inputs);
  final List<EmbeddingInput> inputs;
}

class EmbeddingResult {
  const EmbeddingResult(this.vector);
  final List<double> vector;
}

class EmbeddingBatch {
  const EmbeddingBatch(this.results);
  final List<EmbeddingResult> results;
}
