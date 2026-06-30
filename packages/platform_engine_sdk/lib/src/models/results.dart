class GenerationChunk {

  const GenerationChunk({
    required this.text,
    this.isFinished = false,
  });
  final String text;
  final bool isFinished;
}

class EmbeddingResult {

  const EmbeddingResult({required this.embeddings});
  final List<List<double>> embeddings;
}

class VisionResult {

  const VisionResult({required this.description});
  final String description;
}

class AudioResult {

  const AudioResult({required this.transcription});
  final String transcription;
}

class TokenizationResult {

  const TokenizationResult({required this.tokens});
  final List<int> tokens;
}
