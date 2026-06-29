abstract interface class DiagnosticCollector {
  Future<DiagnosticReport> collectDiagnostics();
}

enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
  unknown
}

class DiagnosticSnapshot {
  final String component;
  final HealthStatus status;
  final Map<String, dynamic> metrics;
  
  const DiagnosticSnapshot(this.component, this.status, this.metrics);
}

class DiagnosticReport {
  final DateTime timestamp;
  final List<DiagnosticSnapshot> snapshots;
  
  const DiagnosticReport(this.timestamp, this.snapshots);
}

abstract interface class PerformanceMarker {
  void start(String operation);
  void finish(String operation);
}
