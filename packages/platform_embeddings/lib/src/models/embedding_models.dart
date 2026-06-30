
abstract class EmbeddingInput {
  const EmbeddingInput();
}

class TextEmbeddingInput extends EmbeddingInput {
  final String text;
  const TextEmbeddingInput(this.text);
}

class EmbeddingRequest {
  final List<EmbeddingInput> inputs;
  const EmbeddingRequest(this.inputs);
}

class EmbeddingResult {
  final List<double> vector;
  const EmbeddingResult(this.vector);
}

class EmbeddingBatch {
  final List<EmbeddingResult> results;
  const EmbeddingBatch(this.results);
}
