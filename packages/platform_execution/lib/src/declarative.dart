
enum Priority { low, normal, high, critical }
enum IsolationPolicy { thread, isolate, process }
enum StreamingMode { none, partial, full }
enum BatchingMode { none, dynamic, static }
enum CheckpointPolicy { never, onStageComplete, onInterval, always }
enum RetryPolicy { never, exponential, linear }

enum WorkloadType {
  generation,
  embedding,
  retrieval,
  chunking,
  parsing,
  ocr,
  vision,
  speechRecognition,
  speechSynthesis,
  translation,
  classification,
  summarization,
  toolExecution,
  workflow,
  indexing,
  synchronization
}

class ResourceRequest {
  final int? cpuMillis;
  final int? gpuMillis;
  final int? npuMillis;
  final int? ramBytes;
  final int? storageBytes;
  final int? networkBytes;
  final int? batteryPercent;
  final int? thermalLimit;

  ResourceRequest({
    this.cpuMillis,
    this.gpuMillis,
    this.npuMillis,
    this.ramBytes,
    this.storageBytes,
    this.networkBytes,
    this.batteryPercent,
    this.thermalLimit,
  });
}

class ExecutionRequest {
  final WorkloadType workloadType;
  final String inputSchema;
  final String outputSchema;
  
  final Priority priority;
  final Duration? latencyTarget;
  final Duration? deadline;
  final ResourceRequest? resourceRequest;
  
  final dynamic cancellationToken;
  
  final RetryPolicy retryPolicy;
  final CheckpointPolicy checkpointPolicy;
  final StreamingMode streamingMode;
  final BatchingMode batchingMode;
  final IsolationPolicy isolationPolicy;
  
  final List<String> requiredCapabilities;
  final List<String> preferredBackends;
  final List<String> preferredAccelerators;
  final String? deviceAffinity;

  ExecutionRequest({
    required this.workloadType,
    required this.inputSchema,
    required this.outputSchema,
    this.priority = Priority.normal,
    this.latencyTarget,
    this.deadline,
    this.resourceRequest,
    this.cancellationToken,
    this.retryPolicy = RetryPolicy.exponential,
    this.checkpointPolicy = CheckpointPolicy.onStageComplete,
    this.streamingMode = StreamingMode.none,
    this.batchingMode = BatchingMode.dynamic,
    this.isolationPolicy = IsolationPolicy.thread,
    this.requiredCapabilities = const [],
    this.preferredBackends = const [],
    this.preferredAccelerators = const [],
    this.deviceAffinity,
  });
}

class ExecutionConstraints {}

class ExecutionGraph {
  // DAG of resolved execution stages
}

class ExecutionRun {
  final String runId;
  final ExecutionGraph graph;
  ExecutionRun({required this.runId, required this.graph});
}

class ExecutionResult {
  final String runId;
  final bool success;
  ExecutionResult({required this.runId, required this.success});
}

class Workload {
  final WorkloadType type;
  Workload({required this.type});
}
