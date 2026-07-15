import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';
import 'package:product_capabilities/product_capabilities.dart';

const String kAiroRuntimeDeviceProfileSchemaVersion = '1.0.0';
const int kAiroRuntimeDeviceProfileBaselineAndroidApi = 26;

enum AiroRuntimeSupportTier {
  fullySupported('fully_supported'),
  legacyOptimized('legacy_optimized'),
  experimental('experimental'),
  unsupported('unsupported');

  const AiroRuntimeSupportTier(this.stableId);

  final String stableId;
}

enum AiroRuntimeGpuClass {
  unknown('unknown'),
  basic2d('basic_2d'),
  standard('standard'),
  accelerated('accelerated'),
  constrained('constrained');

  const AiroRuntimeGpuClass(this.stableId);

  final String stableId;
}

enum AiroRuntimeNetworkClass {
  unavailable('unavailable'),
  weakWifi('weak_wifi'),
  constrainedWifi('constrained_wifi'),
  stableWifi('stable_wifi'),
  ethernet('ethernet');

  const AiroRuntimeNetworkClass(this.stableId);

  final String stableId;
}

enum AiroRuntimeRemoteInput {
  dpad('dpad'),
  mediaKeys('media_keys'),
  channelKeys('channel_keys'),
  voiceKey('voice_key'),
  pointer('pointer');

  const AiroRuntimeRemoteInput(this.stableId);

  final String stableId;
}

enum AiroRuntimePressureLevel {
  normal('normal'),
  elevated('elevated'),
  high('high'),
  critical('critical');

  const AiroRuntimePressureLevel(this.stableId);

  final String stableId;

  bool get forcesLegacy => this == high || this == critical;
  bool get blocksSupport => this == critical;
}

enum AiroRuntimeConstraintCode {
  accepted('accepted'),
  apiBelowBaseline('api_below_baseline'),
  memoryLow('memory_low'),
  storageLow('storage_low'),
  gpuConstrained('gpu_constrained'),
  decoderCountLow('decoder_count_low'),
  decoderFailurePressure('decoder_failure_pressure'),
  requiredCodecMissing('required_codec_missing'),
  networkConstrained('network_constrained'),
  remoteInputMissing('remote_input_missing'),
  thermalPressure('thermal_pressure'),
  secureStorageMissing('secure_storage_missing'),
  securityPatchStale('security_patch_stale'),
  restrictedTrustRequired('restricted_trust_required'),
  profilerUnavailable('profiler_unavailable');

  const AiroRuntimeConstraintCode(this.stableId);

  final String stableId;
}

class AiroRuntimeDeviceSignals extends Equatable {
  AiroRuntimeDeviceSignals({
    required this.signalId,
    required this.platformCategory,
    required this.apiLevel,
    required this.memoryMb,
    required this.freeStorageMb,
    required this.gpuClass,
    required this.decoderCount,
    required Set<MediaCodecCapability> supportedCodecs,
    required Set<AiroRuntimeRemoteInput> remoteInputs,
    required this.networkClass,
    this.memoryPressure = AiroRuntimePressureLevel.normal,
    this.storagePressure = AiroRuntimePressureLevel.normal,
    this.thermalPressure = AiroRuntimePressureLevel.normal,
    this.decoderFailureCount = 0,
    this.hasSecureStorage = true,
    this.securityPatchAgeDays = 0,
    this.schemaVersion = kAiroRuntimeDeviceProfileSchemaVersion,
  }) : supportedCodecs = Set.unmodifiable(supportedCodecs),
       remoteInputs = Set.unmodifiable(remoteInputs);

  final String schemaVersion;
  final String signalId;
  final AiroNodePlatformCategory platformCategory;
  final int apiLevel;
  final int memoryMb;
  final int freeStorageMb;
  final AiroRuntimeGpuClass gpuClass;
  final int decoderCount;
  final Set<MediaCodecCapability> supportedCodecs;
  final Set<AiroRuntimeRemoteInput> remoteInputs;
  final AiroRuntimeNetworkClass networkClass;
  final AiroRuntimePressureLevel memoryPressure;
  final AiroRuntimePressureLevel storagePressure;
  final AiroRuntimePressureLevel thermalPressure;
  final int decoderFailureCount;
  final bool hasSecureStorage;
  final int securityPatchAgeDays;

  DeviceCapabilitySnapshot toDeviceCapabilitySnapshot() {
    return DeviceCapabilitySnapshot(
      apiLevel: apiLevel,
      memoryMb: memoryMb,
      freeStorageMb: freeStorageMb,
      decoderCount: decoderCount,
      supportedCodecs: supportedCodecs,
      hasDpad: remoteInputs.contains(AiroRuntimeRemoteInput.dpad),
      hasSecureStorage: hasSecureStorage,
      requiresRestrictedTrust: securityPatchAgeDays > 365,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'signalId': signalId,
      'platformCategory': platformCategory.stableId,
      'apiLevel': apiLevel,
      'memoryMb': memoryMb,
      'freeStorageMb': freeStorageMb,
      'gpuClass': gpuClass.stableId,
      'decoderCount': decoderCount,
      'supportedCodecs': supportedCodecs
          .map((codec) => codec.stableId)
          .toList(growable: false),
      'remoteInputs': remoteInputs
          .map((input) => input.stableId)
          .toList(growable: false),
      'networkClass': networkClass.stableId,
      'memoryPressure': memoryPressure.stableId,
      'storagePressure': storagePressure.stableId,
      'thermalPressure': thermalPressure.stableId,
      'decoderFailureCount': decoderFailureCount,
      'hasSecureStorage': hasSecureStorage,
      'securityPatchAgeDays': securityPatchAgeDays,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    signalId,
    platformCategory,
    apiLevel,
    memoryMb,
    freeStorageMb,
    gpuClass,
    decoderCount,
    supportedCodecs,
    remoteInputs,
    networkClass,
    memoryPressure,
    storagePressure,
    thermalPressure,
    decoderFailureCount,
    hasSecureStorage,
    securityPatchAgeDays,
  ];
}

class AiroRuntimeDeviceProfile extends Equatable {
  AiroRuntimeDeviceProfile({
    required this.profileId,
    required this.signals,
    required this.supportTier,
    required this.recommendedProductProfile,
    required Iterable<AiroRuntimeConstraintCode> constraints,
    required this.capturedAt,
    this.legacyReceiverModeRecommended = false,
    this.restrictedReceiverTrustRequired = false,
    this.schemaVersion = kAiroRuntimeDeviceProfileSchemaVersion,
  }) : constraints = List.unmodifiable(constraints);

  final String schemaVersion;
  final String profileId;
  final AiroRuntimeDeviceSignals signals;
  final AiroRuntimeSupportTier supportTier;
  final ProductProfileId recommendedProductProfile;
  final bool legacyReceiverModeRecommended;
  final bool restrictedReceiverTrustRequired;
  final List<AiroRuntimeConstraintCode> constraints;
  final DateTime capturedAt;

  bool get supported => supportTier != AiroRuntimeSupportTier.unsupported;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'signalId': signals.signalId,
      'platformCategory': signals.platformCategory.stableId,
      'supportTier': supportTier.stableId,
      'recommendedProductProfile': recommendedProductProfile.stableId,
      'legacyReceiverModeRecommended': legacyReceiverModeRecommended,
      'restrictedReceiverTrustRequired': restrictedReceiverTrustRequired,
      'constraints': constraints
          .map((constraint) => constraint.stableId)
          .toList(growable: false),
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AiroRuntimeDeviceProfile('
        'profileId: $profileId, '
        'supportTier: ${supportTier.stableId}, '
        'recommendedProductProfile: ${recommendedProductProfile.stableId}, '
        'legacyReceiverModeRecommended: $legacyReceiverModeRecommended'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    signals,
    supportTier,
    recommendedProductProfile,
    legacyReceiverModeRecommended,
    restrictedReceiverTrustRequired,
    constraints,
    capturedAt,
  ];
}

class AiroRuntimeDeviceProfilePolicy extends Equatable {
  AiroRuntimeDeviceProfilePolicy({
    Set<MediaCodecCapability> baselineCodecs = const {
      MediaCodecCapability.h264,
      MediaCodecCapability.aac,
      MediaCodecCapability.hls,
    },
    this.baselineApiLevel = kAiroRuntimeDeviceProfileBaselineAndroidApi,
    this.fullMemoryMb = 2048,
    this.legacyMemoryMb = 1024,
    this.fullFreeStorageMb = 512,
    this.legacyFreeStorageMb = 128,
    this.maxSecurityPatchAgeDays = 365,
    this.maxLegacyDecoderFailures = 2,
  }) : baselineCodecs = Set.unmodifiable(baselineCodecs);

  final Set<MediaCodecCapability> baselineCodecs;
  final int baselineApiLevel;
  final int fullMemoryMb;
  final int legacyMemoryMb;
  final int fullFreeStorageMb;
  final int legacyFreeStorageMb;
  final int maxSecurityPatchAgeDays;
  final int maxLegacyDecoderFailures;

  AiroRuntimeDeviceProfile evaluate({
    required AiroRuntimeDeviceSignals signals,
    required DateTime now,
  }) {
    final constraints = <AiroRuntimeConstraintCode>[];
    _addBaselineConstraints(signals, constraints);
    _addPressureConstraints(signals, constraints);

    final supportTier = _supportTierFor(signals, constraints);
    final productProfile = _productProfileFor(supportTier);
    final legacyMode = _legacyModeFor(signals, supportTier, constraints);
    final restrictedTrust =
        constraints.contains(AiroRuntimeConstraintCode.securityPatchStale) ||
        signals.securityPatchAgeDays > maxSecurityPatchAgeDays;

    final effectiveConstraints = constraints.isEmpty
        ? const [AiroRuntimeConstraintCode.accepted]
        : List<AiroRuntimeConstraintCode>.unmodifiable({...constraints});

    return AiroRuntimeDeviceProfile(
      profileId: 'runtime-${signals.signalId}',
      signals: signals,
      supportTier: supportTier,
      recommendedProductProfile: productProfile,
      legacyReceiverModeRecommended: legacyMode,
      restrictedReceiverTrustRequired: restrictedTrust,
      constraints: effectiveConstraints,
      capturedAt: now,
    );
  }

  void _addBaselineConstraints(
    AiroRuntimeDeviceSignals signals,
    List<AiroRuntimeConstraintCode> constraints,
  ) {
    if (signals.apiLevel < baselineApiLevel) {
      constraints.add(AiroRuntimeConstraintCode.apiBelowBaseline);
    }
    if (signals.memoryMb < legacyMemoryMb) {
      constraints.add(AiroRuntimeConstraintCode.memoryLow);
    }
    if (signals.freeStorageMb < legacyFreeStorageMb) {
      constraints.add(AiroRuntimeConstraintCode.storageLow);
    }
    if (signals.gpuClass == AiroRuntimeGpuClass.constrained) {
      constraints.add(AiroRuntimeConstraintCode.gpuConstrained);
    }
    if (signals.decoderCount < 1) {
      constraints.add(AiroRuntimeConstraintCode.decoderCountLow);
    }
    if (!signals.supportedCodecs.containsAll(baselineCodecs)) {
      constraints.add(AiroRuntimeConstraintCode.requiredCodecMissing);
    }
    if (!signals.remoteInputs.contains(AiroRuntimeRemoteInput.dpad)) {
      constraints.add(AiroRuntimeConstraintCode.remoteInputMissing);
    }
    if (!signals.hasSecureStorage) {
      constraints.add(AiroRuntimeConstraintCode.secureStorageMissing);
    }
    if (signals.securityPatchAgeDays > maxSecurityPatchAgeDays) {
      constraints.add(AiroRuntimeConstraintCode.securityPatchStale);
      constraints.add(AiroRuntimeConstraintCode.restrictedTrustRequired);
    }
  }

  void _addPressureConstraints(
    AiroRuntimeDeviceSignals signals,
    List<AiroRuntimeConstraintCode> constraints,
  ) {
    if (signals.memoryPressure.forcesLegacy) {
      constraints.add(AiroRuntimeConstraintCode.memoryLow);
    }
    if (signals.storagePressure.forcesLegacy) {
      constraints.add(AiroRuntimeConstraintCode.storageLow);
    }
    if (signals.thermalPressure.forcesLegacy) {
      constraints.add(AiroRuntimeConstraintCode.thermalPressure);
    }
    if (signals.networkClass == AiroRuntimeNetworkClass.unavailable ||
        signals.networkClass == AiroRuntimeNetworkClass.weakWifi) {
      constraints.add(AiroRuntimeConstraintCode.networkConstrained);
    }
    if (signals.decoderFailureCount > maxLegacyDecoderFailures) {
      constraints.add(AiroRuntimeConstraintCode.decoderFailurePressure);
    }
  }

  AiroRuntimeSupportTier _supportTierFor(
    AiroRuntimeDeviceSignals signals,
    List<AiroRuntimeConstraintCode> constraints,
  ) {
    if (_hasUnsupportedConstraint(constraints) ||
        signals.memoryPressure.blocksSupport ||
        signals.storagePressure.blocksSupport ||
        signals.thermalPressure.blocksSupport) {
      return AiroRuntimeSupportTier.unsupported;
    }
    if (signals.apiLevel == baselineApiLevel ||
        signals.memoryMb < fullMemoryMb ||
        signals.freeStorageMb < fullFreeStorageMb ||
        signals.gpuClass == AiroRuntimeGpuClass.basic2d ||
        signals.gpuClass == AiroRuntimeGpuClass.unknown ||
        constraints.isNotEmpty) {
      return AiroRuntimeSupportTier.legacyOptimized;
    }
    return AiroRuntimeSupportTier.fullySupported;
  }

  bool _hasUnsupportedConstraint(List<AiroRuntimeConstraintCode> constraints) {
    return constraints.contains(AiroRuntimeConstraintCode.apiBelowBaseline) ||
        constraints.contains(AiroRuntimeConstraintCode.requiredCodecMissing) ||
        constraints.contains(AiroRuntimeConstraintCode.remoteInputMissing) ||
        constraints.contains(AiroRuntimeConstraintCode.secureStorageMissing) ||
        constraints.contains(AiroRuntimeConstraintCode.decoderCountLow);
  }

  ProductProfileId _productProfileFor(AiroRuntimeSupportTier tier) {
    return switch (tier) {
      AiroRuntimeSupportTier.fullySupported => ProductProfileId.fullTv,
      AiroRuntimeSupportTier.legacyOptimized => ProductProfileId.liteReceiver,
      AiroRuntimeSupportTier.experimental =>
        ProductProfileId.experimentalLegacy,
      AiroRuntimeSupportTier.unsupported => ProductProfileId.embeddedReceiver,
    };
  }

  bool _legacyModeFor(
    AiroRuntimeDeviceSignals signals,
    AiroRuntimeSupportTier tier,
    List<AiroRuntimeConstraintCode> constraints,
  ) {
    if (tier == AiroRuntimeSupportTier.unsupported) return false;
    return tier == AiroRuntimeSupportTier.legacyOptimized ||
        signals.memoryPressure.forcesLegacy ||
        signals.storagePressure.forcesLegacy ||
        signals.thermalPressure.forcesLegacy ||
        constraints.contains(AiroRuntimeConstraintCode.networkConstrained) ||
        constraints.contains(AiroRuntimeConstraintCode.decoderFailurePressure);
  }

  @override
  List<Object?> get props => [
    baselineCodecs,
    baselineApiLevel,
    fullMemoryMb,
    legacyMemoryMb,
    fullFreeStorageMb,
    legacyFreeStorageMb,
    maxSecurityPatchAgeDays,
    maxLegacyDecoderFailures,
  ];
}

abstract interface class AiroRuntimeDeviceProfiler {
  Future<AiroRuntimeDeviceProfile> profile({required DateTime now});
}

class AiroNoOpRuntimeDeviceProfiler implements AiroRuntimeDeviceProfiler {
  const AiroNoOpRuntimeDeviceProfiler();

  @override
  Future<AiroRuntimeDeviceProfile> profile({required DateTime now}) async {
    final signals = AiroRuntimeDeviceSignals(
      signalId: 'profiler-unavailable',
      platformCategory: AiroNodePlatformCategory.unknown,
      apiLevel: 0,
      memoryMb: 0,
      freeStorageMb: 0,
      gpuClass: AiroRuntimeGpuClass.unknown,
      decoderCount: 0,
      supportedCodecs: const {},
      remoteInputs: const {},
      networkClass: AiroRuntimeNetworkClass.unavailable,
      hasSecureStorage: false,
    );
    return AiroRuntimeDeviceProfile(
      profileId: 'runtime-profiler-unavailable',
      signals: signals,
      supportTier: AiroRuntimeSupportTier.unsupported,
      recommendedProductProfile: ProductProfileId.embeddedReceiver,
      constraints: const [AiroRuntimeConstraintCode.profilerUnavailable],
      capturedAt: now,
    );
  }
}

class AiroFakeRuntimeDeviceProfiler implements AiroRuntimeDeviceProfiler {
  AiroFakeRuntimeDeviceProfiler({
    required this.signals,
    AiroRuntimeDeviceProfilePolicy? policy,
  }) : policy = policy ?? AiroRuntimeDeviceProfilePolicy();

  final AiroRuntimeDeviceSignals signals;
  final AiroRuntimeDeviceProfilePolicy policy;

  @override
  Future<AiroRuntimeDeviceProfile> profile({required DateTime now}) async {
    return policy.evaluate(signals: signals, now: now);
  }
}
