
import 'package:platform_execution/platform_execution.dart';

class Schema {}

abstract class PipelineStage<I, O> {
  String get name;
  Schema get inputSchema;
  Schema get outputSchema;
  
  int get estimatedMemoryBytes;
  int get estimatedComputeComplexity;
  
  bool get supportsStreaming;
  bool get supportsBatching;
  bool get supportsCancellation;
  bool get supportsCheckpointing;

  Future<O> execute(I input, PipelineContext context);
}

class PipelineDag {
  final String name;
  final List<PipelineStage> stages;
  PipelineDag({required this.name, required this.stages});
}

class PipelineContext {
  final String runId;
  PipelineContext({required this.runId});
}
