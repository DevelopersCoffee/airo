import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroStreamingSessionSummary', () {
    AiroStreamingSessionSummary summary({
      String sessionId = 'session-1',
      String activeSourceId = 'source-primary',
      String networkKey = 'wifi:abc123',
      int? ttffMs = 1200,
      int rebufferCount = 0,
      double rebufferDurationRatio = 0,
      int sourceSwitchCount = 0,
      double? throughputKbpsP50 = 4200,
      double? throughputKbpsP10 = 1800,
    }) {
      return AiroStreamingSessionSummary(
        sessionId: sessionId,
        activeSourceId: activeSourceId,
        networkKey: networkKey,
        ttffMs: ttffMs,
        rebufferCount: rebufferCount,
        rebufferDurationRatio: rebufferDurationRatio,
        sourceSwitchCount: sourceSwitchCount,
        throughputKbpsP50: throughputKbpsP50,
        throughputKbpsP10: throughputKbpsP10,
      );
    }

    test('accepts a well-formed summary', () {
      final result = summary().validate();

      expect(result.accepted, isTrue);
      expect(result.codes, [
        AiroStreamingSessionSummaryValidationCode.accepted,
      ]);
    });

    test('rejects a negative rebuffer count', () {
      final result = summary(rebufferCount: -1).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(AiroStreamingSessionSummaryValidationCode.negativeCount),
      );
    });

    test('rejects a negative source switch count', () {
      final result = summary(sourceSwitchCount: -1).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(AiroStreamingSessionSummaryValidationCode.negativeCount),
      );
    });

    test('rejects a negative time-to-first-frame', () {
      final result = summary(ttffMs: -1).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(AiroStreamingSessionSummaryValidationCode.negativeCount),
      );
    });

    test('accepts a null time-to-first-frame (session stopped before first frame)', () {
      final result = summary(ttffMs: null).validate();

      expect(result.accepted, isTrue);
    });

    test('rejects a rebuffer duration ratio above 1', () {
      final result = summary(rebufferDurationRatio: 1.5).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(
          AiroStreamingSessionSummaryValidationCode.rebufferRatioOutOfRange,
        ),
      );
    });

    test('rejects a negative rebuffer duration ratio', () {
      final result = summary(rebufferDurationRatio: -0.1).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(
          AiroStreamingSessionSummaryValidationCode.rebufferRatioOutOfRange,
        ),
      );
    });

    test('rejects negative throughput samples', () {
      final result = summary(throughputKbpsP50: -1).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(
          AiroStreamingSessionSummaryValidationCode.negativeThroughput,
        ),
      );
    });

    test('accepts null throughput samples (not yet measured)', () {
      final result = summary(
        throughputKbpsP50: null,
        throughputKbpsP10: null,
      ).validate();

      expect(result.accepted, isTrue);
    });

    test('rejects a raw stream URL as the active source id', () {
      final result = summary(
        activeSourceId: 'https://provider.example/live/user/pass/1.ts',
      ).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(AiroStreamingSessionSummaryValidationCode.unsafeFieldValue),
      );
    });

    test('rejects a credential-shaped active source id', () {
      final result = summary(
        activeSourceId: 'Bearer abc.def.ghi',
      ).validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(AiroStreamingSessionSummaryValidationCode.unsafeFieldValue),
      );
    });

    test('produces an analytics event on the playback_quality purpose', () {
      final event = summary().toAnalyticsEvent();

      expect(event.name, 'streaming_session_summary');
      expect(event.owner, 'platform_player');
      expect(event.purpose, AiroAnalyticsPurpose.playbackQuality);
    });

    test('analytics event carries every summary field under a snake_case key', () {
      final event = summary().toAnalyticsEvent();

      expect(event.params['session_id'], 'session-1');
      expect(event.params['active_source_id'], 'source-primary');
      expect(event.params['network_key'], 'wifi:abc123');
      expect(event.params['ttff_ms'], 1200);
      expect(event.params['rebuffer_count'], 0);
      expect(event.params['rebuffer_duration_ratio'], 0);
      expect(event.params['source_switch_count'], 0);
      expect(event.params['throughput_kbps_p50'], 4200);
      expect(event.params['throughput_kbps_p10'], 1800);
    });

    test('analytics event omits ttff_ms when null', () {
      final event = summary(ttffMs: null).toAnalyticsEvent();

      expect(event.params.containsKey('ttff_ms'), isFalse);
    });

    test('passes the repository-wide analytics validator when well-formed', () {
      final event = summary().toAnalyticsEvent();
      final result = validateEvent(
        event,
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
    });

    test(
      'the repository-wide analytics validator rejects a raw-URL source id '
      'even if callers skip the summary-level validate() step',
      () {
        final event = summary(
          activeSourceId: 'https://provider.example/live/user/pass/1.ts',
        ).toAnalyticsEvent();
        final result = validateEvent(
          event,
          consent: const AiroAnalyticsConsentState.allEnabled(),
        );

        expect(result.status, AiroAnalyticsTrackStatus.rejectedPrivacy);
      },
    );

    test('is Equatable by value', () {
      expect(summary(), summary());
    });
  });
}
