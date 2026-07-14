import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo analytics contracts', () {
    AiroAnalyticsEvent event({
      String name = 'playback_started',
      String owner = 'media',
      AiroAnalyticsPurpose purpose = AiroAnalyticsPurpose.product,
      Map<String, Object?> params = const {'source_type': 'iptv'},
      AiroAnalyticsPriority priority = AiroAnalyticsPriority.normal,
    }) {
      return AiroAnalyticsEvent(
        name: name,
        owner: owner,
        purpose: purpose,
        params: params,
        priority: priority,
      );
    }

    AiroCrashReport crashReport({
      Map<String, Object?> context = const {
        'active_screen': 'player',
        'source_url': 'https://example.com/live.m3u8',
        'local_path': '/Users/example/video.ts',
        'local_ip': '192.168.1.10',
        'auth_header': 'Bearer abc.def',
        'media_title': 'Private Match',
        'search_query': 'private channel',
      },
      List<String> stackFrames = const [
        'Player.open(https://example.com/live.m3u8)',
      ],
      List<String> nativeSymbols = const ['libplayer.so!decode_frame'],
    }) {
      return AiroCrashReport(
        reportId: 'crash-1',
        occurredAt: DateTime.utc(2026, 7, 15, 10),
        severity: AiroCrashSeverity.nativeFatal,
        kind: AiroCrashKind.playbackEngine,
        appVersion: '2.0.0.1',
        platform: 'android_tv',
        productProfile: AiroAnalyticsProductProfile.liteReceiver,
        deviceTier: 'constrained_tv',
        activeModule: 'playback',
        memoryPressureBucket: 'high',
        decoderFamily: 'hardware',
        context: context,
        stackFrames: stackFrames,
        nativeSymbols: nativeSymbols,
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

    test('full tv analytics profile allows complete event set', () {
      final profile = AiroTvAnalyticsProductEditionProfiles.fullTv();
      final playbackEvent = event(
        name: 'playback_startup_completed',
        purpose: AiroAnalyticsPurpose.playbackQuality,
      );
      final productEvent = event(
        name: 'subscription_conversion',
        owner: 'growth',
        purpose: AiroAnalyticsPurpose.product,
      );

      expect(profile.validate().accepted, isTrue);
      expect(
        profile.allowedPurposes,
        containsAll(const {
          AiroAnalyticsPurpose.operational,
          AiroAnalyticsPurpose.product,
          AiroAnalyticsPurpose.playbackQuality,
          AiroAnalyticsPurpose.diagnostics,
          AiroAnalyticsPurpose.crash,
          AiroAnalyticsPurpose.personalized,
        }),
      );
      expect(profile.allowsEvent(playbackEvent), isTrue);
      expect(profile.allowsEvent(productEvent), isTrue);
      expect(profile.externalUploadAllowed, isTrue);
    });

    test('lite receiver excludes personalized and uses reduced budgets', () {
      final full = AiroTvAnalyticsProductEditionProfiles.fullTv();
      final lite = AiroTvAnalyticsProductEditionProfiles.liteReceiver();

      expect(lite.validate().accepted, isTrue);
      expect(
        lite.allowedPurposes,
        isNot(contains(AiroAnalyticsPurpose.personalized)),
      );
      expect(lite.maxQueueEvents, lessThan(full.maxQueueEvents));
      expect(lite.maxCrashReports, lessThan(full.maxCrashReports));
      expect(lite.allowsEventName('playback_quality_sample'), isTrue);
      expect(lite.allowsEventName('subscription_conversion'), isFalse);
    });

    test('embedded receiver profile forces local-only configuration', () {
      final embedded = AiroTvAnalyticsProductEditionProfiles.embeddedReceiver();
      final configuration = embedded.toServiceConfiguration(
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
      );

      expect(embedded.validate().accepted, isTrue);
      expect(embedded.localOnly, isTrue);
      expect(configuration.consent.localOnly, isTrue);
      expect(configuration.consent.product, isFalse);
      expect(configuration.consent.playbackQuality, isFalse);
      expect(configuration.externalUploadAllowed, isFalse);
      expect(configuration.validate().accepted, isTrue);
    });

    test('companion profiles omit tv playback quality event families', () {
      final mobile = AiroTvAnalyticsProductEditionProfiles.mobileCompanion();
      final desktop = AiroTvAnalyticsProductEditionProfiles.desktopCompanion();

      expect(mobile.validate().accepted, isTrue);
      expect(desktop.validate().accepted, isTrue);
      expect(mobile.allowsEventName('command_route_latency'), isTrue);
      expect(desktop.allowsEventName('pairing_completed'), isTrue);
      expect(mobile.allowsEventName('playback_startup_completed'), isFalse);
      expect(
        desktop.eventFamilies,
        isNot(contains(AiroAnalyticsEventFamily.playbackQuality)),
      );
    });

    test('profile validation rejects unsafe local-only definitions', () {
      final invalid = AiroAnalyticsProductEditionProfile(
        productProfile: AiroAnalyticsProductProfile.embeddedReceiver,
        displayName: 'Invalid Embedded',
        allowedPurposes: const {
          AiroAnalyticsPurpose.operational,
          AiroAnalyticsPurpose.product,
        },
        eventFamilies: const {
          AiroAnalyticsEventFamily.operationalCore,
          AiroAnalyticsEventFamily.playbackQuality,
        },
        eventNames: const {'subscription_conversion'},
        providerKind: AiroAnalyticsProviderKind.noOp,
        maxQueueEvents: -1,
        maxCrashReports: -1,
        localRetentionDays: -1,
        externalUploadAllowed: true,
        localOnly: true,
      );

      expect(
        invalid.validate().codes,
        containsAll(const {
          AiroAnalyticsProfileValidationCode.unsupportedPurposeAllowed,
          AiroAnalyticsProfileValidationCode.eventFamilyPurposeNotAllowed,
          AiroAnalyticsProfileValidationCode.externalUploadInLocalOnly,
          AiroAnalyticsProfileValidationCode.providerUploadWithoutProvider,
          AiroAnalyticsProfileValidationCode.queueBudgetInvalid,
          AiroAnalyticsProfileValidationCode.crashBudgetInvalid,
          AiroAnalyticsProfileValidationCode.localRetentionInvalid,
        }),
      );
    });

    test(
      'analytics profile public maps expose only stable contract fields',
      () {
        final publicMap = AiroTvAnalyticsProductEditionProfiles.fullTv()
            .toPublicMap();
        final flattened = publicMap.toString();

        expect(flattened, contains('full_tv'));
        expect(flattened, contains('playback_quality'));
        expect(flattened, contains('maxQueueEvents'));
        expect(flattened, isNot(contains('https://')));
        expect(flattened, isNot(contains('/Users/')));
        expect(flattened, isNot(contains('192.168.')));
        expect(flattened, isNot(contains('Bearer')));
        expect(flattened, isNot(contains('City News Live')));
        expect(flattened, isNot(contains('providerPayload')));
      },
    );

    test('standard retention policy validates approved retention windows', () {
      final policy = AiroTvAnalyticsRetentionPolicies.standard();

      expect(policy.validate().accepted, isTrue);
      expect(
        policy
            .ruleFor(AiroAnalyticsRetentionClass.operational30Days)
            ?.rawRetentionDays,
        30,
      );
      expect(
        policy.ruleFor(AiroAnalyticsRetentionClass.product90Days),
        isA<AiroAnalyticsRetentionRule>()
            .having((rule) => rule.rawRetentionDays, 'rawRetentionDays', 90)
            .having(
              (rule) => rule.deleteOnConsentWithdrawal,
              'deleteOnConsentWithdrawal',
              isTrue,
            ),
      );
      expect(
        policy
            .ruleFor(AiroAnalyticsRetentionClass.aggregateOnly)
            ?.rawRetentionDays,
        0,
      );
    });

    test('consent withdrawal deletion plan clears optional analytics', () {
      final policy = AiroTvAnalyticsRetentionPolicies.standard();
      final plan = policy.deletionPlan(
        AiroAnalyticsDeletionReason.consentWithdrawal,
      );

      expect(
        plan.retentionClasses,
        containsAll(const {
          AiroAnalyticsRetentionClass.product90Days,
          AiroAnalyticsRetentionClass.diagnostics30Days,
          AiroAnalyticsRetentionClass.crash90Days,
        }),
      );
      expect(
        plan.retentionClasses,
        isNot(contains(AiroAnalyticsRetentionClass.operational30Days)),
      );
      expect(
        plan.steps,
        containsAll(const {
          AiroAnalyticsDeletionStep.clearLocalQueue,
          AiroAnalyticsDeletionStep.clearLocalCrashDiagnostics,
          AiroAnalyticsDeletionStep.resetAnalyticsIdentity,
          AiroAnalyticsDeletionStep.requestProviderDelete,
          AiroAnalyticsDeletionStep.writeAuditRecord,
        }),
      );
      expect(
        plan.affectedPurposes,
        containsAll(const {
          AiroAnalyticsPurpose.product,
          AiroAnalyticsPurpose.playbackQuality,
          AiroAnalyticsPurpose.diagnostics,
          AiroAnalyticsPurpose.crash,
          AiroAnalyticsPurpose.personalized,
        }),
      );
    });

    test(
      'privacy deletion plan includes export delete tombstone and audit',
      () {
        final policy = AiroTvAnalyticsRetentionPolicies.standard();
        final plan = policy.deletionPlan(
          AiroAnalyticsDeletionReason.accountDeletion,
        );

        expect(
          plan.retentionClasses,
          containsAll(AiroAnalyticsRetentionClass.values),
        );
        expect(
          plan.steps,
          containsAll(const {
            AiroAnalyticsDeletionStep.requestProviderExport,
            AiroAnalyticsDeletionStep.requestProviderDelete,
            AiroAnalyticsDeletionStep.writeAggregateTombstone,
            AiroAnalyticsDeletionStep.writeAuditRecord,
          }),
        );
      },
    );

    test('data access policy enforces least privilege and approval', () {
      final policy = AiroTvAnalyticsRetentionPolicies.standard();

      final productAccess = policy.evaluateAccess(
        const AiroAnalyticsAccessRequest(
          role: AiroAnalyticsAccessRole.productAnalyst,
          purpose: AiroAnalyticsAccessPurpose.productMeasurement,
          retentionClass: AiroAnalyticsRetentionClass.product90Days,
          productionData: true,
          approved: true,
        ),
      );
      final supportCrashAccess = policy.evaluateAccess(
        const AiroAnalyticsAccessRequest(
          role: AiroAnalyticsAccessRole.support,
          purpose: AiroAnalyticsAccessPurpose.supportTroubleshooting,
          retentionClass: AiroAnalyticsRetentionClass.crash90Days,
          productionData: true,
        ),
      );
      final productCrashAccess = policy.evaluateAccess(
        const AiroAnalyticsAccessRequest(
          role: AiroAnalyticsAccessRole.productAnalyst,
          purpose: AiroAnalyticsAccessPurpose.productMeasurement,
          retentionClass: AiroAnalyticsRetentionClass.crash90Days,
        ),
      );

      expect(productAccess.accepted, isTrue);
      expect(
        supportCrashAccess.codes,
        containsAll(const {
          AiroAnalyticsAccessDecisionCode.roleNotAllowed,
          AiroAnalyticsAccessDecisionCode.purposeNotAllowed,
          AiroAnalyticsAccessDecisionCode.approvalRequired,
          AiroAnalyticsAccessDecisionCode.productionAccessBlocked,
        }),
      );
      expect(
        productCrashAccess.codes,
        containsAll(const {
          AiroAnalyticsAccessDecisionCode.roleNotAllowed,
          AiroAnalyticsAccessDecisionCode.purposeNotAllowed,
        }),
      );
    });

    test('invalid retention policy returns deterministic codes', () {
      final invalid = AiroAnalyticsRetentionPolicy(
        rules: [
          AiroAnalyticsRetentionRule(
            retentionClass: AiroAnalyticsRetentionClass.operational30Days,
            rawRetentionDays: 7,
            deleteOnConsentWithdrawal: false,
            exportable: true,
            allowedRoles: const {},
            allowedPurposes: const {},
          ),
          AiroAnalyticsRetentionRule(
            retentionClass: AiroAnalyticsRetentionClass.aggregateOnly,
            rawRetentionDays: 30,
            deleteOnConsentWithdrawal: false,
            exportable: false,
            allowedRoles: const {AiroAnalyticsAccessRole.privacyOfficer},
            allowedPurposes: const {AiroAnalyticsAccessPurpose.privacyRequest},
          ),
        ],
      );

      expect(
        invalid.validate().codes,
        containsAll(const {
          AiroAnalyticsRetentionPolicyCode.retentionDaysMismatch,
          AiroAnalyticsRetentionPolicyCode.aggregateHasRawRetention,
          AiroAnalyticsRetentionPolicyCode.retentionClassMissing,
          AiroAnalyticsRetentionPolicyCode.accessRoleMissing,
          AiroAnalyticsRetentionPolicyCode.accessPurposeMissing,
        }),
      );
    });

    test('retention and access public maps exclude raw analytics data', () {
      final policy = AiroTvAnalyticsRetentionPolicies.standard();
      final access = policy.evaluateAccess(
        const AiroAnalyticsAccessRequest(
          role: AiroAnalyticsAccessRole.privacyOfficer,
          purpose: AiroAnalyticsAccessPurpose.privacyRequest,
          retentionClass: AiroAnalyticsRetentionClass.diagnostics30Days,
          productionData: true,
          approved: true,
        ),
      );
      final plan = policy.deletionPlan(
        AiroAnalyticsDeletionReason.privacyRequest,
      );
      final flattened =
          '${policy.toPublicMap()} ${access.toPublicMap()} ${plan.toPublicMap()}';

      expect(flattened, contains('diagnostics_30_days'));
      expect(flattened, contains('privacy_officer'));
      expect(flattened, contains('request_provider_delete'));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('Bearer')));
      expect(flattened, isNot(contains('City News Live')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('diagnosticDump')));
    });

    test('standard dashboard catalog covers required surfaces', () {
      final catalog = AiroTvAnalyticsDashboardCatalogs.standard();
      final surfaces = catalog.metrics.map((metric) => metric.surface).toSet();

      expect(catalog.validate().accepted, isTrue);
      expect(surfaces, containsAll(AiroAnalyticsDashboardSurface.values));
      expect(
        catalog.metrics.map((metric) => metric.metricId),
        containsAll(const {
          'weekly_active_receivers',
          'playback_startup_p95_bucket',
          'legacy_decoder_fallback_rate',
          'pairing_success_rate',
          'subscription_conversion_rate',
          'crash_rate_by_profile',
        }),
      );
    });

    test('standard operational alerts reference known metrics', () {
      final catalog = AiroTvAnalyticsDashboardCatalogs.standard();
      final metricIds = catalog.metrics
          .map((metric) => metric.metricId)
          .toSet();

      for (final alert in catalog.alerts) {
        expect(metricIds, contains(alert.metricId), reason: alert.alertId);
        expect(alert.threshold.isFinite, isTrue, reason: alert.alertId);
        expect(alert.evaluationWindowMinutes, greaterThan(0));
        expect(alert.runbookId, startsWith('runbook_'));
      }
      expect(
        catalog.alerts.map((alert) => alert.alertId),
        containsAll(const {
          'playback_startup_regression',
          'crash_spike_by_profile',
          'legacy_decoder_fallback_spike',
          'pairing_success_regression',
          'provider_outage_regression',
          'privacy_deletion_latency_breach',
        }),
      );
    });

    test('invalid dashboard catalog returns deterministic codes', () {
      final invalid = AiroAnalyticsDashboardCatalog(
        metrics: const [
          AiroAnalyticsDashboardMetricSpec(
            metricId: 'bad metric',
            owner: '',
            purpose: AiroAnalyticsPurpose.product,
            retentionClass: AiroAnalyticsRetentionClass.product90Days,
            surface: AiroAnalyticsDashboardSurface.executive,
            dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          ),
          AiroAnalyticsDashboardMetricSpec(
            metricId: 'bad metric',
            owner: 'product',
            purpose: AiroAnalyticsPurpose.product,
            retentionClass: AiroAnalyticsRetentionClass.product90Days,
            surface: AiroAnalyticsDashboardSurface.executive,
            dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          ),
        ],
        alerts: const [
          AiroAnalyticsOperationalAlertRule(
            alertId: 'broken_alert',
            metricId: 'missing_metric',
            severity: AiroAnalyticsAlertSeverity.critical,
            comparison: AiroAnalyticsAlertComparison.greaterThan,
            threshold: -1,
            evaluationWindowMinutes: 0,
            runbookId: '',
          ),
        ],
      );

      expect(
        invalid.validate().codes,
        containsAll(const {
          AiroAnalyticsDashboardCatalogCode.duplicateMetric,
          AiroAnalyticsDashboardCatalogCode.metricIdInvalid,
          AiroAnalyticsDashboardCatalogCode.metricOwnerMissing,
          AiroAnalyticsDashboardCatalogCode.requiredSurfaceMissing,
          AiroAnalyticsDashboardCatalogCode.alertMetricMissing,
          AiroAnalyticsDashboardCatalogCode.alertThresholdInvalid,
          AiroAnalyticsDashboardCatalogCode.alertWindowInvalid,
          AiroAnalyticsDashboardCatalogCode.alertRunbookMissing,
        }),
      );
    });

    test('dashboard catalog public maps expose stable metadata only', () {
      final flattened = AiroTvAnalyticsDashboardCatalogs.standard()
          .toPublicMap()
          .toString();

      expect(flattened, contains('playback_startup_regression'));
      expect(flattened, contains('crash_spike_by_profile'));
      expect(flattened, contains('runbook_privacy_deletion_latency'));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('Bearer')));
      expect(flattened, isNot(contains('City News Live')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('diagnosticDump')));
    });

    test('self hosted gateway accepts registered safe event', () {
      final gateway = AiroTvAnalyticsSelfHostedGateways.standard();
      final decision = gateway.evaluate(
        event: AiroAnalyticsEvent(
          name: 'playback_startup_completed',
          owner: 'media',
          purpose: AiroAnalyticsPurpose.playbackQuality,
          params: const {'source_type': 'iptv', 'startup_bucket': '1_3s'},
        ),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
        region: AiroAnalyticsGatewayRegion.us,
        rateLimitState: AiroAnalyticsGatewayRateLimitState(
          windowStartedAt: DateTime.utc(2026, 7, 15, 10),
          eventCount: 1,
        ),
      );

      expect(decision.accepted, isTrue);
      expect(
        decision.retentionClass,
        AiroAnalyticsRetentionClass.product90Days,
      );
      expect(decision.schemaCodes, const [
        AiroAnalyticsSchemaValidationCode.accepted,
      ]);
    });

    test('self hosted gateway rejects unknown schema and unsafe payload', () {
      final gateway = AiroTvAnalyticsSelfHostedGateways.standard();
      final unknown = gateway.evaluate(
        event: event(name: 'unknown_event'),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
        region: AiroAnalyticsGatewayRegion.us,
        rateLimitState: AiroAnalyticsGatewayRateLimitState(
          windowStartedAt: DateTime.utc(2026, 7, 15, 10),
          eventCount: 1,
        ),
      );
      final unsafe = gateway.evaluate(
        event: AiroAnalyticsEvent(
          name: 'playback_startup_completed',
          owner: 'media',
          purpose: AiroAnalyticsPurpose.playbackQuality,
          params: const {
            'source_type': 'https://example.com/live.m3u8',
            'startup_bucket': '1_3s',
          },
        ),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
        region: AiroAnalyticsGatewayRegion.us,
        rateLimitState: AiroAnalyticsGatewayRateLimitState(
          windowStartedAt: DateTime.utc(2026, 7, 15, 10),
          eventCount: 1,
        ),
      );

      expect(
        unknown.codes,
        contains(AiroAnalyticsGatewayDecisionCode.schemaRejected),
      );
      expect(
        unsafe.codes,
        containsAll(const {
          AiroAnalyticsGatewayDecisionCode.schemaRejected,
          AiroAnalyticsGatewayDecisionCode.privacyRejected,
        }),
      );
    });

    test('self hosted gateway enforces local-only region and rate limits', () {
      final gateway = AiroTvAnalyticsSelfHostedGateways.standard();
      final decision = gateway.evaluate(
        event: AiroAnalyticsEvent(
          name: 'device_discovery_summary',
          owner: 'device_ecosystem',
          purpose: AiroAnalyticsPurpose.operational,
          params: const {
            'source_profile': 'full_tv',
            'discovery_method': 'mdns',
            'availability_category': 'companion_available',
            'device_count_bucket': '1_3',
          },
        ),
        consent: const AiroAnalyticsConsentState.localOnly(),
        collectionEnabled: false,
        region: AiroAnalyticsGatewayRegion.localOnly,
        rateLimitState: AiroAnalyticsGatewayRateLimitState(
          windowStartedAt: DateTime.utc(2026, 7, 15, 10),
          eventCount: 120,
        ),
      );

      expect(
        decision.codes,
        containsAll(const {
          AiroAnalyticsGatewayDecisionCode.collectionDisabled,
          AiroAnalyticsGatewayDecisionCode.localOnlyUploadBlocked,
          AiroAnalyticsGatewayDecisionCode.regionNotAllowed,
          AiroAnalyticsGatewayDecisionCode.rateLimited,
        }),
      );
    });

    test('self hosted gateway requires retention and deletion support', () {
      final gateway = AiroAnalyticsSelfHostedGatewayPolicy(
        gatewayId: 'bad_gateway',
        schemaRegistry: AiroTvAnalyticsSchemas.registry(),
        retentionPolicy: AiroTvAnalyticsRetentionPolicies.standard(),
        providerKind: AiroAnalyticsProviderKind.vendorAdapter,
        supportsRetentionPolicy: false,
        supportsDeletionRequests: false,
      );
      final decision = gateway.evaluate(
        event: AiroAnalyticsEvent(
          name: 'subscription_conversion',
          owner: 'growth',
          purpose: AiroAnalyticsPurpose.product,
          params: const {
            'entry_surface': 'settings',
            'plan_bucket': 'annual',
            'success': true,
          },
        ),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
        region: AiroAnalyticsGatewayRegion.eu,
        rateLimitState: AiroAnalyticsGatewayRateLimitState(
          windowStartedAt: DateTime.utc(2026, 7, 15, 10),
          eventCount: 1,
        ),
      );

      expect(
        decision.codes,
        containsAll(const {
          AiroAnalyticsGatewayDecisionCode.providerKindInvalid,
          AiroAnalyticsGatewayDecisionCode.retentionUnsupported,
          AiroAnalyticsGatewayDecisionCode.deletionUnsupported,
        }),
      );
    });

    test('self hosted gateway public maps omit endpoints and credentials', () {
      final gateway = AiroTvAnalyticsSelfHostedGateways.standard();
      final decision = gateway.evaluate(
        event: AiroAnalyticsEvent(
          name: 'pairing_completed',
          owner: 'device_ecosystem',
          purpose: AiroAnalyticsPurpose.operational,
          params: const {
            'source_profile': 'mobile_companion',
            'target_profile': 'lite_receiver',
            'result_category': 'success',
          },
        ),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
        region: AiroAnalyticsGatewayRegion.india,
        rateLimitState: AiroAnalyticsGatewayRateLimitState(
          windowStartedAt: DateTime.utc(2026, 7, 15, 10),
          eventCount: 2,
        ),
      );
      final flattened = '${gateway.toPublicMap()} ${decision.toPublicMap()}';

      expect(flattened, contains('airo_tv_self_hosted_gateway'));
      expect(flattened, contains('india'));
      expect(flattened, contains('registeredSchemaCount'));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('Bearer')));
      expect(flattened, isNot(contains('apiKey')));
      expect(flattened, isNot(contains('City News Live')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('diagnosticDump')));
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

    test('standard privacy fixture suite matches expected outcomes', () {
      final suite = AiroTvAnalyticsPrivacyFilterSuites.standard();
      final filter = AiroAnalyticsPrivacyFilter.standard;

      for (final testCase in suite.cases) {
        final result = filter.validate(testCase.toEvent());
        if (testCase.shouldReject) {
          expect(
            result.violations.map((violation) => violation.code),
            contains(testCase.expectedCode),
            reason: testCase.caseId,
          );
        } else {
          expect(result.isAccepted, isTrue, reason: testCase.caseId);
        }
      }
    });

    test('privacy fixture suite public map excludes risky sample values', () {
      final publicMap = AiroTvAnalyticsPrivacyFilterSuites.standard()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(flattened, contains('stream-url-value'));
      expect(flattened, contains(AiroAnalyticsPrivacyCode.urlValue.stableId));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('rtsp://')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('Bearer')));
      expect(flattened, isNot(contains('City News Live')));
      expect(flattened, isNot(contains('latest live match')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
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
      expect(first.queueResult?.code, AiroAnalyticsQueueOfferCode.accepted);
      expect(second.queueResult?.code, AiroAnalyticsQueueOfferCode.queueFull);
      expect(service.events.map((event) => event.name), ['first_event']);

      await service.reset();
      expect(service.events, isEmpty);
    });

    test(
      'bounded queue evicts lower priority events deterministically',
      () async {
        final service = AiroLocalDiagnosticsAnalyticsService(
          consent: const AiroAnalyticsConsentState.allEnabled(),
          maxEvents: 1,
        );

        await service.track(
          event(name: 'low_event', priority: AiroAnalyticsPriority.low),
        );
        final result = await service.track(
          event(
            name: 'critical_event',
            priority: AiroAnalyticsPriority.critical,
          ),
        );

        expect(result.status, AiroAnalyticsTrackStatus.accepted);
        expect(
          result.queueResult?.code,
          AiroAnalyticsQueueOfferCode.evictedLowerPriority,
        );
        expect(result.queueResult?.evictedEvent?.name, 'low_event');
        expect(service.events.map((event) => event.name), ['critical_event']);
      },
    );

    test('queue snapshot public map excludes event params', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      await service.track(
        event(
          name: 'product_event',
          params: const {'source_type': 'subscription_screen'},
        ),
      );
      final flattened = service.queueSnapshot.toPublicMap().toString();

      expect(flattened, contains('product_event'));
      expect(flattened, contains('priorityCounts'));
      expect(flattened, isNot(contains('source_type')));
      expect(flattened, isNot(contains('subscription_screen')));
      expect(flattened, isNot(contains('providerPayload')));
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
      final transition = await service.updateConsent(
        const AiroAnalyticsConsentState.localOnly(),
      );

      expect(service.events.map((event) => event.name), ['diagnostic_event']);
      expect(
        transition.codes,
        containsAll(const {
          AiroAnalyticsConsentTransitionCode.optionalQueueCleared,
          AiroAnalyticsConsentTransitionCode.localOnlyExternalUploadBlocked,
        }),
      );
      expect(transition.removedEventCount, 1);
      expect(transition.previousConsent.product, isTrue);
      expect(transition.nextConsent.localOnly, isTrue);
    });

    test('consent transition public map excludes event payloads', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      await service.track(
        event(
          name: 'product_event',
          params: const {'source_type': 'subscription_screen'},
        ),
      );
      final transition = await service.updateConsent(
        const AiroAnalyticsConsentState.localOnly(),
      );
      final flattened = transition.toPublicMap().toString();

      expect(flattened, contains('optional_queue_cleared'));
      expect(flattened, contains('removedEventCount: 1'));
      expect(flattened, contains('localOnly: true'));
      expect(flattened, isNot(contains('product_event')));
      expect(flattened, isNot(contains('subscription_screen')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
    });

    test(
      'collection disabled clears local diagnostics and drops future events',
      () async {
        final service = AiroLocalDiagnosticsAnalyticsService(
          consent: const AiroAnalyticsConsentState.allEnabled(),
        );

        await service.track(event(name: 'product_event'));
        await service.setCollectionEnabled(false);
        final result = await service.track(event(name: 'second_event'));
        final transition = await service.updateConsent(
          const AiroAnalyticsConsentState.disabled(),
        );

        expect(service.events, isEmpty);
        expect(
          result.status,
          AiroAnalyticsTrackStatus.droppedByCollectionDisabled,
        );
        expect(
          transition.codes,
          contains(AiroAnalyticsConsentTransitionCode.collectionDisabled),
        );
      },
    );

    test('analytics reset clears queue and advances generation', () async {
      final service = AiroLocalDiagnosticsAnalyticsService(
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );

      await service.track(event(name: 'product_event'));
      await service.reset();
      final transition = await service.updateConsent(
        const AiroAnalyticsConsentState.localOnly(),
      );

      expect(service.events, isEmpty);
      expect(service.resetGeneration, 1);
      expect(
        transition.codes,
        contains(AiroAnalyticsConsentTransitionCode.analyticsIdentityReset),
      );
      expect(transition.resetGeneration, 1);
    });

    test('provider backed service applies local-only before upload', () async {
      final sentEvents = <AiroAnalyticsEvent>[];
      final service = AiroProviderBackedAnalyticsService(
        sender: (event) async => sentEvents.add(event),
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
      );

      final transition = await service.updateConsent(
        const AiroAnalyticsConsentState.localOnly(),
      );
      final productResult = await service.track(event());
      final diagnosticResult = await service.track(
        event(
          name: 'diagnostic_event',
          purpose: AiroAnalyticsPurpose.diagnostics,
        ),
      );

      expect(
        transition.codes,
        contains(
          AiroAnalyticsConsentTransitionCode.localOnlyExternalUploadBlocked,
        ),
      );
      expect(productResult.status, AiroAnalyticsTrackStatus.droppedByLocalOnly);
      expect(diagnosticResult.status, AiroAnalyticsTrackStatus.accepted);
      expect(sentEvents.map((event) => event.name), ['diagnostic_event']);
    });

    test('provider backed service catches provider failures', () async {
      final startedAt = DateTime.utc(2026, 7, 15, 10);
      var attempts = 0;
      final service = AiroProviderBackedAnalyticsService(
        sender: (_) async {
          attempts += 1;
          throw StateError('offline');
        },
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: true,
        clock: () => startedAt,
      );

      final result = await service.track(event());
      final blocked = await service.track(event(name: 'second_event'));

      expect(result.status, AiroAnalyticsTrackStatus.providerUnavailable);
      expect(service.providerBackoffState.failureCount, 1);
      expect(
        result.uploadDecision?.code,
        AiroAnalyticsUploadDecisionCode.providerBackoffActive,
      );
      expect(blocked.status, AiroAnalyticsTrackStatus.providerBackoffActive);
      expect(attempts, 1);
    });

    test(
      'provider upload gate defers non-critical events during playback',
      () async {
        final sentEvents = <AiroAnalyticsEvent>[];
        final service = AiroProviderBackedAnalyticsService(
          sender: (event) async => sentEvents.add(event),
          consent: const AiroAnalyticsConsentState.allEnabled(),
          collectionEnabled: true,
          playbackActive: true,
          clock: () => DateTime.utc(2026, 7, 15, 10),
        );

        final normal = await service.track(event(name: 'normal_event'));
        final critical = await service.track(
          event(
            name: 'critical_event',
            priority: AiroAnalyticsPriority.critical,
          ),
        );

        expect(normal.status, AiroAnalyticsTrackStatus.deferredByPlayback);
        expect(
          normal.uploadDecision?.code,
          AiroAnalyticsUploadDecisionCode.deferredDuringPlayback,
        );
        expect(critical.status, AiroAnalyticsTrackStatus.accepted);
        expect(sentEvents.map((event) => event.name), ['critical_event']);
      },
    );

    test('crash redaction removes unsafe context and stack details', () {
      final result = AiroCrashRedactionPolicy.standard.redact(crashReport());
      final flattened = result.toPublicMap().toString();

      expect(
        result.codes,
        containsAll(const {
          AiroCrashRedactionCode.urlValue,
          AiroCrashRedactionCode.localPathValue,
          AiroCrashRedactionCode.localIpValue,
          AiroCrashRedactionCode.credentialLikeValue,
          AiroCrashRedactionCode.prohibitedFieldName,
          AiroCrashRedactionCode.stackFrameRedacted,
          AiroCrashRedactionCode.nativeSymbolRedacted,
        }),
      );
      expect(result.redactedStackFrameCount, 1);
      expect(result.redactedNativeSymbolCount, 1);
      expect(flattened, contains('crash-1'));
      expect(flattened, contains('native_fatal'));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('Bearer')));
      expect(flattened, isNot(contains('Private Match')));
      expect(flattened, isNot(contains('private channel')));
      expect(flattened, isNot(contains('libplayer.so')));
    });

    test('local crash reporter stores only redacted diagnostics', () async {
      final service = AiroLocalDiagnosticsCrashReportingService(
        consent: const AiroAnalyticsConsentState.localOnly(),
      );

      final result = await service.report(crashReport());
      final flattened = service.reports.single.toPublicMap().toString();

      expect(result.status, AiroCrashReportStatus.storedLocalOnly);
      expect(service.reports, hasLength(1));
      expect(flattened, isNot(contains('stored_local_only')));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('Private Match')));
    });

    test(
      'provider crash reporter respects consent and catches failures',
      () async {
        var attempts = 0;
        final localOnly = AiroProviderBackedCrashReportingService(
          sender: (_) async => attempts += 1,
          consent: const AiroAnalyticsConsentState.localOnly(),
          collectionEnabled: true,
        );
        final failing = AiroProviderBackedCrashReportingService(
          sender: (_) async {
            attempts += 1;
            throw StateError('offline');
          },
          consent: const AiroAnalyticsConsentState.allEnabled(),
          collectionEnabled: true,
        );

        final blocked = await localOnly.report(crashReport());
        final failed = await failing.report(crashReport());

        expect(blocked.status, AiroCrashReportStatus.uploadBlockedLocalOnly);
        expect(failed.status, AiroCrashReportStatus.providerUnavailable);
        expect(attempts, 1);
        expect(failed.toPublicMap().toString(), isNot(contains('https://')));
      },
    );

    test('disabled crash collection drops before provider upload', () async {
      var attempts = 0;
      final service = AiroProviderBackedCrashReportingService(
        sender: (_) async => attempts += 1,
        consent: const AiroAnalyticsConsentState.allEnabled(),
        collectionEnabled: false,
      );

      final result = await service.report(crashReport());

      expect(result.status, AiroCrashReportStatus.droppedByCollectionDisabled);
      expect(attempts, 0);
    });

    test('provider upload decision public map exposes stable state only', () {
      final now = DateTime.utc(2026, 7, 15, 10);
      final decision = AiroAnalyticsUploadGate.evaluate(
        event: event(
          name: 'product_event',
          params: const {'source_type': 'subscription_screen'},
        ),
        playbackActive: true,
        providerBackoffState:
            const AiroAnalyticsProviderBackoffState.inactive(),
        now: now,
      );
      final flattened = decision.toPublicMap().toString();

      expect(flattened, contains('deferred_during_playback'));
      expect(flattened, contains('playbackActive: true'));
      expect(flattened, isNot(contains('product_event')));
      expect(flattened, isNot(contains('subscription_screen')));
      expect(flattened, isNot(contains('providerPayload')));
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

    test('playback quality telemetry fixture suite validates outcomes', () {
      final registry = AiroTvAnalyticsSchemas.registry();
      final suite = AiroTvPlaybackQualityTelemetrySuites.standard();

      for (final testCase in suite.cases) {
        final result = registry.validateEvent(testCase.event);
        if (testCase.shouldPass) {
          expect(result.accepted, isTrue, reason: testCase.caseId);
        } else {
          expect(result.accepted, isFalse, reason: testCase.caseId);
          expect(
            result.codes,
            containsAll(testCase.expectedCodes),
            reason: testCase.caseId,
          );
        }
      }
    });

    test('playback quality schemas require bucketed safe fields', () {
      final registry = AiroTvAnalyticsSchemas.registry();

      expect(registry.schemaFor('playback_buffering_summary'), isNotNull);
      expect(registry.schemaFor('playback_failover_completed'), isNotNull);
      expect(registry.schemaFor('playback_quality_sample'), isNotNull);
      expect(registry.schemaFor('playback_completion_summary'), isNotNull);
      expect(
        registry.schemaFor('playback_quality_sample')!.allowedFieldNames,
        containsAll({'bitrate_bucket', 'resolution_bucket'}),
      );
      expect(
        registry.schemaFor('playback_completion_summary')!.allowedFieldNames,
        isNot(contains('mediaTitle')),
      );
    });

    test('device ecosystem telemetry fixture suite validates outcomes', () {
      final registry = AiroTvAnalyticsSchemas.registry();
      final suite = AiroTvDeviceEcosystemTelemetrySuites.standard();

      for (final testCase in suite.cases) {
        final result = registry.validateEvent(testCase.event);
        if (testCase.shouldPass) {
          expect(result.accepted, isTrue, reason: testCase.caseId);
        } else {
          expect(result.accepted, isFalse, reason: testCase.caseId);
          expect(
            result.codes,
            containsAll(testCase.expectedCodes),
            reason: testCase.caseId,
          );
        }
      }
    });

    test('device ecosystem schemas use safe categories and buckets', () {
      final registry = AiroTvAnalyticsSchemas.registry();

      expect(registry.schemaFor('device_discovery_summary'), isNotNull);
      expect(registry.schemaFor('command_route_latency'), isNotNull);
      expect(registry.schemaFor('delegation_task_completed'), isNotNull);
      expect(registry.schemaFor('companion_availability_summary'), isNotNull);
      expect(
        registry.schemaFor('command_route_latency')!.allowedFieldNames,
        containsAll({'command_category', 'latency_bucket'}),
      );
      expect(
        registry.schemaFor('device_discovery_summary')!.allowedFieldNames,
        isNot(contains('localIp')),
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
      expect(flattened, contains('playback_buffering_summary'));
      expect(flattened, contains('playback_quality_sample'));
      expect(flattened, contains('playback_completion_summary'));
      expect(flattened, contains('device_discovery_summary'));
      expect(flattened, contains('command_route_latency'));
      expect(flattened, contains('delegation_task_completed'));
      expect(flattened, contains('companion_availability_summary'));
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

    test('playback telemetry fixture public map excludes raw values', () {
      final publicMap = AiroTvPlaybackQualityTelemetrySuites.standard()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(flattened, contains('playback_quality_sample'));
      expect(flattened, contains('bitrate_bucket'));
      expect(flattened, contains('field_kind_mismatch'));
      expect(flattened, isNot(contains('4500000')));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('live.m3u8')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
    });

    test('device ecosystem fixture public map excludes raw values', () {
      final publicMap = AiroTvDeviceEcosystemTelemetrySuites.standard()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(flattened, contains('device_discovery_summary'));
      expect(flattened, contains('command_route_latency'));
      expect(flattened, contains('field_kind_mismatch'));
      expect(flattened, contains('privacy_violation'));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('find private playlist')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('mobile_companion')));
    });
  });
}
