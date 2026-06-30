class EngineDiagnostics {

  const EngineDiagnostics({
    this.loadTime = Duration.zero,
    this.timeToFirstToken = Duration.zero,
    this.tokensPerSecond = 0.0,
    this.memoryUsageMb = 0,
    this.kvCacheUsageMb = 0,
    this.activeSessions = 0,
    this.failures = 0,
  });
  final Duration loadTime;
  final Duration timeToFirstToken;
  final double tokensPerSecond;
  final int memoryUsageMb;
  final int kvCacheUsageMb;
  final int activeSessions;
  final int failures;
}
