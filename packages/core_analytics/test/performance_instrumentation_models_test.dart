import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroPerformanceBudgetPolicy', () {
    const policy = AiroPerformanceBudgetPolicy();
    final observedAt = DateTime.utc(2026, 7, 14, 15);

    AiroPerformanceSample sample({
      String sampleId = 'playback-startup-1',
      AiroPerformanceArea area = AiroPerformanceArea.playback,
      AiroPerformanceMetric metric = AiroPerformanceMetric.timeToFirstFrame,
      AiroPerformanceUnit unit = AiroPerformanceUnit.milliseconds,
      double value = 1200,
    }) {
      return AiroPerformanceSample(
        sampleId: sampleId,
        area: area,
        metric: metric,
        unit: unit,
        value: value,
        bucket: bucketLatency(Duration(milliseconds: value.toInt())),
        observedAt: observedAt,
        dimensions: [
          AiroPerformanceDimension(
            key: AiroPerformanceSafeValue.stable('profile'),
            value: AiroPerformanceSafeValue.stable('lite_receiver'),
          ),
        ],
      );
    }

    test('accepts playback startup sample within budget', () {
      final evaluation = policy.evaluate(
        budget: AiroPerformanceBudget(
          budgetId: 'ttff-under-3s',
          area: AiroPerformanceArea.playback,
          metric: AiroPerformanceMetric.timeToFirstFrame,
          unit: AiroPerformanceUnit.milliseconds,
          maximum: 3000,
        ),
        sample: sample(),
      );

      expect(evaluation.accepted, isTrue);
      expect(sample().bucket, AiroPerformanceBucket.oneTo3s);
      expect(sample().isLatencyMetric, isTrue);
    });

    test('rejects over-budget and mismatched samples', () {
      final evaluation = policy.evaluate(
        budget: AiroPerformanceBudget(
          budgetId: 'search-under-100ms',
          area: AiroPerformanceArea.search,
          metric: AiroPerformanceMetric.searchLatency,
          unit: AiroPerformanceUnit.milliseconds,
          maximum: 100,
        ),
        sample: sample(
          area: AiroPerformanceArea.playback,
          metric: AiroPerformanceMetric.timeToFirstFrame,
          value: 1200,
        ),
      );

      expect(
        evaluation.blockers,
        contains(AiroPerformanceBudgetBlockerCode.areaMismatch),
      );
      expect(
        evaluation.blockers,
        contains(AiroPerformanceBudgetBlockerCode.metricMismatch),
      );
      expect(
        evaluation.blockers,
        contains(AiroPerformanceBudgetBlockerCode.aboveMaximum),
      );
    });

    test('rejects missing sample for required budget', () {
      final evaluation = policy.evaluate(
        budget: AiroPerformanceBudget(
          budgetId: 'memory-under-256mb',
          area: AiroPerformanceArea.memory,
          metric: AiroPerformanceMetric.memoryUsage,
          unit: AiroPerformanceUnit.megabytes,
          maximum: 256,
        ),
      );

      expect(
        evaluation.blockers,
        contains(AiroPerformanceBudgetBlockerCode.missingSample),
      );
    });
  });

  group('AiroPerformanceSafeValue', () {
    test('rejects unsafe dimension keys and values', () {
      expect(
        () => AiroPerformanceSafeValue.stable('playlistUrl'),
        throwsArgumentError,
      );
      expect(
        () => AiroPerformanceSafeValue.stable('https://example.com/live.m3u8'),
        throwsArgumentError,
      );
      expect(
        () => AiroPerformanceSafeValue.stable('/Users/me/movie.mp4'),
        throwsArgumentError,
      );
      expect(
        () => AiroPerformanceSafeValue.stable('192.168.1.10'),
        throwsArgumentError,
      );
      expect(
        () => AiroPerformanceSafeValue.stable('Bearer abc123'),
        throwsArgumentError,
      );
    });

    test('rejects unsafe sample and budget ids', () {
      expect(
        () => AiroPerformanceSample(
          sampleId: 'https://example.com/sample',
          area: AiroPerformanceArea.playback,
          metric: AiroPerformanceMetric.timeToFirstFrame,
          unit: AiroPerformanceUnit.milliseconds,
          value: 100,
          observedAt: DateTime.utc(2026, 7, 14, 15),
        ),
        throwsArgumentError,
      );
      expect(
        () => AiroPerformanceBudget(
          budgetId: '/Users/me/budget',
          area: AiroPerformanceArea.playback,
          metric: AiroPerformanceMetric.timeToFirstFrame,
          unit: AiroPerformanceUnit.milliseconds,
          maximum: 3000,
        ),
        throwsArgumentError,
      );
    });

    test('sample string output hides dimension values', () {
      final sample = AiroPerformanceSample(
        sampleId: 'import-throughput-1',
        area: AiroPerformanceArea.import,
        metric: AiroPerformanceMetric.importThroughput,
        unit: AiroPerformanceUnit.rowsPerSecond,
        value: 5000,
        observedAt: DateTime.utc(2026, 7, 14, 15),
        dimensions: [
          AiroPerformanceDimension(
            key: AiroPerformanceSafeValue.stable('worker'),
            value: AiroPerformanceSafeValue.stable('large_playlist_worker'),
          ),
        ],
      );

      final rendered = sample.toString();

      expect(rendered, contains('import_throughput'));
      expect(rendered, contains('dimensionCount: 1'));
      expect(rendered, isNot(contains('large_playlist_worker')));
      expect(rendered, isNot(contains('http')));
      expect(rendered, isNot(contains('/Users/')));
    });
  });

  group('AiroPerformanceInstrumentationSink adapters', () {
    test('no-op sink accepts samples without retaining them', () async {
      const sink = AiroNoOpPerformanceInstrumentationSink();

      final result = await sink.record(
        AiroPerformanceSample(
          sampleId: 'enqueue-1',
          area: AiroPerformanceArea.network,
          metric: AiroPerformanceMetric.analyticsEnqueueLatency,
          unit: AiroPerformanceUnit.milliseconds,
          value: 2,
          bucket: bucketLatency(const Duration(milliseconds: 2)),
          observedAt: DateTime.utc(2026, 7, 14, 15),
        ),
      );

      expect(result.accepted, isTrue);
    });

    test('fake sink keeps bounded deterministic samples', () async {
      final sink = AiroFakePerformanceInstrumentationSink(maxSamples: 1);
      final sample = AiroPerformanceSample(
        sampleId: 'protocol-rtt-1',
        area: AiroPerformanceArea.protocol,
        metric: AiroPerformanceMetric.protocolRoundTrip,
        unit: AiroPerformanceUnit.milliseconds,
        value: 40,
        bucket: bucketLatency(const Duration(milliseconds: 40)),
        observedAt: DateTime.utc(2026, 7, 14, 15),
      );

      final first = await sink.record(sample);
      final second = await sink.record(sample);

      expect(first.accepted, isTrue);
      expect(second.accepted, isFalse);
      expect(second.reason, AiroPerformanceBudgetBlockerCode.aboveMaximum);
      expect(sink.samples.single.sampleId, 'protocol-rtt-1');
    });
  });
}
