import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo analytics contracts', () {
    AiroAnalyticsEvent event({
      String name = 'playback_started',
      String owner = 'media',
      AiroAnalyticsPurpose purpose = AiroAnalyticsPurpose.product,
      Map<String, Object?> params = const {'source_type': 'iptv'},
    }) {
      return AiroAnalyticsEvent(
        name: name,
        owner: owner,
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

    test('schema registry accepts registered event envelope', () {
      final registry = AiroTvAnalyticsSchemas.registry();
      final result = registry.validateEvent(
        event(
          name: 'playback_startup_completed',
          purpose: AiroAnalyticsPurpose.playbackQuality,
          params: const {
            'source_type': 'iptv',
            'startup_bucket': '1_3s',
            'decoder_type': 'hardware',
          },
        ),
      );

      expect(registry.validateRegistry().accepted, isTrue);
      expect(result.accepted, isTrue);
      expect(
        registry.schemaFor('playback_startup_completed')?.retentionClass,
        AiroAnalyticsRetentionClass.product90Days,
      );
    });

    test('schema registry rejects unknown and mismatched events', () {
      final registry = AiroTvAnalyticsSchemas.registry();

      expect(
        registry.validateEvent(event(name: 'unknown_event')).codes,
        contains(AiroAnalyticsSchemaValidationCode.schemaMissing),
      );
      expect(
        registry
            .validateEvent(
              event(
                name: 'pairing_completed',
                purpose: AiroAnalyticsPurpose.product,
                params: const {
                  'source_profile': 'mobile_companion',
                  'target_profile': 'lite_receiver',
                },
              ),
            )
            .codes,
        contains(AiroAnalyticsSchemaValidationCode.purposeMismatch),
      );
    });

    test('schema registry enforces required and allowed fields', () {
      final registry = AiroTvAnalyticsSchemas.registry();
      final result = registry.validateEvent(
        event(
          name: 'subscription_conversion',
          owner: 'growth',
          params: const {
            'entry_surface': 'settings',
            'plan_bucket': 'annual',
            'success': 'true',
            'unexpected_field': 'value',
          },
        ),
      );

      expect(
        result.codes,
        contains(AiroAnalyticsSchemaValidationCode.fieldKindMismatch),
      );
      expect(
        result.codes,
        contains(AiroAnalyticsSchemaValidationCode.fieldNotAllowed),
      );
    });

    test('schema registry preserves privacy filter violations', () {
      final registry = AiroTvAnalyticsSchemas.registry();
      final result = registry.validateEvent(
        event(
          name: 'playback_startup_completed',
          purpose: AiroAnalyticsPurpose.playbackQuality,
          params: const {
            'source_type': 'https://example.com/live.m3u8',
            'startup_bucket': '1_3s',
          },
        ),
      );

      expect(
        result.codes,
        contains(AiroAnalyticsSchemaValidationCode.privacyViolation),
      );
      expect(
        result.privacyViolations.map((violation) => violation.code),
        contains(AiroAnalyticsPrivacyCode.urlValue),
      );
    });

    test('schema registry rejects duplicate and unsafe schemas', () {
      final registry = AiroAnalyticsSchemaRegistry(
        schemas: [
          AiroTvAnalyticsSchemas.playbackStartupCompleted(),
          AiroAnalyticsEventSchema(
            name: 'playback_startup_completed',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            retentionClass: AiroAnalyticsRetentionClass.product90Days,
            dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
            testsRequired: false,
            allowedFields: const [
              AiroAnalyticsFieldSchema(
                name: 'channel',
                kind: AiroAnalyticsFieldKind.category,
              ),
            ],
          ),
        ],
      );

      final result = registry.validateRegistry();

      expect(
        result.codes,
        contains(AiroAnalyticsSchemaValidationCode.duplicateSchema),
      );
      expect(
        result.codes,
        contains(AiroAnalyticsSchemaValidationCode.prohibitedFieldAllowed),
      );
      expect(
        result.codes,
        contains(AiroAnalyticsSchemaValidationCode.testCoverageMissing),
      );
    });

    test('schema registry public map exposes stable metadata only', () {
      final publicMap = AiroTvAnalyticsSchemas.registry().toPublicMap();
      final flattened = publicMap.toString();

      expect(flattened, contains('playback_startup_completed'));
      expect(flattened, contains(AiroAnalyticsFieldKind.bucket.stableId));
      expect(
        flattened,
        contains(AiroAnalyticsDashboardRequirement.required.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
      expect(flattened, isNot(contains('http://')));
      expect(flattened, isNot(contains('192.168.')));
    });
  });
}
