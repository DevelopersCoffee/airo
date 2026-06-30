enum ModelModality {
  textToText,
  textToImage,
  imageToText,
  audioToText,
  textToAudio,
  embedding,
}

class ModelCapabilities {

  const ModelCapabilities({
    this.supportsVision = false,
    this.supportsFunctionCalling = false,
    this.supportsStreaming = false,
    this.supportsEmbeddings = false,
  });
  final bool supportsVision;
  final bool supportsFunctionCalling;
  final bool supportsStreaming;
  final bool supportsEmbeddings;
}
