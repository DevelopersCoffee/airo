import 'package:core_analytics/core_analytics.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airo_app/core/providers/streaming_telemetry_consent_provider.dart';

void main() {
  group('loadStreamingTelemetryConsent', () {
    test('withholds playbackQuality by default (opt-in only, F7.5)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final consent = loadStreamingTelemetryConsent(prefs);

      expect(consent.playbackQuality, isFalse);
      expect(consent.localOnly, isFalse);
    });

    test('grants playbackQuality when the persisted flag is true', () async {
      SharedPreferences.setMockInitialValues({
        streamingTelemetryConsentStorageKey: true,
      });
      final prefs = await SharedPreferences.getInstance();

      final consent = loadStreamingTelemetryConsent(prefs);

      expect(consent.playbackQuality, isTrue);
      // Never localOnly -- that preset blackholes playbackQuality events
      // regardless of the flag itself (validateEvent's droppedByLocalOnly
      // gate runs before the per-purpose check).
      expect(consent.localOnly, isFalse);
    });
  });

  group('streamingTelemetryConsentProvider', () {
    test('defaults to withheld with nothing persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(streamingTelemetryConsentProvider), isFalse);
    });

    test('loads a persisted grant through the shared store', () async {
      SharedPreferences.setMockInitialValues({
        streamingTelemetryConsentStorageKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(streamingTelemetryConsentProvider), isTrue);
    });

    test('setEnabled(true) persists, updates state, and grants the live '
        'service instance', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = AiroLocalDiagnosticsAnalyticsService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamingTelemetryServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(streamingTelemetryConsentProvider.notifier)
          .setEnabled(true);

      expect(container.read(streamingTelemetryConsentProvider), isTrue);
      expect(prefs.getBool(streamingTelemetryConsentStorageKey), isTrue);
      expect(service.consent.playbackQuality, isTrue);
      expect(
        service.consent.localOnly,
        isFalse,
        reason: 'granting must not route through the localOnly preset',
      );
    });

    test('setEnabled(false) revokes on the live service instance', () async {
      SharedPreferences.setMockInitialValues({
        streamingTelemetryConsentStorageKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState(
          operational: true,
          product: false,
          playbackQuality: true,
          diagnostics: false,
          crash: false,
          personalized: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamingTelemetryServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(streamingTelemetryConsentProvider.notifier)
          .setEnabled(false);

      expect(container.read(streamingTelemetryConsentProvider), isFalse);
      expect(prefs.getBool(streamingTelemetryConsentStorageKey), isFalse);
      expect(service.consent.playbackQuality, isFalse);
    });

    test(
      'a granted event actually survives validateEvent (end to end)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = AiroLocalDiagnosticsAnalyticsService();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            streamingTelemetryServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(streamingTelemetryConsentProvider.notifier)
            .setEnabled(true);

        final result = await service.track(
          AiroAnalyticsEvent(
            name: 'streaming_session_summary',
            owner: 'test',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {'sessionId': 'test'},
          ),
        );

        expect(result.status, AiroAnalyticsTrackStatus.accepted);
      },
    );
  });
}
