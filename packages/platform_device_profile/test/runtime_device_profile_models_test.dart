import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';
import 'package:product_capabilities/product_capabilities.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 7, 14, 12);
  final policy = AiroRuntimeDeviceProfilePolicy();

  group('AiroRuntimeDeviceProfilePolicy', () {
    test('classifies a strong Android TV as fully supported Full TV', () {
      final profile = policy.evaluate(
        signals: _signals(
          signalId: 'strong-tv',
          apiLevel: 30,
          memoryMb: 3072,
          freeStorageMb: 1024,
          gpuClass: AiroRuntimeGpuClass.accelerated,
          decoderCount: 2,
          supportedCodecs: const {
            MediaCodecCapability.h264,
            MediaCodecCapability.aac,
            MediaCodecCapability.hls,
            MediaCodecCapability.mpegTs,
          },
          remoteInputs: const {
            AiroRuntimeRemoteInput.dpad,
            AiroRuntimeRemoteInput.mediaKeys,
          },
          networkClass: AiroRuntimeNetworkClass.stableWifi,
          securityPatchAgeDays: 90,
        ),
        now: capturedAt,
      );

      expect(profile.supportTier, AiroRuntimeSupportTier.fullySupported);
      expect(profile.recommendedProductProfile, ProductProfileId.fullTv);
      expect(profile.legacyReceiverModeRecommended, isFalse);
      expect(profile.restrictedReceiverTrustRequired, isFalse);
      expect(profile.constraints, const [AiroRuntimeConstraintCode.accepted]);
      expect(profile.toPublicMap(), isNot(contains('rawModel')));
    });

    test(
      'classifies a constrained API 26 TV as Legacy Optimized Lite Receiver',
      () {
        final profile = policy.evaluate(
          signals: _signals(
            signalId: 'api26-tv',
            apiLevel: 26,
            memoryMb: 1024,
            freeStorageMb: 128,
            gpuClass: AiroRuntimeGpuClass.basic2d,
            decoderCount: 1,
          ),
          now: capturedAt,
        );

        expect(profile.supportTier, AiroRuntimeSupportTier.legacyOptimized);
        expect(
          profile.recommendedProductProfile,
          ProductProfileId.liteReceiver,
        );
        expect(profile.legacyReceiverModeRecommended, isTrue);
        expect(profile.supported, isTrue);
      },
    );

    test('marks missing baseline requirements unsupported', () {
      final profile = policy.evaluate(
        signals: _signals(
          signalId: 'blocked-tv',
          apiLevel: 25,
          decoderCount: 0,
          supportedCodecs: const {
            MediaCodecCapability.h264,
            MediaCodecCapability.aac,
          },
          remoteInputs: const {AiroRuntimeRemoteInput.mediaKeys},
          hasSecureStorage: false,
        ),
        now: capturedAt,
      );

      expect(profile.supportTier, AiroRuntimeSupportTier.unsupported);
      expect(profile.supported, isFalse);
      expect(profile.legacyReceiverModeRecommended, isFalse);
      expect(
        profile.constraints,
        containsAll(const {
          AiroRuntimeConstraintCode.apiBelowBaseline,
          AiroRuntimeConstraintCode.decoderCountLow,
          AiroRuntimeConstraintCode.requiredCodecMissing,
          AiroRuntimeConstraintCode.remoteInputMissing,
          AiroRuntimeConstraintCode.secureStorageMissing,
        }),
      );
    });

    test(
      'runtime pressure reclassifies a strong TV into Legacy Receiver Mode',
      () {
        final profile = policy.evaluate(
          signals: _signals(
            signalId: 'pressured-tv',
            apiLevel: 31,
            memoryMb: 4096,
            freeStorageMb: 2048,
            gpuClass: AiroRuntimeGpuClass.accelerated,
            decoderCount: 3,
            memoryPressure: AiroRuntimePressureLevel.high,
            networkClass: AiroRuntimeNetworkClass.weakWifi,
            decoderFailureCount: 3,
          ),
          now: capturedAt,
        );

        expect(profile.supportTier, AiroRuntimeSupportTier.legacyOptimized);
        expect(profile.legacyReceiverModeRecommended, isTrue);
        expect(
          profile.constraints,
          containsAll(const {
            AiroRuntimeConstraintCode.memoryLow,
            AiroRuntimeConstraintCode.networkConstrained,
            AiroRuntimeConstraintCode.decoderFailurePressure,
          }),
        );
      },
    );

    test('critical pressure blocks support', () {
      final profile = policy.evaluate(
        signals: _signals(
          signalId: 'critical-tv',
          apiLevel: 31,
          memoryMb: 4096,
          freeStorageMb: 2048,
          gpuClass: AiroRuntimeGpuClass.accelerated,
          decoderCount: 3,
          thermalPressure: AiroRuntimePressureLevel.critical,
        ),
        now: capturedAt,
      );

      expect(profile.supportTier, AiroRuntimeSupportTier.unsupported);
      expect(
        profile.constraints,
        contains(AiroRuntimeConstraintCode.thermalPressure),
      );
    });

    test('stale security patch requires restricted receiver trust', () {
      final profile = policy.evaluate(
        signals: _signals(
          signalId: 'stale-patch-tv',
          securityPatchAgeDays: 500,
        ),
        now: capturedAt,
      );

      expect(profile.supportTier, AiroRuntimeSupportTier.legacyOptimized);
      expect(profile.restrictedReceiverTrustRequired, isTrue);
      expect(
        profile.constraints,
        containsAll(const {
          AiroRuntimeConstraintCode.securityPatchStale,
          AiroRuntimeConstraintCode.restrictedTrustRequired,
        }),
      );
      expect(
        profile.signals.toDeviceCapabilitySnapshot().requiresRestrictedTrust,
        isTrue,
      );
    });
  });

  group('runtime device profilers', () {
    test('fake profiler delegates to the policy', () async {
      final profiler = AiroFakeRuntimeDeviceProfiler(
        signals: _signals(signalId: 'fake-tv'),
        policy: policy,
      );

      final profile = await profiler.profile(now: capturedAt);

      expect(profile.profileId, 'runtime-fake-tv');
      expect(profile.supportTier, AiroRuntimeSupportTier.fullySupported);
    });

    test('no-op profiler returns deterministic unsupported profile', () async {
      const profiler = AiroNoOpRuntimeDeviceProfiler();

      final profile = await profiler.profile(now: capturedAt);

      expect(profile.supportTier, AiroRuntimeSupportTier.unsupported);
      expect(
        profile.recommendedProductProfile,
        ProductProfileId.embeddedReceiver,
      );
      expect(profile.constraints, const [
        AiroRuntimeConstraintCode.profilerUnavailable,
      ]);
    });
  });
}

AiroRuntimeDeviceSignals _signals({
  required String signalId,
  int apiLevel = 30,
  int memoryMb = 3072,
  int freeStorageMb = 1024,
  AiroRuntimeGpuClass gpuClass = AiroRuntimeGpuClass.standard,
  int decoderCount = 2,
  Set<MediaCodecCapability> supportedCodecs = const {
    MediaCodecCapability.h264,
    MediaCodecCapability.aac,
    MediaCodecCapability.hls,
  },
  Set<AiroRuntimeRemoteInput> remoteInputs = const {
    AiroRuntimeRemoteInput.dpad,
  },
  AiroRuntimeNetworkClass networkClass = AiroRuntimeNetworkClass.stableWifi,
  AiroRuntimePressureLevel memoryPressure = AiroRuntimePressureLevel.normal,
  AiroRuntimePressureLevel storagePressure = AiroRuntimePressureLevel.normal,
  AiroRuntimePressureLevel thermalPressure = AiroRuntimePressureLevel.normal,
  int decoderFailureCount = 0,
  bool hasSecureStorage = true,
  int securityPatchAgeDays = 30,
}) {
  return AiroRuntimeDeviceSignals(
    signalId: signalId,
    platformCategory: AiroNodePlatformCategory.androidTv,
    apiLevel: apiLevel,
    memoryMb: memoryMb,
    freeStorageMb: freeStorageMb,
    gpuClass: gpuClass,
    decoderCount: decoderCount,
    supportedCodecs: supportedCodecs,
    remoteInputs: remoteInputs,
    networkClass: networkClass,
    memoryPressure: memoryPressure,
    storagePressure: storagePressure,
    thermalPressure: thermalPressure,
    decoderFailureCount: decoderFailureCount,
    hasSecureStorage: hasSecureStorage,
    securityPatchAgeDays: securityPatchAgeDays,
  );
}
