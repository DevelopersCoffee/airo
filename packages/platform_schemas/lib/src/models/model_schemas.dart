class GenerationRequest {

  const GenerationRequest({
    required this.prompt,
    this.parameters = const {},
  });
  final String prompt;
  final Map<String, dynamic> parameters;
}

class EmbeddingRequest {

  const EmbeddingRequest({
    required this.text,
  });
  final String text;
}

class VisionRequest {

  const VisionRequest({
    required this.imageUri,
    required this.prompt,
  });
  final String imageUri;
  final String prompt;
}

class AudioRequest {

  const AudioRequest({
    required this.audioUri,
  });
  final String audioUri;
}

class WorkflowRequest {

  const WorkflowRequest({
    required this.workflowId,
    required this.inputs,
  });
  final String workflowId;
  final Map<String, dynamic> inputs;
}
