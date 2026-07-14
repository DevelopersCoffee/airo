import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo analytics contracts', () {
    AiroAnalyticsEvent event({
      String name = 'playback_started',
      AiroAnalyticsPurpose purpose = AiroAnalyticsPurpose.product,
      Map<String, Object?> params = const {'source_type': 'iptv'},
    }) {
      return AiroAnalyticsEvent(
        name: name,
        owner: 'media',
        purpose: purpose,
        params: params,
      );
    }

    test('accepts bucketed product events when consent allows collection', () {
      final result = validateEvent(
        event(params: const {'source_type': 'iptv', 'delay_bucket': '0_3s'}),
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
    });

    test('drops product events in local-only mode', () {
      final result = validateEvent(
        event(),
        consent: const AiroAnalyticsConsentState.localOnly(),
      );

      expect(result.status, AiroAnalyticsTrackStatus.droppedByLocalOnly);
    });

    test('rejects invalid event names', () {
      final result = validateEvent(
        event(name: 'Playback Started'),
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      expect(result.status, AiroAnalyticsTrackStatus.rejectedSchema);
    });

    test('rejects prohibited media fields before provider upload', () {
      final result = validateEvent(
        event(params: const {'channel': 'City News Live'}),
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      expect(result.status, AiroAnalyticsTrackStatus.rejectedPrivacy);
      expect(
        result.violations.single.code,
        AiroAnalyticsPrivacyCode.prohibitedFieldName,
      );
      expect(result.violations.single.field, 'channel');
    });

    test('rejects URL, local path, local IP, and auth-like values', () {
      final result = validateEvent(
        event(
          params: const {
            'source_type': 'https://example.com/live.m3u8',
            'storage_bucket': '/Users/example/video.ts',
            'network_bucket': '192.168.1.10',
            'auth_bucket': 'Bearer abc.def',
          },
        ),
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      expect(result.status, AiroAnalyticsTrackStatus.rejectedPrivacy);
      expect(
        result.violations.map((violation) => violation.code),
        containsAll(const {
          AiroAnalyticsPrivacyCode.urlValue,
          AiroAnalyticsPrivacyCode.localPathValue,
          AiroAnalyticsPrivacyCode.localIpValue,
          AiroAnalyticsPrivacyCode.credentialLikeValue,
        }),
      );
    });

    test('no-op provider validates without retaining events', () async {
      const service = AiroNoOpAnalyticsService(
        consent: AiroAnalyticsConsentState.allEnabled(),
      );

      final result = await service.track(event());
      await service.flush();
      await service.reset();

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
    });

    test('local diagnostics provider keeps a bounded accepted queue', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.allEnabled(),
        maxEvents: 1,
      );

      final first = await service.track(event(name: 'first_event'));
      final second = await service.track(event(name: 'second_event'));

      expect(first.status, AiroAnalyticsTrackStatus.accepted);
      expect(second.status, AiroAnalyticsTrackStatus.droppedQueueFull);
      expect(service.events.map((event) => event.name), ['first_event']);

      await service.reset();
      expect(service.events, isEmpty);
    });
  });
}
