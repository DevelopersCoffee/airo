import 'package:benchmark_harness/benchmark_harness.dart';

import 'results.dart';

/// Benchmark that measures channel deduplication / normalization throughput.
///
/// Mirrors the dedup logic in the production `M3UParserService.parseM3U` which
/// normalizes channel names and keeps the first occurrence (preferring entries
/// with a logo).
class DedupBenchmark extends BenchmarkBase {
  static const int _channelCount = 200;
  late final List<_RawEntry> _entries;

  DedupBenchmark() : super('ChannelDedup');

  @override
  void setup() {
    _entries = _buildFixture(_channelCount);
  }

  @override
  void run() {
    final deduped = _dedup(_entries);
    // Prevent dead-code elimination.
    if (deduped.isEmpty) {
      throw StateError('Dedup returned empty');
    }
  }

  /// Run the benchmark and return structured results.
  List<BenchmarkResult> measureResults() {
    final usPerIteration = BenchmarkBase.measureFor(run, 2000);

    final opsPerSec =
        _channelCount / (usPerIteration / Duration.microsecondsPerSecond);

    final now = DateTime.now().toUtc();
    return [
      BenchmarkResult(
        name: 'channel_dedup_${_channelCount}',
        metric: 'channels_per_sec',
        value: opsPerSec,
        unit: 'channels/s',
        deviceClass: 'desktop',
        timestamp: now,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Internal helpers mirroring the production dedup algorithm.
// ---------------------------------------------------------------------------

class _RawEntry {
  final String name;
  final String url;
  final String? logo;
  const _RawEntry({required this.name, required this.url, this.logo});
}

/// Generate a fixture with ~30 % duplicate names.
List<_RawEntry> _buildFixture(int count) {
  final entries = <_RawEntry>[];
  for (var i = 0; i < count; i++) {
    // Every third entry is a duplicate of an earlier channel (with variation).
    final isDup = i >= 3 && i % 3 == 0;
    final baseName = isDup ? 'Channel ${i - 3}' : 'Channel $i';
    entries.add(_RawEntry(
      name: baseName,
      url: 'https://stream.example.com/live/$i.m3u8',
      logo: isDup ? 'https://example.com/logo_$i.png' : null,
    ));
  }
  return entries;
}

/// Normalize + dedup, keeping the entry with the best logo.
List<_RawEntry> _dedup(List<_RawEntry> entries) {
  final seen = <String, _RawEntry>{};
  for (final e in entries) {
    final key = _normalize(e.name);
    if (!seen.containsKey(key)) {
      seen[key] = e;
    } else if (seen[key]!.logo == null && e.logo != null) {
      seen[key] = e;
    }
  }
  return seen.values.toList();
}

String _normalize(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
