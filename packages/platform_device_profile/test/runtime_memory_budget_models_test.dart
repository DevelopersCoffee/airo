import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';
import 'package:product_capabilities/product_capabilities.dart';

void main() {
  const policy = AiroRuntimeMemoryBudgetPolicy();
  final sampledAt = DateTime.utc(2026, 7, 15, 10);
  final profilePolicy = AiroRuntimeDeviceProfilePolicy();

  group('AiroRuntimeMemoryBudgetPolicy', () {
    test('maps 1 GB legacy Android TV to constrained budget', () {
      final profile = profilePolicy.evaluate(
        signals: _signals(
          signalId: 'one-gb-tv',
          memoryMb: 1024,
          apiLevel: 26,
          gpuClass: AiroRuntimeGpuClass.basic2d,
          freeStorageMb: 128,
        ),
        now: sampledAt,
      );

      final budget = policy.budgetForProfile(profile);

      expect(budget.budgetClass, AiroRuntimeMemoryBudgetClass.constrainedTv1gb);
      expect(budget.maxSteadyRssMb, 250);
      expect(budget.maxPeakRssMb, 350);
      expect(budget.imageCacheMb, 16);
      expect(budget.maxRetainedChannelListCopies, 2);
      expect(budget.maxPlaybackSoakDriftMbPerHour, 1);
    });

    test('maps 2 GB Android TV to standard budget', () {
      final budget = policy.budgetForSignals(
        _signals(signalId: 'two-gb-tv', memoryMb: 2048),
      );

      expect(budget.budgetClass, AiroRuntimeMemoryBudgetClass.standardTv2gb);
      expect(budget.maxSteadyRssMb, 384);
      expect(budget.maxPeakRssMb, 512);
      expect(budget.imageCacheMb, 32);
    });

    test('maps 3 GB plus Android TV to expanded budget', () {
      final budget = policy.budgetForSignals(
        _signals(signalId: 'three-gb-tv', memoryMb: 3072),
      );

      expect(
        budget.budgetClass,
        AiroRuntimeMemoryBudgetClass.expandedTv3gbPlus,
      );
      expect(budget.maxSteadyRssMb, 512);
      expect(budget.maxPeakRssMb, 768);
      expect(budget.imageCacheMb, 64);
    });

    test('high memory pressure forces constrained budget', () {
      final budget = policy.budgetForSignals(
        _signals(
          signalId: 'pressured-four-gb-tv',
          memoryMb: 4096,
          memoryPressure: AiroRuntimePressureLevel.high,
        ),
      );

      expect(budget.budgetClass, AiroRuntimeMemoryBudgetClass.constrainedTv1gb);
      expect(budget.supportTier, AiroRuntimeSupportTier.legacyOptimized);
    });

    test('critical pressure or sub-1 GB memory returns unsupported budget', () {
      final criticalBudget = policy.budgetForSignals(
        _signals(
          signalId: 'critical-tv',
          memoryMb: 4096,
          memoryPressure: AiroRuntimePressureLevel.critical,
        ),
      );
      final subGigBudget = policy.budgetForSignals(
        _signals(signalId: 'sub-gig-tv', memoryMb: 768),
      );

      expect(
        criticalBudget.budgetClass,
        AiroRuntimeMemoryBudgetClass.unsupported,
      );
      expect(
        subGigBudget.budgetClass,
        AiroRuntimeMemoryBudgetClass.unsupported,
      );
    });

    test('accepts samples inside the selected budget', () {
      final budget = policy.budgetForSignals(
        _signals(signalId: 'inside-budget-tv', memoryMb: 1024),
      );
      final evaluation = policy.evaluate(
        budget: budget,
        sample: _sample(
          sampledAt: sampledAt,
          steadyRssMb: 200,
          peakRssMb: 320,
          dartHeapMb: 100,
          imageCacheMb: 12,
          retainedChannelListCopies: 2,
          playbackSoakDriftMbPerHour: 0.5,
        ),
      );

      expect(evaluation.accepted, isTrue);
      expect(evaluation.violations, const [
        AiroRuntimeMemoryBudgetViolationCode.accepted,
      ]);
    });

    test('rejects samples that exceed measured budget ceilings', () {
      final budget = policy.budgetForSignals(
        _signals(signalId: 'over-budget-tv', memoryMb: 1024),
      );
      final evaluation = policy.evaluate(
        budget: budget,
        sample: _sample(
          sampledAt: sampledAt,
          steadyRssMb: 251,
          peakRssMb: 351,
          dartHeapMb: 129,
          imageCacheMb: 17,
          retainedChannelListCopies: 3,
          playbackSoakDriftMbPerHour: 1.1,
        ),
      );

      expect(evaluation.accepted, isFalse);
      expect(
        evaluation.violations,
        containsAll(const {
          AiroRuntimeMemoryBudgetViolationCode.steadyRssExceeded,
          AiroRuntimeMemoryBudgetViolationCode.peakRssExceeded,
          AiroRuntimeMemoryBudgetViolationCode.dartHeapExceeded,
          AiroRuntimeMemoryBudgetViolationCode.imageCacheExceeded,
          AiroRuntimeMemoryBudgetViolationCode
              .retainedChannelListCopiesExceeded,
          AiroRuntimeMemoryBudgetViolationCode.playbackSoakDriftExceeded,
        }),
      );
    });

    test('public maps expose stable contract fields only', () {
      final budget = policy.budgetForSignals(
        _signals(signalId: 'public-map-tv', memoryMb: 2048),
      );
      final sample = _sample(sampledAt: sampledAt);
      final evaluation = policy.evaluate(budget: budget, sample: sample);

      expect(budget.toPublicMap(), isNot(contains('rawModel')));
      expect(sample.toPublicMap(), isNot(contains('dumpsys')));
      expect(evaluation.toPublicMap(), containsPair('accepted', true));
      expect(
        budget.toPublicMap(),
        containsPair('schemaVersion', kAiroRuntimeMemoryBudgetSchemaVersion),
      );
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
  );
}

AiroRuntimeMemorySample _sample({
  required DateTime sampledAt,
  int steadyRssMb = 200,
  int peakRssMb = 300,
  int dartHeapMb = 100,
  int imageCacheMb = 12,
  int retainedChannelListCopies = 1,
  double playbackSoakDriftMbPerHour = 0.2,
}) {
  return AiroRuntimeMemorySample(
    sampleId: 'sample-${sampledAt.toIso8601String()}',
    steadyRssMb: steadyRssMb,
    peakRssMb: peakRssMb,
    dartHeapMb: dartHeapMb,
    imageCacheMb: imageCacheMb,
    retainedChannelListCopies: retainedChannelListCopies,
    playbackSoakDriftMbPerHour: playbackSoakDriftMbPerHour,
    sampledAt: sampledAt,
  );
}
