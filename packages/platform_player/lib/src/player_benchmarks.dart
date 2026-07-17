/// Lightweight zap-time measurement utility for manual player benchmarking.
///
/// Usage:
/// ```dart
/// final bench = PlayerBenchmark();
/// final result = await bench.measureZapTime(
///   'http://example.com/stream.m3u8',
///   playFn: (url) async {
///     controller = VideoPlayerController.networkUrl(Uri.parse(url));
///     await controller.initialize();
///     await controller.play();
///   },
///   firstFrameFn: () async {
///     // Wait until first frame is rendered
///     await controller.value.isInitialized;
///   },
/// );
/// print('Zap time: ${result.zapTime.inMilliseconds} ms');
/// ```
library;

/// Result of a single zap-time measurement.
class ZapTimeResult {
  /// Time from play() invocation to first frame rendered.
  final Duration zapTime;

  /// The stream URL that was measured.
  final String url;

  /// Timestamp when the measurement was taken.
  final DateTime timestamp;

  /// Optional label (e.g. "HLS", "MPEG-TS", "media_kit", "video_player").
  final String? label;

  /// Whether the measurement completed successfully.
  final bool success;

  /// Error message if measurement failed.
  final String? error;

  const ZapTimeResult({
    required this.zapTime,
    required this.url,
    required this.timestamp,
    this.label,
    this.success = true,
    this.error,
  });

  /// Factory for a failed measurement.
  factory ZapTimeResult.failed({
    required String url,
    required String error,
    String? label,
  }) {
    return ZapTimeResult(
      zapTime: Duration.zero,
      url: url,
      timestamp: DateTime.now(),
      label: label,
      success: false,
      error: error,
    );
  }

  @override
  String toString() {
    if (!success) return 'ZapTimeResult(FAILED: $error, url: $url)';
    return 'ZapTimeResult('
        '${zapTime.inMilliseconds} ms, '
        'url: $url'
        '${label != null ? ', label: $label' : ''}'
        ')';
  }
}

/// Stopwatch-based zap-time benchmark for comparing player backends.
///
/// This class does not depend on any specific player package.  The caller
/// provides [playFn] (initiates playback) and [firstFrameFn] (resolves when
/// the first video frame is on screen).  The benchmark measures the wall-clock
/// time between the two.
class PlayerBenchmark {
  /// Timeout for a single measurement attempt.
  final Duration timeout;

  /// Number of warm-up runs to discard before recording.
  final int warmUpRuns;

  const PlayerBenchmark({
    this.timeout = const Duration(seconds: 10),
    this.warmUpRuns = 1,
  });

  /// Measure zap time for a single URL.
  ///
  /// [playFn] should call the player's initialize + play sequence.
  /// [firstFrameFn] should complete when the first frame is visible
  /// (e.g. polling `controller.value.isInitialized` or listening to a
  /// media_kit stream event).
  /// [cleanupFn] is called after each measurement to dispose the player.
  Future<ZapTimeResult> measureZapTime(
    String url, {
    required Future<void> Function(String url) playFn,
    required Future<void> Function() firstFrameFn,
    Future<void> Function()? cleanupFn,
    String? label,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      await playFn(url);
      await firstFrameFn().timeout(timeout);
      stopwatch.stop();

      return ZapTimeResult(
        zapTime: stopwatch.elapsed,
        url: url,
        timestamp: DateTime.now(),
        label: label,
      );
    } catch (e) {
      return ZapTimeResult.failed(url: url, error: e.toString(), label: label);
    } finally {
      await cleanupFn?.call();
    }
  }

  /// Run multiple measurements and return all results.
  ///
  /// The first [warmUpRuns] results are discarded to avoid cold-start bias.
  /// Returns only the recorded (post-warmup) results.
  Future<List<ZapTimeResult>> runBenchmark(
    String url, {
    required Future<void> Function(String url) playFn,
    required Future<void> Function() firstFrameFn,
    Future<void> Function()? cleanupFn,
    String? label,
    int iterations = 5,
  }) async {
    final allResults = <ZapTimeResult>[];

    final totalRuns = warmUpRuns + iterations;
    for (var i = 0; i < totalRuns; i++) {
      final result = await measureZapTime(
        url,
        playFn: playFn,
        firstFrameFn: firstFrameFn,
        cleanupFn: cleanupFn,
        label: label,
      );
      allResults.add(result);
    }

    // Discard warm-up runs.
    return allResults.skip(warmUpRuns).toList();
  }

  /// Compute summary statistics from a list of results.
  static BenchmarkSummary summarize(List<ZapTimeResult> results) {
    final successful = results.where((r) => r.success).toList();
    if (successful.isEmpty) {
      return BenchmarkSummary(
        count: results.length,
        successCount: 0,
        min: Duration.zero,
        max: Duration.zero,
        median: Duration.zero,
        mean: Duration.zero,
        p95: Duration.zero,
      );
    }

    final times = successful.map((r) => r.zapTime).toList()
      ..sort((a, b) => a.compareTo(b));

    final total = times.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    final mean = Duration(microseconds: total ~/ times.length);
    final median = times[times.length ~/ 2];
    final p95Index = (times.length * 0.95).ceil() - 1;
    final p95 = times[p95Index.clamp(0, times.length - 1)];

    return BenchmarkSummary(
      count: results.length,
      successCount: successful.length,
      min: times.first,
      max: times.last,
      median: median,
      mean: mean,
      p95: p95,
    );
  }
}

/// Summary statistics for a set of zap-time measurements.
class BenchmarkSummary {
  final int count;
  final int successCount;
  final Duration min;
  final Duration max;
  final Duration median;
  final Duration mean;
  final Duration p95;

  const BenchmarkSummary({
    required this.count,
    required this.successCount,
    required this.min,
    required this.max,
    required this.median,
    required this.mean,
    required this.p95,
  });

  @override
  String toString() {
    return 'BenchmarkSummary(\n'
        '  runs: $count ($successCount succeeded)\n'
        '  min:    ${min.inMilliseconds} ms\n'
        '  median: ${median.inMilliseconds} ms\n'
        '  mean:   ${mean.inMilliseconds} ms\n'
        '  p95:    ${p95.inMilliseconds} ms\n'
        '  max:    ${max.inMilliseconds} ms\n'
        ')';
  }
}
