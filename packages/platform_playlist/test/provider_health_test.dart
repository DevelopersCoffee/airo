import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  const sourceId = 'xtream-123';
  final t0 = DateTime.utc(2026, 7, 17, 12);

  group('ProviderHealthTracker.snapshotFor (empty)', () {
    test('unknown class + zero samples for an unrecorded source', () {
      final tracker = ProviderHealthTracker();
      final snap = tracker.snapshotFor(sourceId);
      expect(snap.sourceId, sourceId);
      expect(snap.totalSamples, 0);
      expect(snap.healthClass, ProviderHealthClass.unknown);
      expect(snap.lastSuccessUtc, isNull);
      expect(snap.lastFailureUtc, isNull);
      expect(snap.failureRate, 0.0);
      expect(snap.p50Latency, isNull);
      expect(snap.p95Latency, isNull);
    });
  });

  group('single sample paths', () {
    test('single fetchSuccess → green + lastSuccess set', () {
      final tracker = ProviderHealthTracker();
      tracker.record(
        ProviderHealthSample.fetchSuccess(
          sourceId: sourceId,
          timestampUtc: t0,
          latency: const Duration(milliseconds: 120),
        ),
      );
      final snap = tracker.snapshotFor(sourceId);
      expect(snap.healthClass, ProviderHealthClass.green);
      expect(snap.lastSuccessUtc, t0);
      expect(snap.lastFailureUtc, isNull);
      expect(snap.failureRate, 0.0);
      expect(snap.p50Latency, const Duration(milliseconds: 120));
    });

    test(
      'single fetchFailure → red + lastFailure set + recentFailureCategory',
      () {
        final tracker = ProviderHealthTracker();
        tracker.record(
          ProviderHealthSample.fetchFailure(
            sourceId: sourceId,
            timestampUtc: t0,
            failureCategory: ProviderHealthFailureCategory.auth,
            httpStatus: 401,
          ),
        );
        final snap = tracker.snapshotFor(sourceId);
        expect(snap.healthClass, ProviderHealthClass.red);
        expect(snap.lastFailureUtc, t0);
        expect(snap.failureRate, 1.0);
        expect(snap.recentFailureCategory, ProviderHealthFailureCategory.auth);
      },
    );

    test('fetchFailure requires a failureCategory', () {
      expect(
        () => ProviderHealthSample(
          sourceId: sourceId,
          timestampUtc: t0,
          kind: ProviderHealthEventKind.fetchFailure,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('mixed samples', () {
    test('80/20 success/failure → amber, failureRate ~0.2', () {
      final tracker = ProviderHealthTracker();
      for (var i = 0; i < 8; i++) {
        tracker.record(
          ProviderHealthSample.fetchSuccess(
            sourceId: sourceId,
            timestampUtc: t0.add(Duration(seconds: i)),
            latency: const Duration(milliseconds: 100),
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        tracker.record(
          ProviderHealthSample.fetchFailure(
            sourceId: sourceId,
            timestampUtc: t0.add(Duration(seconds: 100 + i)),
            failureCategory: ProviderHealthFailureCategory.server,
            httpStatus: 502,
          ),
        );
      }
      final snap = tracker.snapshotFor(sourceId);
      expect(snap.totalSamples, 10);
      expect(snap.failureRate, closeTo(0.2, 1e-9));
      expect(snap.healthClass, ProviderHealthClass.amber);
      expect(snap.recentFailureCategory, ProviderHealthFailureCategory.server);
    });

    test('50% failure rate → red', () {
      final tracker = ProviderHealthTracker();
      for (var i = 0; i < 5; i++) {
        tracker.record(
          ProviderHealthSample.fetchSuccess(
            sourceId: sourceId,
            timestampUtc: t0.add(Duration(seconds: i)),
            latency: const Duration(milliseconds: 100),
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        tracker.record(
          ProviderHealthSample.fetchFailure(
            sourceId: sourceId,
            timestampUtc: t0.add(Duration(seconds: 100 + i)),
            failureCategory: ProviderHealthFailureCategory.network,
          ),
        );
      }
      expect(
        tracker.snapshotFor(sourceId).healthClass,
        ProviderHealthClass.red,
      );
    });

    test('5+ playback stalls escalates to red', () {
      final tracker = ProviderHealthTracker();
      tracker.record(
        ProviderHealthSample.fetchSuccess(
          sourceId: sourceId,
          timestampUtc: t0,
          latency: const Duration(milliseconds: 100),
        ),
      );
      for (var i = 0; i < 5; i++) {
        tracker.record(
          ProviderHealthSample.playbackStall(
            sourceId: sourceId,
            timestampUtc: t0.add(Duration(seconds: i)),
          ),
        );
      }
      final snap = tracker.snapshotFor(sourceId);
      expect(snap.playbackStallCount, 5);
      expect(snap.healthClass, ProviderHealthClass.red);
    });
  });

  group('percentiles', () {
    test('p50/p95 sorted from recorded latencies', () {
      final tracker = ProviderHealthTracker();
      for (final ms in [10, 20, 30, 40, 50, 60, 70, 80, 90, 1000]) {
        tracker.record(
          ProviderHealthSample.fetchSuccess(
            sourceId: sourceId,
            timestampUtc: t0,
            latency: Duration(milliseconds: ms),
          ),
        );
      }
      final snap = tracker.snapshotFor(sourceId);
      // 10 samples: (10-1)*0.5=4.5 rounds up → index 5 → 60ms; the p95
      // outlier lands at index 9 → 1000ms.
      expect(snap.p50Latency, const Duration(milliseconds: 60));
      expect(snap.p95Latency, const Duration(milliseconds: 1000));
    });
  });

  group('ring buffer eviction', () {
    test('drops the oldest sample when maxSamplesPerSource is exceeded', () {
      final tracker = ProviderHealthTracker(maxSamplesPerSource: 3);
      for (var i = 0; i < 5; i++) {
        tracker.record(
          ProviderHealthSample.fetchSuccess(
            sourceId: sourceId,
            timestampUtc: t0.add(Duration(seconds: i)),
            latency: const Duration(milliseconds: 10),
          ),
        );
      }
      expect(tracker.sampleCountFor(sourceId), 3);
      final snap = tracker.snapshotFor(sourceId);
      expect(snap.totalSamples, 3);
      // Only the three most recent successes survive.
      expect(snap.lastSuccessUtc, t0.add(const Duration(seconds: 4)));
    });
  });

  group('isolation across sources', () {
    test('clearFor drops one source without touching another', () {
      final tracker = ProviderHealthTracker();
      tracker.record(
        ProviderHealthSample.fetchSuccess(
          sourceId: 'a',
          timestampUtc: t0,
          latency: const Duration(milliseconds: 10),
        ),
      );
      tracker.record(
        ProviderHealthSample.fetchSuccess(
          sourceId: 'b',
          timestampUtc: t0,
          latency: const Duration(milliseconds: 10),
        ),
      );
      tracker.clearFor('a');
      expect(tracker.snapshotFor('a').totalSamples, 0);
      expect(tracker.snapshotFor('b').totalSamples, 1);
    });

    test('clearAll wipes every source', () {
      final tracker = ProviderHealthTracker();
      tracker.record(
        ProviderHealthSample.fetchSuccess(
          sourceId: 'a',
          timestampUtc: t0,
          latency: const Duration(milliseconds: 10),
        ),
      );
      tracker.record(
        ProviderHealthSample.fetchSuccess(
          sourceId: 'b',
          timestampUtc: t0,
          latency: const Duration(milliseconds: 10),
        ),
      );
      tracker.clearAll();
      expect(tracker.snapshotFor('a').totalSamples, 0);
      expect(tracker.snapshotFor('b').totalSamples, 0);
    });
  });

  group('redaction discipline', () {
    test('ProviderHealthSample carries no URL or credential fields', () {
      // Compile-time guarantee via the model itself — this test acts as a
      // canary: if someone adds a `url` or `credentials` field, the
      // props list widens and this test fails, forcing a review.
      final sample = ProviderHealthSample.fetchFailure(
        sourceId: sourceId,
        timestampUtc: t0,
        failureCategory: ProviderHealthFailureCategory.auth,
        httpStatus: 401,
      );
      expect(sample.props, [
        sourceId,
        t0,
        ProviderHealthEventKind.fetchFailure,
        null, // latency
        401, // httpStatus
        ProviderHealthFailureCategory.auth,
      ]);
    });
  });
}
