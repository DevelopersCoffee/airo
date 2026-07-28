import 'dart:convert';
import 'dart:io';

import 'package:core_ai/src/embeddings/exact_vector_index.dart';

void main() {
  const corpusSize = 1200;
  const warmupIterations = 20;
  const measuredIterations = 50;

  final reports = <Map<String, Object>>[];
  for (final dimensions
      in ExactVectorIndex.supportedDimensions.toList()..sort()) {
    final index = ExactVectorIndex(
      dimensions: dimensions,
      records: [
        for (var row = 0; row < corpusSize; row += 1)
          VectorRecord(
            id: 'record-${row.toString().padLeft(4, '0')}',
            vector: _deterministicVector(dimensions, seed: row + 1),
          ),
      ],
    );
    final query = _deterministicVector(dimensions, seed: corpusSize + 1);

    for (var iteration = 0; iteration < warmupIterations; iteration += 1) {
      index.search(query, topK: 10);
    }

    final samples = <int>[];
    for (var iteration = 0; iteration < measuredIterations; iteration += 1) {
      final stopwatch = Stopwatch()..start();
      final results = index.search(query, topK: 10);
      stopwatch.stop();
      if (results.length != 10) {
        throw StateError('Expected 10 results, received ${results.length}.');
      }
      samples.add(stopwatch.elapsedMicroseconds);
    }
    samples.sort();

    reports.add({
      'dimensions': dimensions,
      'corpusSize': corpusSize,
      'topK': 10,
      'warmupIterations': warmupIterations,
      'measuredIterations': measuredIterations,
      'medianMicroseconds': _percentile(samples, 0.50),
      'p95Microseconds': _percentile(samples, 0.95),
      'maxMicroseconds': samples.last,
    });
  }

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'benchmark': 'core_ai_exact_vector_index',
      'clock': 'Stopwatch',
      'reports': reports,
    }),
  );
}

List<double> _deterministicVector(int dimensions, {required int seed}) {
  return [
    for (var column = 0; column < dimensions; column += 1)
      (((seed * 31 + column * 17) % 251) - 125) / 125,
  ];
}

int _percentile(List<int> sortedSamples, double percentile) {
  final index = ((sortedSamples.length - 1) * percentile).round();
  return sortedSamples[index];
}
