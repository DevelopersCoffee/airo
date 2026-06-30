abstract interface class RuntimeInspector {
  Map<String, dynamic> getRuntimeStatus();
}

abstract interface class EngineInspector {
  Map<String, dynamic> getEngineStatus(String engineId);
}

abstract interface class CompositionGraph {
  Map<String, dynamic> getDependencyGraph();
}

abstract interface class EventStreamMonitor {
  Stream<Map<String, dynamic>> monitorEvents();
}
