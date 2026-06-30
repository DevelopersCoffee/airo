class BenchmarkMetrics {
  const BenchmarkMetrics({
    this.ttftMs = 0,
    this.tokensPerSecond = 0,
    this.ingestionMbPerSecond = 0,
    this.parserThroughput = 0,
    this.embeddingThroughput = 0,
    this.indexThroughput = 0,
    this.peakRamKb = 0,
    this.batteryImpact = 0,
    this.startupLatencyMs = 0,
    this.cacheHitRate = 0,
  });

  final int ttftMs;
  final double tokensPerSecond;
  final double ingestionMbPerSecond;
  final double parserThroughput;
  final double embeddingThroughput;
  final double indexThroughput;
  final int peakRamKb;
  final double batteryImpact;
  final int startupLatencyMs;
  final double cacheHitRate;
}
