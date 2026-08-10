import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/src/services/streaming_session_metrics_collector.dart';

void main() {
  group('StreamingSessionMetricsCollector', () {
    late DateTime clock;
    DateTime now() => clock;

    StreamingSessionMetricsCollector collector({
      String sessionId = 'session-1',
      String activeSourceId = 'source-primary',
      String networkKey = 'wifi:abc123',
    }) {
      return StreamingSessionMetricsCollector(
        sessionId: sessionId,
        activeSourceId: activeSourceId,
        networkKey: networkKey,
        now: now,
      );
    }

    setUp(() {
      clock = DateTime.utc(2026, 1, 1);
    });

    void advance(Duration by) => clock = clock.add(by);

    test('computes time-to-first-frame from session start to first frame', () {
      final c = collector();

      c.sessionStarted();
      advance(const Duration(milliseconds: 850));
      c.firstFrameRendered();
      advance(const Duration(seconds: 5));
      final summary = c.sessionStopped();

      expect(summary.ttffMs, 850);
    });

    test('ttffMs is null when the session stops before a first frame', () {
      final c = collector();

      c.sessionStarted();
      advance(const Duration(seconds: 2));
      final summary = c.sessionStopped();

      expect(summary.ttffMs, isNull);
    });

    test('counts rebuffers and accumulates rebuffer duration ratio', () {
      final c = collector();

      c.sessionStarted();
      c.firstFrameRendered();
      // 10s of playback total, 2s of it spent rebuffering.
      advance(const Duration(seconds: 3));
      c.stallStarted();
      advance(const Duration(seconds: 1));
      c.stallEnded();
      advance(const Duration(seconds: 5));
      c.stallStarted();
      advance(const Duration(seconds: 1));
      c.stallEnded();
      advance(const Duration(seconds: 0));
      final summary = c.sessionStopped();

      expect(summary.rebufferCount, 2);
      expect(summary.rebufferDurationRatio, closeTo(0.2, 0.001));
    });

    test('stallEnded without a matching stallStarted is a no-op', () {
      final c = collector();

      c.sessionStarted();
      c.stallEnded();
      final summary = c.sessionStopped();

      expect(summary.rebufferCount, 0);
    });

    test('counts source switches and reports the final active source', () {
      final c = collector();

      c.sessionStarted();
      c.sourceSwitched('source-backup-1');
      c.sourceSwitched('source-backup-2');
      final summary = c.sessionStopped();

      expect(summary.sourceSwitchCount, 2);
      expect(summary.activeSourceId, 'source-backup-2');
    });

    test('reports throughput p50/p10 from streamed samples', () {
      final c = collector();

      c.sessionStarted();
      for (final kbps in [10.0, 20.0, 30.0, 40.0, 50.0]) {
        c.throughputSampleKbps(kbps);
      }
      final summary = c.sessionStopped();

      expect(summary.throughputKbpsP50, 30.0);
      expect(summary.throughputKbpsP10, 10.0);
    });

    test('throughput reservoir stays bounded under heavy sampling', () {
      final c = collector();

      c.sessionStarted();
      for (var i = 0; i < 5000; i++) {
        c.throughputSampleKbps(i.toDouble());
      }

      // Must not throw and must still produce finite percentiles.
      final summary = c.sessionStopped();
      expect(summary.throughputKbpsP50, isNotNull);
      expect(summary.throughputKbpsP10, isNotNull);
    });

    test('ignores negative throughput samples', () {
      final c = collector();

      c.sessionStarted();
      c.throughputSampleKbps(-5);
      final summary = c.sessionStopped();

      expect(summary.throughputKbpsP50, isNull);
      expect(summary.throughputKbpsP10, isNull);
    });

    test('a zero-sample session produces a valid summary with null throughput', () {
      final c = collector();

      c.sessionStarted();
      final summary = c.sessionStopped();

      expect(summary.throughputKbpsP50, isNull);
      expect(summary.throughputKbpsP10, isNull);
      expect(summary.validate().accepted, isTrue);
    });

    test('stopping twice does not throw', () {
      final c = collector();

      c.sessionStarted();
      c.firstFrameRendered();

      expect(c.sessionStopped, returnsNormally);
      expect(c.sessionStopped, returnsNormally);
    });

    test('an immediate stop (zero session duration) does not throw or produce NaN', () {
      final c = collector();

      c.sessionStarted();
      final summary = c.sessionStopped();

      expect(summary.rebufferDurationRatio, 0.0);
      expect(summary.rebufferDurationRatio.isNaN, isFalse);
    });

    test('the produced summary passes AiroStreamingSessionSummary.validate()', () {
      final c = collector();

      c.sessionStarted();
      advance(const Duration(milliseconds: 500));
      c.firstFrameRendered();
      c.throughputSampleKbps(4000);
      final summary = c.sessionStopped();

      expect(summary.validate().accepted, isTrue);
    });

    test('sessionStopped result type is the shared analytics summary model', () {
      final c = collector();
      c.sessionStarted();

      expect(c.sessionStopped(), isA<AiroStreamingSessionSummary>());
    });
  });
}
