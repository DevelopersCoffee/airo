import 'package:flutter_test/flutter_test.dart';
import 'package:product_capabilities/product_capabilities.dart';

void main() {
  group('Airo TV product profile contracts', () {
    test('full TV manifest exposes stable schema and profile identifiers', () {
      final profile = AiroTvProductProfiles.fullTv();

      expect(profile.schemaVersion, kProductCapabilitiesSchemaVersion);
      expect(profile.profileId.stableId, 'full_tv');
      expect(profile.releaseChannel, ProductReleaseChannel.fullTvStable);
      expect(
        profile.guarantees,
        contains(ProductProfileGuarantee.profileScopedNavigation),
      );
      expect(profile.supportsCapability(ProductCapability.fullEpg), isTrue);
      expect(profile.navigation, contains(ProductNavigationEntry.guide));
      expect(profile.validate().accepted, isTrue);
    });

    test('lite receiver excludes heavy profile modules and capabilities', () {
      final profile = AiroTvProductProfiles.liteReceiver();

      expect(profile.profileId, ProductProfileId.liteReceiver);
      expect(profile.releaseChannel, ProductReleaseChannel.liteReceiverStable);
      expect(profile.includesModule(ProductModule.localAi), isFalse);
      expect(profile.includesModule(ProductModule.recording), isFalse);
      expect(profile.includesModule(ProductModule.downloads), isFalse);
      expect(profile.includesModule(ProductModule.multiview), isFalse);
      expect(profile.includesModule(ProductModule.fullEpg), isFalse);
      expect(profile.supportsCapability(ProductCapability.localAi), isFalse);
      expect(profile.supportsCapability(ProductCapability.fullEpg), isFalse);
      expect(
        profile.guarantees,
        contains(ProductProfileGuarantee.restrictedTrustCompatible),
      );
      expect(profile.validate().accepted, isTrue);
    });

    test('lite receiver accepts a constrained but capable Android TV', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final snapshot = DeviceCapabilitySnapshot(
        apiLevel: 26,
        memoryMb: 1024,
        freeStorageMb: 256,
        decoderCount: 1,
        supportedCodecs: const {
          MediaCodecCapability.h264,
          MediaCodecCapability.aac,
          MediaCodecCapability.hls,
        },
        hasDpad: true,
        hasSecureStorage: true,
      );

      expect(profile.evaluateDevice(snapshot).isSupported, isTrue);
    });

    test('capability evaluation reports deterministic blocker codes', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final snapshot = DeviceCapabilitySnapshot(
        apiLevel: 25,
        memoryMb: 512,
        freeStorageMb: 64,
        decoderCount: 0,
        supportedCodecs: const {MediaCodecCapability.h264},
        hasDpad: false,
        hasSecureStorage: false,
      );

      final evaluation = profile.evaluateDevice(snapshot);

      expect(evaluation.isSupported, isFalse);
      expect(
        evaluation.blockers,
        containsAll(const {
          DeviceCapabilityBlocker.apiLevelTooLow,
          DeviceCapabilityBlocker.memoryTooLow,
          DeviceCapabilityBlocker.storageTooLow,
          DeviceCapabilityBlocker.decoderCountTooLow,
          DeviceCapabilityBlocker.requiredCodecMissing,
          DeviceCapabilityBlocker.dpadRequired,
          DeviceCapabilityBlocker.secureStorageRequired,
        }),
      );
    });

    test('manifest public map exposes stable ids and numeric budgets', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final publicMap = profile.toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['profileId'], ProductProfileId.liteReceiver.stableId);
      expect(
        publicMap['releaseChannel'],
        ProductReleaseChannel.liteReceiverStable.stableId,
      );
      expect(
        publicMap['includedModules'],
        contains(ProductModule.playback.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });

    test(
      'manifest validator rejects overlapping modules and unsupported nav',
      () {
        final manifest = ProductProfileManifest(
          profileId: ProductProfileId.liteReceiver,
          displayName: 'Broken Lite Receiver',
          supportLevel: ProductSupportLevel.compatible,
          releaseChannel: ProductReleaseChannel.liteReceiverStable,
          includedModules: const {
            ProductModule.playback,
            ProductModule.fullEpg,
          },
          excludedModules: const {ProductModule.fullEpg},
          capabilities: const {ProductCapability.directPlayback},
          navigation: const [
            ProductNavigationEntry.home,
            ProductNavigationEntry.search,
          ],
          androidPermissions: const {'android.permission.INTERNET'},
          resourceBudget: const ProductResourceBudget(
            maxMemoryMb: 256,
            maxStorageMb: 128,
            maxArtworkCacheMb: 8,
            maxBackgroundJobs: 1,
          ),
          deviceRequirement: DeviceCapabilityRequirement(
            minApiLevel: 26,
            minMemoryMb: 1024,
            minFreeStorageMb: 128,
            minDecoderCount: 1,
            requiredCodecs: const {
              MediaCodecCapability.h264,
              MediaCodecCapability.aac,
              MediaCodecCapability.hls,
            },
          ),
        );

        final result = manifest.validate();

        expect(result.accepted, isFalse);
        expect(
          result.codes,
          contains(ProductManifestValidationCode.moduleOverlap),
        );
        expect(
          result.codes,
          contains(ProductManifestValidationCode.navigationUnsupported),
        );
      },
    );

    test(
      'manifest validator rejects unsupported capabilities permissions budget',
      () {
        final manifest = ProductProfileManifest(
          profileId: ProductProfileId.fullTv,
          displayName: 'Broken Full TV',
          supportLevel: ProductSupportLevel.certified,
          releaseChannel: ProductReleaseChannel.fullTvStable,
          includedModules: const {ProductModule.playback},
          excludedModules: const {},
          capabilities: const {ProductCapability.recording},
          navigation: const [ProductNavigationEntry.home],
          androidPermissions: const {'android.permission.READ_MEDIA_VIDEO'},
          resourceBudget: const ProductResourceBudget(
            maxMemoryMb: 0,
            maxStorageMb: 0,
            maxArtworkCacheMb: 0,
            maxBackgroundJobs: 0,
          ),
          deviceRequirement: DeviceCapabilityRequirement(
            minApiLevel: 26,
            minMemoryMb: 2048,
            minFreeStorageMb: 512,
            minDecoderCount: 1,
            requiredCodecs: const {MediaCodecCapability.h264},
          ),
        );

        final result = manifest.validate();

        expect(
          result.codes,
          contains(ProductManifestValidationCode.capabilityUnsupported),
        );
        expect(
          result.codes,
          contains(ProductManifestValidationCode.permissionUnsupported),
        );
        expect(
          result.codes,
          contains(ProductManifestValidationCode.budgetInvalid),
        );
      },
    );

    test(
      'manifest validator enforces release channel support compatibility',
      () {
        final manifest = ProductProfileManifest(
          profileId: ProductProfileId.liteReceiver,
          displayName: 'Wrong Channel',
          supportLevel: ProductSupportLevel.experimental,
          releaseChannel: ProductReleaseChannel.fullTvStable,
          includedModules: const {ProductModule.playback},
          excludedModules: const {},
          capabilities: const {ProductCapability.directPlayback},
          navigation: const [ProductNavigationEntry.home],
          androidPermissions: const {'android.permission.INTERNET'},
          resourceBudget: const ProductResourceBudget(
            maxMemoryMb: 256,
            maxStorageMb: 128,
            maxArtworkCacheMb: 8,
            maxBackgroundJobs: 1,
          ),
          deviceRequirement: DeviceCapabilityRequirement(
            minApiLevel: 26,
            minMemoryMb: 1024,
            minFreeStorageMb: 128,
            minDecoderCount: 1,
            requiredCodecs: const {MediaCodecCapability.h264},
          ),
        );

        final result = manifest.validate();

        expect(
          result.codes,
          contains(ProductManifestValidationCode.releaseChannelMismatch),
        );
        expect(
          result.codes,
          contains(ProductManifestValidationCode.supportLevelMismatch),
        );
        expect(result.toPublicMap()['accepted'], isFalse);
      },
    );
  });

  group('Airo TV module lifecycle contracts', () {
    test('playback lifecycle validates for full TV and lite receiver', () {
      final playback = AiroTvModuleLifecycleManifests.playback();

      expect(
        playback.validateFor(AiroTvProductProfiles.fullTv()).accepted,
        isTrue,
      );
      expect(
        playback.validateFor(AiroTvProductProfiles.liteReceiver()).accepted,
        isTrue,
      );
      expect(playback.supportsProfile(ProductProfileId.liteReceiver), isTrue);
    });

    test('full EPG validates for full TV and rejects lite receiver', () {
      final fullEpg = AiroTvModuleLifecycleManifests.fullEpg();

      expect(
        fullEpg.validateFor(AiroTvProductProfiles.fullTv()).accepted,
        isTrue,
      );

      final liteResult = fullEpg.validateFor(
        AiroTvProductProfiles.liteReceiver(),
      );

      expect(liteResult.accepted, isFalse);
      expect(
        liteResult.codes,
        contains(ProductModuleLifecycleValidationCode.unsupportedProfile),
      );
      expect(
        liteResult.codes,
        contains(ProductModuleLifecycleValidationCode.moduleUnavailable),
      );
      expect(
        liteResult.codes,
        contains(ProductModuleLifecycleValidationCode.capabilityUnsupported),
      );
    });

    test('heavy modules remain outside lite receiver lifecycle budgets', () {
      final localAi = AiroTvModuleLifecycleManifests.localAi();
      final result = localAi.validateFor(AiroTvProductProfiles.liteReceiver());

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        containsAll(const {
          ProductModuleLifecycleValidationCode.unsupportedProfile,
          ProductModuleLifecycleValidationCode.moduleUnavailable,
          ProductModuleLifecycleValidationCode.capabilityUnsupported,
          ProductModuleLifecycleValidationCode.initializationCostExceeded,
          ProductModuleLifecycleValidationCode.memoryBudgetExceeded,
          ProductModuleLifecycleValidationCode.backgroundJobBudgetExceeded,
        }),
      );
    });

    test('lifecycle validator rejects unsafe background work', () {
      final manifest = ProductModuleLifecycleManifest(
        module: ProductModule.compactEpg,
        displayName: 'Unsafe Compact EPG',
        supportedProfiles: const {ProductProfileId.liteReceiver},
        dependencies: const {ProductModule.playback},
        requiredCapabilities: const {ProductCapability.compactEpg},
        androidPermissions: const {'android.permission.INTERNET'},
        budget: const ProductModuleLifecycleBudget(
          initializationCostMs: 500,
          maxMemoryMb: 64,
          maxStorageMb: 16,
          maxBackgroundJobs: 1,
        ),
        backgroundTasks: const {ProductModuleBackgroundTask.epgRefresh},
        allowsBackgroundExecution: false,
        supportsGracefulShutdown: false,
      );

      final result = manifest.validateFor(AiroTvProductProfiles.liteReceiver());

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(ProductModuleLifecycleValidationCode.shutdownRequired),
      );
    });

    test('lifecycle validator rejects invalid fallbacks and missing flags', () {
      final manifest = ProductModuleLifecycleManifest(
        module: ProductModule.fullEpg,
        displayName: 'Broken Full EPG',
        supportedProfiles: const {ProductProfileId.fullTv},
        dependencies: const {ProductModule.playback, ProductModule.compactEpg},
        requiredCapabilities: const {
          ProductCapability.compactEpg,
          ProductCapability.fullEpg,
        },
        androidPermissions: const {'android.permission.INTERNET'},
        budget: const ProductModuleLifecycleBudget(
          initializationCostMs: 1200,
          maxMemoryMb: 192,
          maxStorageMb: 128,
          maxBackgroundJobs: 1,
        ),
        fallbackModule: ProductModule.fullEpg,
      );

      final result = manifest.validateFor(AiroTvProductProfiles.fullTv());

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(ProductModuleLifecycleValidationCode.fallbackInvalid),
      );
      expect(
        result.codes,
        contains(ProductModuleLifecycleValidationCode.featureFlagMissing),
      );
    });

    test('lifecycle public map exposes stable ids and numeric budgets', () {
      final publicMap = AiroTvModuleLifecycleManifests.compactEpg()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['module'], ProductModule.compactEpg.stableId);
      expect(
        publicMap['supportedProfiles'],
        contains(ProductProfileId.liteReceiver.stableId),
      );
      expect(
        publicMap['dependencies'],
        contains(ProductModule.playback.stableId),
      );
      expect(
        publicMap['backgroundTasks'],
        contains(ProductModuleBackgroundTask.epgRefresh.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });
  });

  group('Airo TV product composition contracts', () {
    test('full TV composition validates with compiled lifecycle manifests', () {
      final composition = AiroTvProductCompositions.fullTv();
      final result = composition.validate();

      expect(result.accepted, isTrue);
      expect(
        composition.compiledModules,
        containsAll(AiroTvProductProfiles.fullTv().includedModules),
      );
      expect(
        composition.enabledFeatureFlags,
        contains(ProductModuleFeatureFlag.fullEpg),
      );
    });

    test('lite receiver composition excludes heavy modules', () {
      final composition = AiroTvProductCompositions.liteReceiver();
      final result = composition.validate();

      expect(result.accepted, isTrue);
      expect(
        composition.compiledModules,
        isNot(contains(ProductModule.fullEpg)),
      );
      expect(
        composition.compiledModules,
        isNot(contains(ProductModule.localAi)),
      );
      expect(
        composition.enabledFeatureFlags,
        isNot(contains(ProductModuleFeatureFlag.fullEpg)),
      );
    });

    test('composition rejects runtime flag for absent module', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final composition = ProductCompositionManifest(
        profileManifest: profile,
        compiledModules: profile.includedModules,
        lifecycleManifests: [
          ...AiroTvModuleLifecycleManifests.liteReceiver(),
          AiroTvModuleLifecycleManifests.fullEpg(),
        ],
        enabledFeatureFlags: const {ProductModuleFeatureFlag.fullEpg},
      );

      final result = composition.validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(ProductCompositionValidationCode.lifecycleManifestInvalid),
      );
      expect(
        result.codes,
        contains(ProductCompositionValidationCode.lifecycleModuleNotCompiled),
      );
      expect(
        result.codes,
        contains(ProductCompositionValidationCode.runtimeFlagWithoutModule),
      );
    });

    test('composition rejects excluded compiled modules', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final composition = ProductCompositionManifest(
        profileManifest: profile,
        compiledModules: {...profile.includedModules, ProductModule.localAi},
        lifecycleManifests: AiroTvModuleLifecycleManifests.liteReceiver(),
      );

      final result = composition.validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(ProductCompositionValidationCode.excludedModuleCompiled),
      );
    });

    test('composition rejects included module without lifecycle manifest', () {
      final profile = AiroTvProductProfiles.fullTv();
      final lifecycles = AiroTvModuleLifecycleManifests.fullTv()
          .where((manifest) => manifest.module != ProductModule.analytics)
          .toList(growable: false);
      final composition = ProductCompositionManifest(
        profileManifest: profile,
        compiledModules: profile.includedModules,
        lifecycleManifests: lifecycles,
      );

      final result = composition.validate();

      expect(result.accepted, isFalse);
      expect(
        result.codes,
        contains(
          ProductCompositionValidationCode.includedModuleMissingLifecycle,
        ),
      );
    });

    test('composition public map exposes stable ids only', () {
      final publicMap = AiroTvProductCompositions.liteReceiver().toPublicMap();
      final flattened = publicMap.toString();

      expect(
        publicMap['compiledModules'],
        contains(ProductModule.playback.stableId),
      );
      expect(
        publicMap['enabledFeatureFlags'],
        contains(ProductModuleFeatureFlag.diagnostics.stableId),
      );
      expect(
        publicMap['lifecycleModules'],
        contains(ProductModule.compactEpg.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });
  });

  group('Airo TV profile navigation manifests', () {
    test('full TV navigation validates against full TV composition', () {
      final manifest = AiroTvNavigationManifests.fullTv();
      final result = manifest.validate(
        profile: AiroTvProductProfiles.fullTv(),
        composition: AiroTvProductCompositions.fullTv(),
      );

      expect(result, const [ProductNavigationValidationCode.accepted]);
      expect(
        manifest.sections.map((section) => section.entry),
        contains(ProductNavigationEntry.guide),
      );
      expect(
        manifest.sections.map((section) => section.renderTier),
        contains(ProductNavigationRenderTier.rich),
      );
    });

    test('lite receiver navigation excludes unavailable heavy sections', () {
      final manifest = AiroTvNavigationManifests.liteReceiver();
      final result = manifest.validate(
        profile: AiroTvProductProfiles.liteReceiver(),
        composition: AiroTvProductCompositions.liteReceiver(),
      );

      expect(result, const [ProductNavigationValidationCode.accepted]);
      expect(
        manifest.sections.map((section) => section.entry),
        isNot(contains(ProductNavigationEntry.guide)),
      );
      expect(
        manifest.sections.map((section) => section.renderTier).toSet(),
        const {ProductNavigationRenderTier.lightweight},
      );
    });

    test('embedded receiver rejects rich unavailable navigation sections', () {
      final profile = _embeddedReceiverProfile();
      final manifest = ProductNavigationManifest(
        profileId: ProductProfileId.embeddedReceiver,
        sections: const [
          ProductNavigationSection(
            entry: ProductNavigationEntry.guide,
            routeId: 'embedded.guide',
            displayKey: 'navigation.guide',
            renderTier: ProductNavigationRenderTier.rich,
            requiredModule: ProductModule.fullEpg,
            requiredCapability: ProductCapability.fullEpg,
          ),
        ],
      );

      final result = manifest.validate(profile: profile);

      expect(
        result,
        contains(ProductNavigationValidationCode.entryUnsupported),
      );
      expect(
        result,
        contains(ProductNavigationValidationCode.moduleUnavailable),
      );
      expect(
        result,
        contains(ProductNavigationValidationCode.capabilityUnsupported),
      );
      expect(
        result,
        contains(ProductNavigationValidationCode.renderTierUnsupported),
      );
    });

    test('navigation validation rejects empty and duplicate routes', () {
      final manifest = ProductNavigationManifest(
        profileId: ProductProfileId.liteReceiver,
        sections: const [
          ProductNavigationSection(
            entry: ProductNavigationEntry.home,
            routeId: '',
            displayKey: '',
            renderTier: ProductNavigationRenderTier.lightweight,
          ),
          ProductNavigationSection(
            entry: ProductNavigationEntry.live,
            routeId: 'lite.live',
            displayKey: 'navigation.live',
            renderTier: ProductNavigationRenderTier.lightweight,
            requiredModule: ProductModule.playback,
          ),
          ProductNavigationSection(
            entry: ProductNavigationEntry.search,
            routeId: 'lite.live',
            displayKey: 'navigation.search',
            renderTier: ProductNavigationRenderTier.lightweight,
            requiredModule: ProductModule.basicSearch,
          ),
        ],
      );

      final result = manifest.validate(
        profile: AiroTvProductProfiles.liteReceiver(),
      );

      expect(result, contains(ProductNavigationValidationCode.routeIdMissing));
      expect(
        result,
        contains(ProductNavigationValidationCode.displayKeyMissing),
      );
      expect(
        result,
        contains(ProductNavigationValidationCode.duplicateRouteId),
      );
    });

    test('navigation validation catches modules absent from composition', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final composition = ProductCompositionManifest(
        profileManifest: profile,
        compiledModules: profile.includedModules.difference({
          ProductModule.basicSearch,
        }),
        lifecycleManifests: AiroTvModuleLifecycleManifests.liteReceiver(),
      );

      final result = AiroTvNavigationManifests.liteReceiver().validate(
        profile: profile,
        composition: composition,
      );

      expect(
        result,
        contains(ProductNavigationValidationCode.compositionModuleNotCompiled),
      );
    });

    test('navigation public map exposes stable route ids only', () {
      final publicMap = AiroTvNavigationManifests.liteReceiver().toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['profileId'], ProductProfileId.liteReceiver.stableId);
      expect(flattened, contains('lite.search'));
      expect(
        flattened,
        contains(ProductNavigationRenderTier.lightweight.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });
  });

  group('Airo TV release listing strategies', () {
    test(
      'single adaptive app strategy validates shared listing constraints',
      () {
        final strategy =
            AiroTvReleaseListingStrategies.singleAdaptiveApplication();

        expect(strategy.validate().accepted, isTrue);
        expect(
          strategy.strategy,
          ProductStoreListingStrategy.singleAdaptiveApplication,
        );
        expect(strategy.listingIds, {'airo-tv'});
        expect(strategy.usesDeviceTargeting, isTrue);
        expect(strategy.usesFeatureDelivery, isTrue);
        expect(strategy.isolatesDependencies, isTrue);
        expect(
          strategy.profileChannels[ProductProfileId.liteReceiver],
          ProductReleaseChannel.liteReceiverStable,
        );
        expect(
          strategy.providedEvidence,
          contains(ProductStoreListingEvidence.legalReview),
        );
      },
    );

    test('split full lite app strategy validates separate listings', () {
      final strategy =
          AiroTvReleaseListingStrategies.splitFullLiteApplications();

      expect(strategy.validate().accepted, isTrue);
      expect(
        strategy.strategy,
        ProductStoreListingStrategy.splitFullLiteApplications,
      );
      expect(strategy.listingIds, containsAll({'airo-tv', 'airo-tv-lite'}));
      expect(strategy.usesDeviceTargeting, isTrue);
      expect(strategy.isolatesDependencies, isTrue);
      expect(strategy.sharesAccountEntitlements, isTrue);
    });

    test(
      'targeted delivery requires feature delivery and catalog evidence',
      () {
        final strategy = AiroTvReleaseListingStrategies.targetedDelivery();

        expect(strategy.validate().accepted, isTrue);
        expect(strategy.listingIds, {'airo-tv'});
        expect(strategy.usesFeatureDelivery, isTrue);
        expect(
          strategy.providedEvidence,
          containsAll(const {
            ProductStoreListingEvidence.deviceCatalogReview,
            ProductStoreListingEvidence.featureDeliveryReview,
          }),
        );
      },
    );

    test(
      'vendor and internal channels stay outside general store publishing',
      () {
        final vendor = AiroTvReleaseListingStrategies.vendorSpecificReceiver();
        final internal = AiroTvReleaseListingStrategies.internalCertification();

        expect(vendor.validate().accepted, isTrue);
        expect(vendor.generalStorePublishable, isFalse);
        expect(
          vendor.providedEvidence,
          contains(ProductStoreListingEvidence.vendorApproval),
        );
        expect(internal.validate().accepted, isTrue);
        expect(internal.rolloutPercentage, 0);
        expect(internal.generalStorePublishable, isFalse);
      },
    );

    test(
      'listing policy rejects channel mismatch and missing legal review',
      () {
        final strategy = ProductStoreListingStrategyManifest(
          strategyId: 'broken-release-listing',
          displayName: 'Broken release listing',
          strategy: ProductStoreListingStrategy.targetedDelivery,
          profileChannels: const {
            ProductProfileId.liteReceiver: ProductReleaseChannel.fullTvStable,
          },
          listingIds: const {'airo-tv'},
          requiredEvidence: const {
            ProductStoreListingEvidence.legalReview,
            ProductStoreListingEvidence.deviceCatalogReview,
            ProductStoreListingEvidence.featureDeliveryReview,
          },
          providedEvidence: const {
            ProductStoreListingEvidence.deviceCatalogReview,
          },
          rolloutPercentage: 0,
          crashFreeSessionsThresholdBasisPoints: 8500,
          usesDeviceTargeting: true,
          usesFeatureDelivery: false,
          isolatesDependencies: false,
          sharesAccountEntitlements: false,
          preservesProtocolCompatibility: false,
          generalStorePublishable: true,
        );

        final result = strategy.validate();

        expect(
          result.codes,
          contains(ProductStoreListingValidationCode.channelMismatch),
        );
        expect(
          result.codes,
          contains(ProductStoreListingValidationCode.evidenceMissing),
        );
        expect(
          result.codes,
          contains(ProductStoreListingValidationCode.rolloutInvalid),
        );
        expect(
          result.codes,
          contains(ProductStoreListingValidationCode.crashThresholdInvalid),
        );
        expect(
          result.codes,
          contains(ProductStoreListingValidationCode.sharedAccountMissing),
        );
        expect(
          result.codes,
          contains(
            ProductStoreListingValidationCode.protocolCompatibilityMissing,
          ),
        );
        expect(
          result.codes,
          contains(
            ProductStoreListingValidationCode.dependencyIsolationMissing,
          ),
        );
        expect(
          result.codes,
          contains(
            ProductStoreListingValidationCode.targetedDeliveryEvidenceMissing,
          ),
        );
        expect(
          result.codes,
          contains(ProductStoreListingValidationCode.legalReviewMissing),
        );
      },
    );

    test('listing public map exposes stable ids only', () {
      final publicMap = AiroTvReleaseListingStrategies.targetedDelivery()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['strategyId'], 'airo-tv-targeted-delivery');
      expect(
        publicMap['strategy'],
        ProductStoreListingStrategy.targetedDelivery.stableId,
      );
      expect(publicMap['listingIds'], contains('airo-tv'));
      expect(
        flattened,
        contains(ProductStoreListingEvidence.storePolicyReview.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
      expect(flattened, isNot(contains('http://')));
    });
  });

  group('Airo TV cross-profile compatibility suite', () {
    test('v2 suite validates required cross-profile scenarios', () {
      final suite = AiroTvCrossProfileCompatibilitySuites.releaseV2_0_0_1();

      expect(suite.validate().accepted, isTrue);
      expect(suite.scenarios, hasLength(8));
      expect(
        suite.scenarioById('mobile-to-lite-handoff')?.requiredAssertions,
        containsAll(const {
          ProductCompatibilityAssertion.capabilityAdvertisement,
          ProductCompatibilityAssertion.handoffPreflight,
          ProductCompatibilityAssertion.sourcePlaybackPreserved,
          ProductCompatibilityAssertion.trustedRelationship,
          ProductCompatibilityAssertion.privacyRedaction,
        }),
      );
      expect(
        suite.scenarioById('mobile-to-receiver-only-playback')?.targetProfile,
        ProductCompatibilityParticipantProfile.embeddedReceiver,
      );
    });

    test('protocol mismatch scenarios pin expected old and new outcomes', () {
      final suite = AiroTvCrossProfileCompatibilitySuites.releaseV2_0_0_1();
      final oldReceiver = suite.scenarioById(
        'old-receiver-new-controller-protocol',
      )!;
      final oldController = suite.scenarioById(
        'old-controller-new-receiver-protocol',
      )!;

      expect(
        oldReceiver.expectedOutcome,
        ProductCompatibilityExpectedOutcome.protocolTooOld,
      );
      expect(oldReceiver.controllerProtocolVersion, 2);
      expect(oldReceiver.receiverProtocolVersion, 1);
      expect(
        oldController.expectedOutcome,
        ProductCompatibilityExpectedOutcome.protocolTooNew,
      );
      expect(oldController.controllerProtocolVersion, 1);
      expect(oldController.receiverProtocolVersion, 2);
      expect(
        oldController.requiredAssertions,
        contains(ProductCompatibilityAssertion.protocolCompatibility),
      );
    });

    test('companion unavailable keeps lite receiver usable', () {
      final scenario = AiroTvCrossProfileCompatibilitySuites.releaseV2_0_0_1()
          .scenarioById('lite-companion-unavailable')!;

      expect(scenario.companionAvailable, isFalse);
      expect(
        scenario.expectedOutcome,
        ProductCompatibilityExpectedOutcome.companionUnavailableFallback,
      );
      expect(
        scenario.requiredAssertions,
        containsAll(const {
          ProductCompatibilityAssertion.companionFallback,
          ProductCompatibilityAssertion.delegationUnsupportedReason,
          ProductCompatibilityAssertion.sessionIdentityPreserved,
        }),
      );
    });

    test('suite policy rejects unsafe or incomplete failure scenarios', () {
      final suite = ProductCrossProfileCompatibilitySuite(
        suiteId: 'broken-cross-profile-suite',
        displayName: 'Broken cross-profile suite',
        scenarios: [
          ProductCrossProfileCompatibilityScenario(
            scenarioId: 'duplicate',
            displayName: 'Duplicate one',
            kind: ProductCompatibilityScenarioKind.handoff,
            sourceProfile: ProductCompatibilityParticipantProfile.fullTv,
            targetProfile: ProductCompatibilityParticipantProfile.fullTv,
            requiredAssertions: const {
              ProductCompatibilityAssertion.handoffPreflight,
            },
            automationTags: const {},
            expectedOutcome:
                ProductCompatibilityExpectedOutcome.blockedBeforeHandoff,
            controllerProtocolVersion: 0,
            sourcePlaybackMustRemainActiveOnFailure: false,
            preservesSharedAccount: false,
            preservesSessionIdentity: false,
          ),
          ProductCrossProfileCompatibilityScenario(
            scenarioId: 'duplicate',
            displayName: 'Duplicate two',
            kind: ProductCompatibilityScenarioKind.companionUnavailable,
            sourceProfile: ProductCompatibilityParticipantProfile.liteReceiver,
            targetProfile: ProductCompatibilityParticipantProfile.homeNode,
            requiredAssertions: {},
            automationTags: {ProductCompatibilityAutomationTag.hostUnit},
            expectedOutcome: ProductCompatibilityExpectedOutcome
                .companionUnavailableFallback,
            companionAvailable: true,
          ),
        ],
      );

      final result = suite.validate();

      expect(
        result.codes,
        contains(ProductCompatibilitySuiteValidationCode.duplicateScenarioId),
      );
      expect(
        result.codes,
        contains(ProductCompatibilitySuiteValidationCode.profileMissing),
      );
      expect(
        result.codes,
        contains(ProductCompatibilitySuiteValidationCode.assertionMissing),
      );
      expect(
        result.codes,
        contains(ProductCompatibilitySuiteValidationCode.automationTagMissing),
      );
      expect(
        result.codes,
        contains(
          ProductCompatibilitySuiteValidationCode.protocolVersionInvalid,
        ),
      );
      expect(
        result.codes,
        contains(ProductCompatibilitySuiteValidationCode.unsafeFailureBehavior),
      );
      expect(
        result.codes,
        contains(ProductCompatibilitySuiteValidationCode.sharedAccountMissing),
      );
      expect(
        result.codes,
        contains(
          ProductCompatibilitySuiteValidationCode.sessionIdentityMissing,
        ),
      );
      expect(
        result.codes,
        contains(
          ProductCompatibilitySuiteValidationCode.companionFallbackMissing,
        ),
      );
      expect(
        result.codes,
        contains(
          ProductCompatibilitySuiteValidationCode.privacyAssertionMissing,
        ),
      );
    });

    test('suite public map exposes stable ids only', () {
      final publicMap = AiroTvCrossProfileCompatibilitySuites.releaseV2_0_0_1()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['suiteId'], 'airo-tv-v2-0-0-1-cross-profile');
      expect(flattened, contains('mobile-to-lite-handoff'));
      expect(
        flattened,
        contains(ProductCompatibilityAssertion.handoffPreflight.stableId),
      );
      expect(
        flattened,
        contains(ProductCompatibilityAutomationTag.releaseGate.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
      expect(flattened, isNot(contains('http://')));
      expect(flattened, isNot(contains('192.168.')));
    });
  });

  group('Airo TV profile-aware capability advertisements', () {
    test('full TV advertises runtime-safe profile capabilities', () {
      final advertisement = AiroTvCapabilityAdvertisements.fullTv(
        _fullTvDeviceSnapshot(),
      );

      expect(advertisement.compositionAccepted, isTrue);
      expect(advertisement.deviceSupported, isTrue);
      expect(advertisement.profileId, ProductProfileId.fullTv);
      expect(advertisement.advertises(ProductCapability.fullEpg), isTrue);
      expect(advertisement.advertises(ProductCapability.analytics), isTrue);
      expect(advertisement.compiledModules, contains(ProductModule.fullEpg));
      expect(
        advertisement.enabledFeatureFlags,
        contains(ProductModuleFeatureFlag.fullEpg),
      );
      expect(
        advertisement.unsupportedReasons.where(
          (reason) =>
              reason.code ==
              ProductCapabilityUnsupportedReasonCode.deviceRequirementBlocked,
        ),
        isEmpty,
      );
    });

    test('lite receiver does not advertise heavy capabilities', () {
      final advertisement = AiroTvCapabilityAdvertisements.liteReceiver(
        _liteReceiverDeviceSnapshot(),
      );

      expect(advertisement.compositionAccepted, isTrue);
      expect(advertisement.deviceSupported, isTrue);
      expect(advertisement.profileId, ProductProfileId.liteReceiver);
      expect(advertisement.advertises(ProductCapability.compactEpg), isTrue);
      expect(advertisement.advertises(ProductCapability.fullEpg), isFalse);
      expect(advertisement.advertises(ProductCapability.localAi), isFalse);
      expect(advertisement.advertises(ProductCapability.recording), isFalse);
      expect(
        advertisement.compiledModules,
        isNot(contains(ProductModule.fullEpg)),
      );
      expect(
        advertisement.unsupportedReasons.map((reason) => reason.capability),
        containsAll(const {
          ProductCapability.fullEpg,
          ProductCapability.localAi,
          ProductCapability.recording,
          ProductCapability.downloads,
          ProductCapability.multiview,
        }),
      );
    });

    test('device blockers prevent runtime-safe capability publication', () {
      final advertisement = AiroTvCapabilityAdvertisements.liteReceiver(
        DeviceCapabilitySnapshot(
          apiLevel: 25,
          memoryMb: 512,
          freeStorageMb: 64,
          decoderCount: 0,
          supportedCodecs: const {MediaCodecCapability.h264},
          hasDpad: false,
          hasSecureStorage: false,
        ),
      );

      expect(advertisement.deviceSupported, isFalse);
      expect(advertisement.runtimeSafeCapabilities, isEmpty);
      expect(
        advertisement.unsupportedReasons.map((reason) => reason.deviceBlocker),
        containsAll(const {
          DeviceCapabilityBlocker.apiLevelTooLow,
          DeviceCapabilityBlocker.memoryTooLow,
          DeviceCapabilityBlocker.storageTooLow,
          DeviceCapabilityBlocker.decoderCountTooLow,
          DeviceCapabilityBlocker.requiredCodecMissing,
          DeviceCapabilityBlocker.dpadRequired,
          DeviceCapabilityBlocker.secureStorageRequired,
        }),
      );
    });

    test('composition rejection is exposed as unsupported reasons', () {
      final profile = AiroTvProductProfiles.liteReceiver();
      final composition = ProductCompositionManifest(
        profileManifest: profile,
        compiledModules: profile.includedModules,
        lifecycleManifests: [
          ...AiroTvModuleLifecycleManifests.liteReceiver(),
          AiroTvModuleLifecycleManifests.fullEpg(),
        ],
        enabledFeatureFlags: const {ProductModuleFeatureFlag.fullEpg},
      );

      final advertisement = const ProductCapabilityAdvertisementPolicy()
          .publish(
            composition: composition,
            deviceSnapshot: _liteReceiverDeviceSnapshot(),
          );

      expect(advertisement.compositionAccepted, isFalse);
      expect(advertisement.advertises(ProductCapability.fullEpg), isFalse);
      expect(
        advertisement.unsupportedReasons.map(
          (reason) => reason.compositionCode,
        ),
        contains(ProductCompositionValidationCode.runtimeFlagWithoutModule),
      );
      expect(
        advertisement.unsupportedReasons.map((reason) => reason.code),
        contains(ProductCapabilityUnsupportedReasonCode.compositionInvalid),
      );
    });

    test('advertisement public map exposes stable ids only', () {
      final publicMap = AiroTvCapabilityAdvertisements.liteReceiver(
        _liteReceiverDeviceSnapshot(),
      ).toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['profileId'], ProductProfileId.liteReceiver.stableId);
      expect(
        publicMap['runtimeSafeCapabilities'],
        contains(ProductCapability.compactEpg.stableId),
      );
      expect(
        publicMap['compiledModules'],
        contains(ProductModule.playback.stableId),
      );
      expect(publicMap['compositionAccepted'], isTrue);
      expect(publicMap['deviceSupported'], isTrue);
      expect(flattened, contains('profile_capability_absent'));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });
  });
}

ProductProfileManifest _embeddedReceiverProfile() {
  return ProductProfileManifest(
    profileId: ProductProfileId.embeddedReceiver,
    displayName: 'Airo Embedded Receiver',
    supportLevel: ProductSupportLevel.compatible,
    releaseChannel: ProductReleaseChannel.receiverStable,
    includedModules: const {ProductModule.playback},
    excludedModules: const {
      ProductModule.fullEpg,
      ProductModule.localAi,
      ProductModule.recording,
      ProductModule.downloads,
      ProductModule.multiview,
    },
    capabilities: const {
      ProductCapability.directPlayback,
      ProductCapability.dpadNavigation,
    },
    navigation: const [
      ProductNavigationEntry.home,
      ProductNavigationEntry.live,
      ProductNavigationEntry.settings,
    ],
    androidPermissions: const {'android.permission.INTERNET'},
    resourceBudget: const ProductResourceBudget(
      maxMemoryMb: 256,
      maxStorageMb: 64,
      maxArtworkCacheMb: 8,
      maxBackgroundJobs: 0,
    ),
    deviceRequirement: DeviceCapabilityRequirement(
      minApiLevel: 26,
      minMemoryMb: 768,
      minFreeStorageMb: 64,
      minDecoderCount: 1,
      requiredCodecs: const {
        MediaCodecCapability.h264,
        MediaCodecCapability.aac,
      },
    ),
  );
}

DeviceCapabilitySnapshot _fullTvDeviceSnapshot() {
  return DeviceCapabilitySnapshot(
    apiLevel: 29,
    memoryMb: 4096,
    freeStorageMb: 2048,
    decoderCount: 2,
    supportedCodecs: const {
      MediaCodecCapability.h264,
      MediaCodecCapability.aac,
      MediaCodecCapability.hls,
      MediaCodecCapability.hevc,
    },
    hasDpad: true,
    hasSecureStorage: true,
  );
}

DeviceCapabilitySnapshot _liteReceiverDeviceSnapshot() {
  return DeviceCapabilitySnapshot(
    apiLevel: 26,
    memoryMb: 1024,
    freeStorageMb: 256,
    decoderCount: 1,
    supportedCodecs: const {
      MediaCodecCapability.h264,
      MediaCodecCapability.aac,
      MediaCodecCapability.hls,
    },
    hasDpad: true,
    hasSecureStorage: true,
  );
}
