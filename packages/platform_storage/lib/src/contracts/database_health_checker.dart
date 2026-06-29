class DatabaseDiagnostics {
  final int schemaVersion;
  final int databaseSizeBytes;
  final bool integrityOk;
  final bool needsVacuum;

  const DatabaseDiagnostics({
    required this.schemaVersion,
    required this.databaseSizeBytes,
    required this.integrityOk,
    required this.needsVacuum,
  });
}

abstract interface class DatabaseHealthChecker {
  Future<DatabaseDiagnostics> checkHealth();
  Future<void> optimize();
}
