
import 'package:platform_identity/platform_identity.dart';

class SchemaDescriptor {

  SchemaDescriptor({
    required this.id,
    required this.version,
    required this.mimeType,
    this.serializer,
    this.validator,
  });
  final String id;
  final String version;
  final String mimeType;
  final dynamic serializer;
  final dynamic validator;
}

class StageDescriptor {
  
  StageDescriptor({
    required this.id,
    required this.version,
    required this.inputSchema,
    required this.outputSchema,
    this.requiredCapabilities = const [],
    this.cacheable = false,
    this.cachePolicy,
  });
  final StageId id;
  final String version;
  final SchemaDescriptor inputSchema;
  final SchemaDescriptor outputSchema;
  final List<String> requiredCapabilities;
  
  final bool cacheable;
  final String? cachePolicy;
}

class ExecutionProfile {

  ExecutionProfile({
    this.minimumMemoryBytes = 0,
    this.preferredMemoryBytes = 0,
    this.maximumMemoryBytes = 0,
    this.minimumThreads = 1,
    this.preferredThreads = 1,
    this.preferredAccelerators = const [],
    this.expectedLatency,
    this.expectedThroughput,
  });
  final int minimumMemoryBytes;
  final int preferredMemoryBytes;
  final int maximumMemoryBytes;
  
  final int minimumThreads;
  final int preferredThreads;
  
  final List<String> preferredAccelerators;
  
  final Duration? expectedLatency;
  final int? expectedThroughput;
}

class TelemetryEvent {
  TelemetryEvent(this.type, this.data) : timestamp = DateTime.now();
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

abstract class PipelineStage<I, O> {
  StageDescriptor get descriptor;
  ExecutionProfile get executionProfile;
  Future<O> execute(I input, PipelineContext context);
}

class PipelineDag {
  PipelineDag({required this.id, required this.stages});
  final PipelineId id;
  final List<PipelineStage> stages;
}

class PipelineContext {
  PipelineContext({required this.sessionId});
  final SessionId sessionId;
  
  void emitTelemetry(TelemetryEvent event) {}
}
