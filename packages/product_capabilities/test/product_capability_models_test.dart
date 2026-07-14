import 'package:flutter_test/flutter_test.dart';
import 'package:product_capabilities/product_capabilities.dart';

void main() {
  group('Airo TV product profile contracts', () {
    test('full TV manifest exposes stable schema and profile identifiers', () {
      final profile = AiroTvProductProfiles.fullTv();

      expect(profile.schemaVersion, kProductCapabilitiesSchemaVersion);
      expect(profile.profileId.stableId, 'full_tv');
      expect(profile.supportsCapability(ProductCapability.fullEpg), isTrue);
      expect(profile.navigation, contains(ProductNavigationEntry.guide));
    });

    test('lite receiver excludes heavy profile modules and capabilities', () {
      final profile = AiroTvProductProfiles.liteReceiver();

      expect(profile.profileId, ProductProfileId.liteReceiver);
      expect(profile.includesModule(ProductModule.localAi), isFalse);
      expect(profile.includesModule(ProductModule.recording), isFalse);
      expect(profile.includesModule(ProductModule.downloads), isFalse);
      expect(profile.includesModule(ProductModule.multiview), isFalse);
      expect(profile.includesModule(ProductModule.fullEpg), isFalse);
      expect(profile.supportsCapability(ProductCapability.localAi), isFalse);
      expect(profile.supportsCapability(ProductCapability.fullEpg), isFalse);
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
  });
}
