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
}
