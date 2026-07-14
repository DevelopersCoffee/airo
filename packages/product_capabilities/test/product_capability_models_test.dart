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
}
