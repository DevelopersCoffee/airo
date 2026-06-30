class GenerationRequest {
  final String prompt;
  final Map<String, dynamic> parameters;

  const GenerationRequest({
    required this.prompt,
    this.parameters = const {},
  });
}

class EmbeddingRequest {
  final String text;

  const EmbeddingRequest({
    required this.text,
  });
}

class VisionRequest {
  final String imageUri;
  final String prompt;

  const VisionRequest({
    required this.imageUri,
    required this.prompt,
  });
}

class AudioRequest {
  final String audioUri;

  const AudioRequest({
    required this.audioUri,
  });
}

class WorkflowRequest {
  final String workflowId;
  final Map<String, dynamic> inputs;

  const WorkflowRequest({
    required this.workflowId,
    required this.inputs,
  });
}
