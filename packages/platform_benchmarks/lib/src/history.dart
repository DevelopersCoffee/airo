import 'package:platform_benchmarks/platform_benchmarks.dart';

class BenchmarkRun {
  const BenchmarkRun({
    required this.id,
    required this.timestamp,
    required this.metrics,
    required this.environment,
  });
  
  final String id;
  final DateTime timestamp;
  final BenchmarkMetrics metrics;
  final Map<String, String> environment;
}

class BenchmarkHistory {
  BenchmarkHistory(this.runs);
  final List<BenchmarkRun> runs;
}

class ComparisonReport {
  const ComparisonReport({
    required this.baseRunId,
    required this.targetRunId,
    required this.regressions,
    required this.improvements,
  });
  
  final String baseRunId;
  final String targetRunId;
  final Map<String, double> regressions;
  final Map<String, double> improvements;
}

abstract class RegressionDetector {
  ComparisonReport detect(BenchmarkHistory history, String baseId, String targetId);
}
