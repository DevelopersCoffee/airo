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

    test('validates service configuration for provider isolation', () {
      final configuration = AiroAnalyticsServiceConfiguration(
        providerKind: AiroAnalyticsProviderKind.vendorAdapter,
        productProfile: AiroAnalyticsProductProfile.fullTv,
        consent: const AiroAnalyticsConsentState.localOnly(),
        collectionEnabled: true,
        maxQueueEvents: -1,
        externalUploadAllowed: true,
        providerSdkIsolated: false,
        nonBlocking: false,
        resettableInstallationId: false,
      );

      final result = configuration.validate();

      expect(
        result.codes,
        containsAll(const {
          AiroAnalyticsConfigurationCode.queueBudgetInvalid,
          AiroAnalyticsConfigurationCode.externalUploadInLocalOnly,
          AiroAnalyticsConfigurationCode.vendorSdkNotIsolated,
          AiroAnalyticsConfigurationCode.playbackMayBlock,
          AiroAnalyticsConfigurationCode.resettableInstallIdMissing,
        }),
      );
      expect(configuration.toPublicMap()['providerKind'], 'vendor_adapter');
      expect(
        configuration.toPublicMap().toString(),
        isNot(contains('storeConsoleAccount')),
      );
    });

    test(
      'initialize returns disabled and invalid configuration states',
      () async {
        const service = AiroNoOpAnalyticsService();

        final disabled = await service.initialize(
          const AiroAnalyticsServiceConfiguration(
            providerKind: AiroAnalyticsProviderKind.noOp,
            productProfile: AiroAnalyticsProductProfile.liteReceiver,
          ),
        );
        final invalid = await service.initialize(
          const AiroAnalyticsServiceConfiguration(
            providerKind: AiroAnalyticsProviderKind.vendorAdapter,
            productProfile: AiroAnalyticsProductProfile.fullTv,
            collectionEnabled: true,
            providerSdkIsolated: false,
          ),
        );

        expect(disabled.code, AiroAnalyticsLifecycleCode.disabled);
        expect(invalid.code, AiroAnalyticsLifecycleCode.invalidConfiguration);
        expect(
          invalid.toPublicMap().toString(),
          contains(
            AiroAnalyticsConfigurationCode.vendorSdkNotIsolated.stableId,
          ),
        );
      },
    );

    test('drops events when collection is disabled', () {
      final result = validateEvent(
        event(),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: false,
      );

      expect(
        result.status,
        AiroAnalyticsTrackStatus.droppedByCollectionDisabled,
      );
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

    test('consent withdrawal deletes optional queued events', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      await service.track(event(name: 'product_event'));
      await service.track(
        event(
          name: 'diagnostic_event',
          purpose: AiroAnalyticsPurpose.diagnostics,
        ),
      );
      await service.updateConsent(const AiroAnalyticsConsentState.localOnly());

      expect(service.events.map((event) => event.name), ['diagnostic_event']);
    });

    test('provider backed service catches provider failures', () async {
      final service = AiroProviderBackedAnalyticsService(
        sender: (_) async => throw StateError('offline'),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
      );

      final result = await service.track(event());

      expect(result.status, AiroAnalyticsTrackStatus.providerUnavailable);
    });

    test('timed events emit duration buckets without raw values', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );
      final startedAt = DateTime.utc(2026, 7, 15, 10);
      final handle = service.startTimedEvent(
        eventName: 'playback_startup_completed',
        owner: 'media',
        purpose: AiroAnalyticsPurpose.playbackQuality,
        startedAt: startedAt,
        params: const {'source_type': 'iptv'},
      );

      final result = await service.endTimedEvent(
        handle: handle,
        endedAt: startedAt.add(const Duration(milliseconds: 2500)),
      );

      expect(result.status, AiroAnalyticsTrackStatus.accepted);
      expect(service.events.single.params['duration_bucket'], '1_3s');
      expect(service.events.single.params.toString(), isNot(contains('2500')));
    });
  });
}
