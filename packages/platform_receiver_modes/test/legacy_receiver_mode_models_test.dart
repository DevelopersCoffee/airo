import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';
import 'package:platform_receiver_modes/platform_receiver_modes.dart';
import 'package:product_capabilities/product_capabilities.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 7, 14, 14);
  const policy = LegacyReceiverModePolicy();

  group('LegacyReceiverModePolicy', () {
    test('keeps Legacy Receiver Mode off for fully supported Full TV', () {
      final contract = policy.evaluate(
        runtimeProfile: _runtimeProfile(
          supportTier: AiroRuntimeSupportTier.fullySupported,
          productProfile: ProductProfileId.fullTv,
          legacyRecommended: false,
        ),
        now: capturedAt,
      );

      expect(contract.modeId, LegacyReceiverModeId.off);
      expect(contract.enabled, isFalse);
      expect(contract.activationBlocked, isFalse);
      expect(contract.recommendedProductProfile, ProductProfileId.fullTv);
      expect(contract.visualBudget.allowAnimatedPreviews, isTrue);
      expect(contract.dataBudget.allowFullLocalIndex, isTrue);
    });

    test('enables Lite Receiver with compact budgets for legacy profile', () {
      final contract = policy.evaluate(
        runtimeProfile: _runtimeProfile(
          supportTier: AiroRuntimeSupportTier.legacyOptimized,
          productProfile: ProductProfileId.liteReceiver,
          legacyRecommended: true,
          constraints: const [AiroRuntimeConstraintCode.memoryLow],
        ),
        now: capturedAt,
      );

      expect(contract.modeId, LegacyReceiverModeId.liteReceiver);
      expect(contract.enabled, isTrue);
      expect(contract.usesLegacyReceiverMode, isTrue);
      expect(contract.recommendedProductProfile, ProductProfileId.liteReceiver);
      expect(
        contract.homeSections,
        containsAll(const {
          LegacyReceiverHomeSection.continueWatching,
          LegacyReceiverHomeSection.liveNow,
          LegacyReceiverHomeSection.phoneSearch,
          LegacyReceiverHomeSection.currentProgram,
        }),
      );
      expect(
        contract.navigation,
        isNot(contains(ProductNavigationEntry.guide)),
      );
      expect(contract.disabledModules, contains(ProductModule.fullEpg));
      expect(contract.disabledModules, contains(ProductModule.localAi));
      expect(contract.visualBudget.allowAnimatedPreviews, isFalse);
      expect(contract.visualBudget.allowBlurEffects, isFalse);
      expect(contract.dataBudget.allowFullLocalIndex, isFalse);
      expect(contract.dataBudget.catalogPageSize, 25);
    });

    test('exposes pressure trigger from runtime constraints', () {
      final contract = policy.evaluate(
        runtimeProfile: _runtimeProfile(
          supportTier: AiroRuntimeSupportTier.legacyOptimized,
          productProfile: ProductProfileId.liteReceiver,
          legacyRecommended: true,
          constraints: const [
            AiroRuntimeConstraintCode.networkConstrained,
            AiroRuntimeConstraintCode.decoderFailurePressure,
          ],
        ),
        now: capturedAt,
      );

      expect(
        contract.triggers,
        containsAll(const {
          LegacyReceiverModeTrigger.runtimeProfile,
          LegacyReceiverModeTrigger.resourcePressure,
        }),
      );
      expect(
        contract.runtimeConstraints,
        contains(AiroRuntimeConstraintCode.decoderFailurePressure),
      );
    });

    test('returns restricted Lite Receiver for restricted trust profile', () {
      final contract = policy.evaluate(
        runtimeProfile: _runtimeProfile(
          supportTier: AiroRuntimeSupportTier.legacyOptimized,
          productProfile: ProductProfileId.liteReceiver,
          legacyRecommended: true,
          restrictedTrust: true,
          constraints: const [
            AiroRuntimeConstraintCode.securityPatchStale,
            AiroRuntimeConstraintCode.restrictedTrustRequired,
          ],
        ),
        now: capturedAt,
      );

      expect(contract.modeId, LegacyReceiverModeId.restrictedLiteReceiver);
      expect(
        contract.triggers,
        contains(LegacyReceiverModeTrigger.restrictedTrust),
      );
      expect(contract.delegationPolicy.allowCompanionDiscovery, isFalse);
      expect(
        contract.delegationPolicy.required,
        contains(LegacyReceiverDelegationCapability.companionPlaybackResolve),
      );
      expect(
        contract.visualBudget.artworkPolicy,
        LegacyReceiverArtworkPolicy.iconsOnly,
      );
      expect(contract.dataBudget.catalogPageSize, 16);
    });

    test('blocks activation for unsupported runtime profile', () {
      final contract = policy.evaluate(
        runtimeProfile: _runtimeProfile(
          supportTier: AiroRuntimeSupportTier.unsupported,
          productProfile: ProductProfileId.embeddedReceiver,
          legacyRecommended: false,
          constraints: const [AiroRuntimeConstraintCode.requiredCodecMissing],
        ),
        now: capturedAt,
      );

      expect(contract.modeId, LegacyReceiverModeId.blocked);
      expect(contract.enabled, isFalse);
      expect(contract.activationBlocked, isTrue);
      expect(contract.navigation, const [
        ProductNavigationEntry.settings,
        ProductNavigationEntry.diagnostics,
      ]);
      expect(contract.includedModules, const {ProductModule.diagnostics});
      expect(contract.dataBudget.catalogPageSize, 0);
      expect(contract.delegationPolicy.allowStandalonePlayback, isFalse);
    });

    test('public map omits raw runtime signals', () {
      final contract = policy.evaluate(
        runtimeProfile: _runtimeProfile(
          supportTier: AiroRuntimeSupportTier.legacyOptimized,
          productProfile: ProductProfileId.liteReceiver,
          legacyRecommended: true,
        ),
        now: capturedAt,
      );

      final publicMap = contract.toPublicMap();

      expect(publicMap, containsPair('modeId', 'lite_receiver'));
      expect(publicMap, isNot(contains('signals')));
      expect(publicMap, isNot(contains('supportedCodecs')));
      expect(publicMap, isNot(contains('decoderFailureCount')));
    });
  });
}

AiroRuntimeDeviceProfile _runtimeProfile({
  required AiroRuntimeSupportTier supportTier,
  required ProductProfileId productProfile,
  required bool legacyRecommended,
  bool restrictedTrust = false,
  List<AiroRuntimeConstraintCode> constraints = const [
    AiroRuntimeConstraintCode.accepted,
  ],
}) {
  final signals = AiroRuntimeDeviceSignals(
    signalId: 'receiver-mode-test',
    platformCategory: AiroNodePlatformCategory.androidTv,
    apiLevel: 30,
    memoryMb: 3072,
    freeStorageMb: 1024,
    gpuClass: AiroRuntimeGpuClass.standard,
    decoderCount: 2,
    supportedCodecs: const {
      MediaCodecCapability.h264,
      MediaCodecCapability.aac,
      MediaCodecCapability.hls,
    },
    remoteInputs: const {AiroRuntimeRemoteInput.dpad},
    networkClass: AiroRuntimeNetworkClass.stableWifi,
  );

  return AiroRuntimeDeviceProfile(
    profileId: 'runtime-receiver-mode-test',
    signals: signals,
    supportTier: supportTier,
    recommendedProductProfile: productProfile,
    legacyReceiverModeRecommended: legacyRecommended,
    restrictedReceiverTrustRequired: restrictedTrust,
    constraints: constraints,
    capturedAt: DateTime.utc(2026, 7, 14, 13),
  );
}
