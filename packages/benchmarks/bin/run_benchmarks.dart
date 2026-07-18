import 'dart:convert';
import 'dart:io';

import 'package:benchmarks/benchmarks.dart';

/// Entry point for the benchmark harness.
///
/// Runs all registered benchmarks, prints results to stdout as JSON, and
/// writes them to `benchmark_results.json` in the current directory.
Future<void> main() async {
  final allResults = <BenchmarkResult>[];

  // ---- M3U Parse benchmark ------------------------------------------------
  stderr.writeln('Running M3U parse benchmark...');
  final m3uBench = M3UParseBenchmark();
  m3uBench.setup();
  allResults.addAll(m3uBench.measureResults());

  // ---- Channel dedup benchmark ---------------------------------------------
  stderr.writeln('Running channel dedup benchmark...');
  final dedupBench = DedupBenchmark();
  dedupBench.setup();
  allResults.addAll(dedupBench.measureResults());

  // ---- Output --------------------------------------------------------------
  final jsonOutput = const JsonEncoder.withIndent(
    '  ',
  ).convert(allResults.map((r) => r.toJson()).toList());

  // Structured JSON to stdout for CI consumption.
  stdout.writeln(jsonOutput);

  // Also persist to a file for artifact upload.
  const outputPath = 'benchmark_results.json';
  await File(outputPath).writeAsString(jsonOutput);
  stderr.writeln('Results written to $outputPath');
}
