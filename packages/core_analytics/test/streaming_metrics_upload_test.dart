import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // F7.3/F7.5: this file proves that the *existing* analytics services
  // (no new gateway code -- see SPEC.md AD-P1.3) already give the streaming
  // QoE summary event (F7.1) the guarantees Phase 1 requires: nothing
  // leaves the device before consent, the local sink always records
  // regardless of upload consent, and upload never contends with an
  // active playback session.
  AiroStreamingSessionSummary summary() {
    return const AiroStreamingSessionSummary(
      sessionId: 'session-1',
      activeSourceId: 'source-primary',
      networkKey: 'wifi:abc123',
      ttffMs: 900,
      throughputKbpsP50: 4000,
      throughputKbpsP10: 1500,
    );
  }

  // Neither built-in preset (.disabled(), .localOnly()) grants
  // playbackQuality by default -- an explicit grant is required. Wiring
  // that grant into the app is a product decision (default consent
  // posture + a settings surface, see SPEC's open question P1-2) and is
  // deliberately out of scope here; these tests exercise the pipeline's
  // contract once a grant exists, not the app's default posture.
  const playbackQualityGranted = AiroAnalyticsConsentState(
    operational: true,
    product: false,
    playbackQuality: true,
    diagnostics: false,
    crash: false,
    personalized: false,
  );

  group('AiroNoOpAnalyticsService (today\'s actual default)', () {
    test('records nothing regardless of consent -- current production behavior', () async {
      final service = AiroNoOpAnalyticsService(consent: playbackQualityGranted);

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
      // No-op has no observable storage or network side effect to assert
      // on beyond the validator's own accept/reject decision -- that's
      // the point of this preset.
    });
  });

  group('AiroLocalDiagnosticsAnalyticsService (F7.5 local-first sink)', () {
    test('without consent, the summary is dropped -- no telemetry before consent', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.disabled(),
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.droppedByConsent);
      expect(service.events, isEmpty);
    });

    test('once playback_quality is granted, the summary is queued locally', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: playbackQualityGranted,
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
      expect(service.events, hasLength(1));
      expect(service.events.single.name, 'streaming_session_summary');
    });

    test('collection disabled overrides consent -- still nothing recorded', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: playbackQualityGranted,
        collectionEnabled: false,
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.droppedByCollectionDisabled);
      expect(service.events, isEmpty);
    });
  });

  group('AiroProviderBackedAnalyticsService upload gate (F7.3)', () {
    test('defers upload while playback is active -- never contends with media', () async {
      var sent = 0;
      final service = AiroProviderBackedAnalyticsService(
        sender: (event) async => sent++,
        consent: playbackQualityGranted,
        collectionEnabled: true,
        playbackActive: true,
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.deferredByPlayback);
      expect(sent, 0);
    });

    test('uploads once playback is no longer active', () async {
      var sent = 0;
      final service = AiroProviderBackedAnalyticsService(
        sender: (event) async => sent++,
        consent: playbackQualityGranted,
        collectionEnabled: true,
        playbackActive: false,
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
      expect(sent, 1);
    });

    test('a sender failure trips backoff instead of throwing', () async {
      final service = AiroProviderBackedAnalyticsService(
        sender: (event) async => throw Exception('network down'),
        consent: playbackQualityGranted,
        collectionEnabled: true,
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.providerUnavailable);
      expect(service.providerBackoffState.failureCount, 1);
    });

    test('without consent, the sender is never invoked', () async {
      var sent = 0;
      final service = AiroProviderBackedAnalyticsService(
        sender: (event) async => sent++,
        consent: const AiroAnalyticsConsentState.disabled(),
        collectionEnabled: true,
      );

      final result = await service.track(summary().toAnalyticsEvent());

      expect(result.status, AiroAnalyticsTrackStatus.droppedByConsent);
      expect(sent, 0);
    });
  });
}
