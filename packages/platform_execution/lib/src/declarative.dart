
enum Priority { low, normal, high, critical }
enum IsolationPolicy { thread, isolate, process }

class MemoryBudget {
  final int maxBytes;
  MemoryBudget({required this.maxBytes});
}

class Workload {
  final String type;
  Workload({required this.type});
}

class ExecutionRequest {
  final Workload workload;
  final Priority priority;
  final MemoryBudget? memoryBudget;
  final Duration? maxLatency;
  final IsolationPolicy isolationPolicy;

  ExecutionRequest({
    required this.workload,
    this.priority = Priority.normal,
    this.memoryBudget,
    this.maxLatency,
    this.isolationPolicy = IsolationPolicy.thread,
  });
}

class ExecutionGraph {
  // DAG of resolved execution stages mapped to backends/engines
}
