/// Performance benchmark harness for Airo.
///
/// Provides benchmarks for M3U parsing, channel deduplication, and a
/// structured [BenchmarkResult] model for CI consumption.
library benchmarks;

export 'src/m3u_parse_bench.dart';
export 'src/dedup_bench.dart';
export 'src/results.dart';
