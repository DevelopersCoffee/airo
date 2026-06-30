
import 'package:platform_execution/platform_execution.dart';
import 'artifacts.dart';

class Schema {}

class PipelineStageDescriptor {
  final Schema inputSchema;
  final Schema outputSchema;
  
  final List<String> requiredCapabilities;
  
  final int estimatedMemoryBytes;
  final int estimatedCpuCompute;
  final int estimatedGpuCompute;
  
  final bool supportsStreaming;
  final bool supportsBatching;
  final bool supportsCheckpointing;
  final bool supportsResume;
  
  final List<Type> producesArtifacts;
  final List<Type> consumesArtifacts;

  final bool cacheable;
  final String? cacheKey;
  final String? artifactVersion;
  final bool deterministic;

  PipelineStageDescriptor({
    required this.inputSchema,
    required this.outputSchema,
    this.requiredCapabilities = const [],
    this.estimatedMemoryBytes = 0,
    this.estimatedCpuCompute = 0,
    this.estimatedGpuCompute = 0,
    this.supportsStreaming = false,
    this.supportsBatching = false,
    this.supportsCheckpointing = false,
    this.supportsResume = false,
    this.producesArtifacts = const [],
    this.consumesArtifacts = const [],
    this.cacheable = false,
    this.cacheKey,
    this.artifactVersion,
    this.deterministic = true,
  });
}

abstract class PipelineStage<I, O> {
  String get name;
  PipelineStageDescriptor get descriptor;
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
