
import 'package:platform_execution/platform_execution.dart';
import 'package:platform_identity/platform_identity.dart';
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

class StageDescriptor {
  final StageId id;
  final String version;
  final SchemaDescriptor inputSchema;
  final SchemaDescriptor outputSchema;
  final List<String> requiredCapabilities;
  
  final bool cacheable;
  final String? cachePolicy;
  
  StageDescriptor({
    required this.id,
    required this.version,
    required this.inputSchema,
    required this.outputSchema,
    this.requiredCapabilities = const [],
    this.cacheable = false,
    this.cachePolicy,
  });
}

class ExecutionProfile {
  final int minimumMemoryBytes;
  final int preferredMemoryBytes;
  final int maximumMemoryBytes;
  
  final int minimumThreads;
  final int preferredThreads;
  
  final List<String> preferredAccelerators;
  
  final Duration? expectedLatency;
  final int? expectedThroughput;

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
}

class TelemetryEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  TelemetryEvent(this.type, this.data) : timestamp = DateTime.now();
}

abstract class PipelineStage<I, O> {
  StageDescriptor get descriptor;
  ExecutionProfile get executionProfile;
  Future<O> execute(I input, PipelineContext context);
}

class PipelineDag {
  final PipelineId id;
  final List<PipelineStage> stages;
  PipelineDag({required this.id, required this.stages});
}

class PipelineContext {
  final SessionId sessionId;
  PipelineContext({required this.sessionId});
  
  void emitTelemetry(TelemetryEvent event) {}
}
