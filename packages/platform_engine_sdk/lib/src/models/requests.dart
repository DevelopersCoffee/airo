class GenerationRequest {

  const GenerationRequest({
    required this.prompt,
    this.temperature = 0.7,
    this.maxTokens = 1024,
  });
  final String prompt;
  final double temperature;
  final int maxTokens;
}

class EmbeddingRequest {

  const EmbeddingRequest({required this.texts});
  final List<String> texts;
}

class VisionRequest {

  const VisionRequest({required this.imagePath, this.prompt});
  final String imagePath;
  final String? prompt;
}

class AudioRequest {

  const AudioRequest({required this.audioPath});
  final String audioPath;
}

class TokenizationRequest {

  const TokenizationRequest({required this.text});
  final String text;
}
