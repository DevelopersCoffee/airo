
import 'package:platform_execution/platform_execution.dart';
import 'artifacts.dart';

class SchemaDescriptor {
  final String id;
  final String version;
  final String mimeType;
  final dynamic serializer;
  final dynamic validator;

  SchemaDescriptor({
    required this.id,
    required this.version,
    required this.mimeType,
    this.serializer,
    this.validator,
  });
}

class PipelineStageDescriptor {
  final SchemaDescriptor inputSchema;
  final SchemaDescriptor outputSchema;
  
  final List<String> requiredCapabilities;
  
  final int minimumMemoryBytes;
  final int preferredMemoryBytes;
  final int maximumMemoryBytes;
  
  final int minimumThreads;
  final int preferredThreads;
  
  final List<String> preferredAccelerators;
  
  final Duration? expectedLatency;
  final int? expectedThroughput;
  
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
    this.minimumMemoryBytes = 0,
    this.preferredMemoryBytes = 0,
    this.maximumMemoryBytes = 0,
    this.minimumThreads = 1,
    this.preferredThreads = 1,
    this.preferredAccelerators = const [],
    this.expectedLatency,
    this.expectedThroughput,
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
