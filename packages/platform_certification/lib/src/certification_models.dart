import 'package:equatable/equatable.dart';

const String kAiroCertificationSchemaVersion = '1.0.0';
const String kAiroValidationSchemaVersion = '1.0.0';

enum AiroCertificationLevel {
  certified('certified'),
  compatible('compatible'),
  experimental('experimental'),
  unsupported('unsupported');

  const AiroCertificationLevel(this.stableId);

  final String stableId;
}

enum AiroCertificationTargetKind {
  androidTvApi26('android_tv_api_26'),
  androidTvApi28('android_tv_api_28'),
  fireTvLegacy('fire_tv_legacy'),
  aospTvBox('aosp_tv_box'),
  lowerApiExperimental('lower_api_experimental');

  const AiroCertificationTargetKind(this.stableId);

  final String stableId;
}

enum AiroCertificationGateId {
  installLaunch('install_launch'),
  dpadFocus('dpad_focus'),
  playbackBaseline('playback_baseline'),
  subtitleRendering('subtitle_rendering'),
  pairingFlow('pairing_flow'),
  compactEpg('compact_epg'),
  memoryPressure('memory_pressure'),
  lowStorage('low_storage'),
  sleepWake('sleep_wake'),
  thermalStability('thermal_stability'),
  credentialPreservation('credential_preservation'),
  packageContentScan('package_content_scan'),
  dependencyBaseline('dependency_baseline');

  const AiroCertificationGateId(this.stableId);

  final String stableId;
}

enum AiroCertificationEvidenceKind {
  physicalDeviceRun('physical_device_run'),
  hostStaticScan('host_static_scan'),
  benchmarkTrace('benchmark_trace'),
  manualChecklist('manual_checklist'),
  mediaFixtureRun('media_fixture_run'),
  releaseConfigReview('release_config_review');

  const AiroCertificationEvidenceKind(this.stableId);

  final String stableId;
}

enum AiroCertificationBlockerCode {
  targetMissing('target_missing'),
  unsupportedTarget('unsupported_target'),
  gateMissing('gate_missing'),
  evidenceMissing('evidence_missing'),
  evidenceWrongTarget('evidence_wrong_target'),
  evidenceWrongKind('evidence_wrong_kind'),
  evidenceStale('evidence_stale');

  const AiroCertificationBlockerCode(this.stableId);

  final String stableId;
}

enum AiroValidationPlatform {
  androidMobile('android_mobile'),
  androidTv('android_tv'),
  fireTv('fire_tv'),
  ios('ios'),
  ipados('ipados'),
  desktop('desktop'),
  tvos('tvos'),
  webEmbeddedReceiver('web_embedded_receiver'),
  backendCloud('backend_cloud');

  const AiroValidationPlatform(this.stableId);

  final String stableId;
}

enum AiroValidationProductProfile {
  fullTv('full_tv'),
  liteReceiver('lite_receiver'),
  companion('companion'),
  desktopCompanion('desktop_companion'),
  embeddedReceiver('embedded_receiver'),
  backendControlPlane('backend_control_plane');

  const AiroValidationProductProfile(this.stableId);

  final String stableId;
}

enum AiroValidationReleasePhase {
  platformFoundation('platform_foundation'),
  connectedDevice('connected_device'),
  mediaRouting('media_routing'),
  legacyDevice('legacy_device'),
  cloudBoundary('cloud_boundary'),
  storeReadiness('store_readiness');

  const AiroValidationReleasePhase(this.stableId);

  final String stableId;
}

enum AiroValidationStatus {
  required('required'),
  optional('optional'),
  blocked('blocked');

  const AiroValidationStatus(this.stableId);

  final String stableId;
}

enum AiroValidationGateId {
  productCapabilities('product_capabilities'),
  adaptiveUi('adaptive_ui'),
  remoteFocus('remote_focus'),
  touchInput('touch_input'),
  pointerInput('pointer_input'),
  playbackEngine('playback_engine'),
  mediaRouting('media_routing'),
  pairingController('pairing_controller'),
  sessionSync('session_sync'),
  analyticsRedaction('analytics_redaction'),
  dependencyGovernance('dependency_governance'),
  packageContentScan('package_content_scan'),
  localNetworkPrivacy('local_network_privacy'),
  importExportDataGovernance('import_export_data_governance'),
  accessibility('accessibility'),
  nativeTarget('native_target'),
  storePolicy('store_policy'),
  orchestrationStorage('orchestration_storage'),
  cloudPrivacy('cloud_privacy'),
  physicalDeviceEvidence('physical_device_evidence');

  const AiroValidationGateId(this.stableId);

  final String stableId;
}

enum AiroValidationEvidenceTier {
  hostAutomation('host_automation'),
  physicalDevice('physical_device'),
  manualReview('manual_review'),
  storeReview('store_review'),
  securityPrivacyReview('security_privacy_review'),
  releaseConfigReview('release_config_review'),
  cloudContract('cloud_contract');

  const AiroValidationEvidenceTier(this.stableId);

  final String stableId;
}

class AiroCertificationGate extends Equatable {
  AiroCertificationGate({
    required this.gateId,
    required this.displayName,
    required this.description,
    required Set<AiroCertificationEvidenceKind> acceptedEvidenceKinds,
    this.requiresPhysicalDevice = true,
    this.maxEvidenceAge = const Duration(days: 14),
    this.schemaVersion = kAiroCertificationSchemaVersion,
  }) : acceptedEvidenceKinds = Set.unmodifiable(acceptedEvidenceKinds);

  final String schemaVersion;
  final AiroCertificationGateId gateId;
  final String displayName;
  final String description;
  final Set<AiroCertificationEvidenceKind> acceptedEvidenceKinds;
  final bool requiresPhysicalDevice;
  final Duration maxEvidenceAge;

  bool accepts(AiroCertificationEvidenceKind evidenceKind) =>
      acceptedEvidenceKinds.contains(evidenceKind);

  @override
  List<Object?> get props => [
    schemaVersion,
    gateId,
    displayName,
    description,
    acceptedEvidenceKinds,
    requiresPhysicalDevice,
    maxEvidenceAge,
  ];
}

class AiroCertificationTarget extends Equatable {
  AiroCertificationTarget({
    required this.targetId,
    required this.displayName,
    required this.kind,
    required this.minimumLevel,
    required Set<AiroCertificationGateId> requiredGates,
    required this.minAndroidApi,
    this.maxAndroidApi,
    this.minMemoryMb,
    this.minStorageMb,
    List<String> notes = const [],
    this.schemaVersion = kAiroCertificationSchemaVersion,
  }) : requiredGates = Set.unmodifiable(requiredGates),
       notes = List.unmodifiable(notes);

  final String schemaVersion;
  final String targetId;
  final String displayName;
  final AiroCertificationTargetKind kind;
  final AiroCertificationLevel minimumLevel;
  final Set<AiroCertificationGateId> requiredGates;
  final int minAndroidApi;
  final int? maxAndroidApi;
  final int? minMemoryMb;
  final int? minStorageMb;
  final List<String> notes;

  bool get canAdvertiseSupport =>
      minimumLevel == AiroCertificationLevel.certified ||
      minimumLevel == AiroCertificationLevel.compatible;

  @override
  List<Object?> get props => [
    schemaVersion,
    targetId,
    displayName,
    kind,
    minimumLevel,
    requiredGates,
    minAndroidApi,
    maxAndroidApi,
    minMemoryMb,
    minStorageMb,
    notes,
  ];
}

class AiroCertificationEvidence extends Equatable {
  const AiroCertificationEvidence({
    required this.evidenceId,
    required this.targetId,
    required this.gateId,
    required this.kind,
    required this.capturedAt,
    required this.passed,
    this.summary,
    this.schemaVersion = kAiroCertificationSchemaVersion,
  });

  final String schemaVersion;
  final String evidenceId;
  final String targetId;
  final AiroCertificationGateId gateId;
  final AiroCertificationEvidenceKind kind;
  final DateTime capturedAt;
  final bool passed;
  final String? summary;

  @override
  List<Object?> get props => [
    schemaVersion,
    evidenceId,
    targetId,
    gateId,
    kind,
    capturedAt,
    passed,
    summary,
  ];
}

class AiroCertificationBlocker extends Equatable {
  const AiroCertificationBlocker({
    required this.code,
    required this.targetId,
    this.gateId,
  });

  final AiroCertificationBlockerCode code;
  final String targetId;
  final AiroCertificationGateId? gateId;

  @override
  List<Object?> get props => [code, targetId, gateId];
}

class AiroCertificationResult extends Equatable {
  AiroCertificationResult({
    required this.targetId,
    required this.claimedLevel,
    required List<AiroCertificationBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String targetId;
  final AiroCertificationLevel claimedLevel;
  final List<AiroCertificationBlocker> blockers;

  bool get passed => blockers.isEmpty;

  bool get canAdvertiseSupport =>
      passed &&
      (claimedLevel == AiroCertificationLevel.certified ||
          claimedLevel == AiroCertificationLevel.compatible);

  @override
  List<Object?> get props => [targetId, claimedLevel, blockers];
}

class AiroCertificationMatrix extends Equatable {
  AiroCertificationMatrix({
    required Iterable<AiroCertificationTarget> targets,
    required Iterable<AiroCertificationGate> gates,
    this.schemaVersion = kAiroCertificationSchemaVersion,
  }) : targets = List.unmodifiable(targets),
       gates = List.unmodifiable(gates);

  final String schemaVersion;
  final List<AiroCertificationTarget> targets;
  final List<AiroCertificationGate> gates;

  AiroCertificationTarget? targetById(String targetId) {
    for (final target in targets) {
      if (target.targetId == targetId) return target;
    }
    return null;
  }

  AiroCertificationGate? gateById(AiroCertificationGateId gateId) {
    for (final gate in gates) {
      if (gate.gateId == gateId) return gate;
    }
    return null;
  }

  AiroCertificationResult evaluate({
    required String targetId,
    required Iterable<AiroCertificationEvidence> evidence,
    required DateTime now,
  }) {
    final target = targetById(targetId);
    if (target == null) {
      return AiroCertificationResult(
        targetId: targetId,
        claimedLevel: AiroCertificationLevel.unsupported,
        blockers: [
          AiroCertificationBlocker(
            code: AiroCertificationBlockerCode.targetMissing,
            targetId: targetId,
          ),
        ],
      );
    }
    if (target.minimumLevel == AiroCertificationLevel.unsupported) {
      return AiroCertificationResult(
        targetId: targetId,
        claimedLevel: target.minimumLevel,
        blockers: [
          AiroCertificationBlocker(
            code: AiroCertificationBlockerCode.unsupportedTarget,
            targetId: targetId,
          ),
        ],
      );
    }

    final blockers = <AiroCertificationBlocker>[];
    final evidenceByGate =
        <AiroCertificationGateId, List<AiroCertificationEvidence>>{};
    for (final record in evidence.where((record) => record.passed)) {
      evidenceByGate.putIfAbsent(record.gateId, () => []).add(record);
    }

    for (final gateId in target.requiredGates) {
      final gate = gateById(gateId);
      if (gate == null) {
        blockers.add(
          AiroCertificationBlocker(
            code: AiroCertificationBlockerCode.gateMissing,
            targetId: targetId,
            gateId: gateId,
          ),
        );
        continue;
      }

      final records = evidenceByGate[gateId] ?? const [];
      if (records.isEmpty) {
        blockers.add(
          AiroCertificationBlocker(
            code: AiroCertificationBlockerCode.evidenceMissing,
            targetId: targetId,
            gateId: gateId,
          ),
        );
        continue;
      }

      final gateBlocker = _firstGateBlocker(
        targetId: targetId,
        gate: gate,
        records: records,
        now: now,
      );
      if (gateBlocker != null) blockers.add(gateBlocker);
    }

    return AiroCertificationResult(
      targetId: targetId,
      claimedLevel: target.minimumLevel,
      blockers: blockers,
    );
  }

  AiroCertificationBlocker? _firstGateBlocker({
    required String targetId,
    required AiroCertificationGate gate,
    required List<AiroCertificationEvidence> records,
    required DateTime now,
  }) {
    final targetRecords = records.where(
      (record) => record.targetId == targetId,
    );
    if (targetRecords.isEmpty) {
      return AiroCertificationBlocker(
        code: AiroCertificationBlockerCode.evidenceWrongTarget,
        targetId: targetId,
        gateId: gate.gateId,
      );
    }

    final kindRecords = targetRecords.where(
      (record) => gate.accepts(record.kind),
    );
    if (kindRecords.isEmpty) {
      return AiroCertificationBlocker(
        code: AiroCertificationBlockerCode.evidenceWrongKind,
        targetId: targetId,
        gateId: gate.gateId,
      );
    }

    if (gate.requiresPhysicalDevice &&
        !kindRecords.any(
          (record) =>
              record.kind == AiroCertificationEvidenceKind.physicalDeviceRun,
        )) {
      return AiroCertificationBlocker(
        code: AiroCertificationBlockerCode.evidenceWrongKind,
        targetId: targetId,
        gateId: gate.gateId,
      );
    }

    final freshRecords = kindRecords.where(
      (record) => !record.capturedAt.add(gate.maxEvidenceAge).isBefore(now),
    );
    if (freshRecords.isEmpty) {
      return AiroCertificationBlocker(
        code: AiroCertificationBlockerCode.evidenceStale,
        targetId: targetId,
        gateId: gate.gateId,
      );
    }

    return null;
  }

  @override
  List<Object?> get props => [schemaVersion, targets, gates];
}

class AiroValidationGate extends Equatable {
  AiroValidationGate({
    required this.gateId,
    required this.displayName,
    required this.description,
    required Set<AiroValidationEvidenceTier> acceptedEvidenceTiers,
    this.requiresPhysicalDevice = false,
    this.blocksAdvertising = true,
    this.schemaVersion = kAiroValidationSchemaVersion,
  }) : acceptedEvidenceTiers = Set.unmodifiable(acceptedEvidenceTiers);

  final String schemaVersion;
  final AiroValidationGateId gateId;
  final String displayName;
  final String description;
  final Set<AiroValidationEvidenceTier> acceptedEvidenceTiers;
  final bool requiresPhysicalDevice;
  final bool blocksAdvertising;

  bool accepts(AiroValidationEvidenceTier tier) =>
      acceptedEvidenceTiers.contains(tier);

  bool get canBeSatisfiedByHostAutomation =>
      acceptedEvidenceTiers.contains(AiroValidationEvidenceTier.hostAutomation);

  @override
  List<Object?> get props => [
    schemaVersion,
    gateId,
    displayName,
    description,
    acceptedEvidenceTiers,
    requiresPhysicalDevice,
    blocksAdvertising,
  ];
}

class AiroValidationTarget extends Equatable {
  AiroValidationTarget({
    required this.targetId,
    required this.displayName,
    required this.platform,
    required this.productProfile,
    required this.releasePhase,
    required this.status,
    required Set<AiroValidationGateId> requiredGates,
    this.requiresDeviceCertification = false,
    List<String> notes = const [],
    this.schemaVersion = kAiroValidationSchemaVersion,
  }) : requiredGates = Set.unmodifiable(requiredGates),
       notes = List.unmodifiable(notes);

  final String schemaVersion;
  final String targetId;
  final String displayName;
  final AiroValidationPlatform platform;
  final AiroValidationProductProfile productProfile;
  final AiroValidationReleasePhase releasePhase;
  final AiroValidationStatus status;
  final Set<AiroValidationGateId> requiredGates;
  final bool requiresDeviceCertification;
  final List<String> notes;

  bool get isBlocked => status == AiroValidationStatus.blocked;

  @override
  List<Object?> get props => [
    schemaVersion,
    targetId,
    displayName,
    platform,
    productProfile,
    releasePhase,
    status,
    requiredGates,
    requiresDeviceCertification,
    notes,
  ];
}

class AiroCrossPlatformValidationMatrix extends Equatable {
  AiroCrossPlatformValidationMatrix({
    required Iterable<AiroValidationTarget> targets,
    required Iterable<AiroValidationGate> gates,
    this.schemaVersion = kAiroValidationSchemaVersion,
  }) : targets = List.unmodifiable(targets),
       gates = List.unmodifiable(gates);

  final String schemaVersion;
  final List<AiroValidationTarget> targets;
  final List<AiroValidationGate> gates;

  AiroValidationTarget? targetById(String targetId) {
    for (final target in targets) {
      if (target.targetId == targetId) return target;
    }
    return null;
  }

  AiroValidationGate? gateById(AiroValidationGateId gateId) {
    for (final gate in gates) {
      if (gate.gateId == gateId) return gate;
    }
    return null;
  }

  Iterable<AiroValidationGate> gatesForTarget(String targetId) {
    final target = targetById(targetId);
    if (target == null) return const [];
    return target.requiredGates.map(gateById).whereType<AiroValidationGate>();
  }

  Set<AiroValidationGateId> missingGateIdsForTarget(String targetId) {
    final target = targetById(targetId);
    if (target == null) return const {};
    return {
      for (final gateId in target.requiredGates)
        if (gateById(gateId) == null) gateId,
    };
  }

  bool requiresPhysicalEvidence(String targetId) {
    return gatesForTarget(targetId).any((gate) => gate.requiresPhysicalDevice);
  }

  bool canAdvertiseDeviceSupportWithHostOnlyEvidence(String targetId) {
    final target = targetById(targetId);
    if (target == null || target.isBlocked) return false;
    if (!target.requiresDeviceCertification) return false;
    return !gatesForTarget(targetId).any(
      (gate) =>
          gate.blocksAdvertising &&
          !gate.accepts(AiroValidationEvidenceTier.hostAutomation),
    );
  }

  @override
  List<Object?> get props => [schemaVersion, targets, gates];
}

class AiroCrossPlatformValidation {
  const AiroCrossPlatformValidation._();

  static AiroCrossPlatformValidationMatrix matrix() {
    return AiroCrossPlatformValidationMatrix(
      targets: _targets(),
      gates: _gates(),
    );
  }

  static List<AiroValidationTarget> _targets() {
    return [
      AiroValidationTarget(
        targetId: 'android-tv-lite-receiver',
        displayName: 'Android TV Lite Receiver',
        platform: AiroValidationPlatform.androidTv,
        productProfile: AiroValidationProductProfile.liteReceiver,
        releasePhase: AiroValidationReleasePhase.connectedDevice,
        status: AiroValidationStatus.required,
        requiresDeviceCertification: true,
        requiredGates: const {
          AiroValidationGateId.productCapabilities,
          AiroValidationGateId.adaptiveUi,
          AiroValidationGateId.remoteFocus,
          AiroValidationGateId.playbackEngine,
          AiroValidationGateId.mediaRouting,
          AiroValidationGateId.pairingController,
          AiroValidationGateId.sessionSync,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.dependencyGovernance,
          AiroValidationGateId.packageContentScan,
          AiroValidationGateId.accessibility,
          AiroValidationGateId.physicalDeviceEvidence,
        },
        notes: const [
          'Remote-first receiver validation must include physical D-pad evidence.',
          'Validation consumes product capability, adaptive UI, playback, pairing, command, and session contracts.',
        ],
      ),
      AiroValidationTarget(
        targetId: 'fire-tv-lite-receiver',
        displayName: 'Fire TV Lite Receiver',
        platform: AiroValidationPlatform.fireTv,
        productProfile: AiroValidationProductProfile.liteReceiver,
        releasePhase: AiroValidationReleasePhase.legacyDevice,
        status: AiroValidationStatus.required,
        requiresDeviceCertification: true,
        requiredGates: const {
          AiroValidationGateId.productCapabilities,
          AiroValidationGateId.adaptiveUi,
          AiroValidationGateId.remoteFocus,
          AiroValidationGateId.playbackEngine,
          AiroValidationGateId.mediaRouting,
          AiroValidationGateId.pairingController,
          AiroValidationGateId.sessionSync,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.dependencyGovernance,
          AiroValidationGateId.packageContentScan,
          AiroValidationGateId.accessibility,
          AiroValidationGateId.physicalDeviceEvidence,
          AiroValidationGateId.storePolicy,
        },
        notes: const [
          'Fire TV requires store-channel and physical remote evidence before support claims.',
        ],
      ),
      AiroValidationTarget(
        targetId: 'android-mobile-companion',
        displayName: 'Android Mobile Companion',
        platform: AiroValidationPlatform.androidMobile,
        productProfile: AiroValidationProductProfile.companion,
        releasePhase: AiroValidationReleasePhase.connectedDevice,
        status: AiroValidationStatus.required,
        requiredGates: const {
          AiroValidationGateId.productCapabilities,
          AiroValidationGateId.adaptiveUi,
          AiroValidationGateId.touchInput,
          AiroValidationGateId.pairingController,
          AiroValidationGateId.sessionSync,
          AiroValidationGateId.localNetworkPrivacy,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.accessibility,
        },
        notes: const [
          'Companion validation covers controller and privacy behavior, not receiver certification.',
        ],
      ),
      AiroValidationTarget(
        targetId: 'ios-ipados-companion',
        displayName: 'iOS and iPadOS Companion',
        platform: AiroValidationPlatform.ipados,
        productProfile: AiroValidationProductProfile.companion,
        releasePhase: AiroValidationReleasePhase.connectedDevice,
        status: AiroValidationStatus.required,
        requiredGates: const {
          AiroValidationGateId.productCapabilities,
          AiroValidationGateId.adaptiveUi,
          AiroValidationGateId.touchInput,
          AiroValidationGateId.pairingController,
          AiroValidationGateId.sessionSync,
          AiroValidationGateId.localNetworkPrivacy,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.accessibility,
          AiroValidationGateId.storePolicy,
        },
      ),
      AiroValidationTarget(
        targetId: 'desktop-pointer-companion',
        displayName: 'Desktop Pointer Companion',
        platform: AiroValidationPlatform.desktop,
        productProfile: AiroValidationProductProfile.desktopCompanion,
        releasePhase: AiroValidationReleasePhase.platformFoundation,
        status: AiroValidationStatus.required,
        requiredGates: const {
          AiroValidationGateId.productCapabilities,
          AiroValidationGateId.adaptiveUi,
          AiroValidationGateId.pointerInput,
          AiroValidationGateId.importExportDataGovernance,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.accessibility,
        },
        notes: const [
          'Desktop validation must not require physical TV remote evidence.',
        ],
      ),
      AiroValidationTarget(
        targetId: 'apple-tv-tvos',
        displayName: 'Apple TV tvOS Receiver',
        platform: AiroValidationPlatform.tvos,
        productProfile: AiroValidationProductProfile.fullTv,
        releasePhase: AiroValidationReleasePhase.storeReadiness,
        status: AiroValidationStatus.blocked,
        requiresDeviceCertification: true,
        requiredGates: const {
          AiroValidationGateId.nativeTarget,
          AiroValidationGateId.remoteFocus,
          AiroValidationGateId.playbackEngine,
          AiroValidationGateId.storePolicy,
          AiroValidationGateId.physicalDeviceEvidence,
        },
        notes: const [
          'Blocked until a native tvOS target, store path, and evidence pipeline exist.',
        ],
      ),
      AiroValidationTarget(
        targetId: 'web-embedded-receiver',
        displayName: 'Web Embedded Receiver',
        platform: AiroValidationPlatform.webEmbeddedReceiver,
        productProfile: AiroValidationProductProfile.embeddedReceiver,
        releasePhase: AiroValidationReleasePhase.mediaRouting,
        status: AiroValidationStatus.optional,
        requiresDeviceCertification: true,
        requiredGates: const {
          AiroValidationGateId.productCapabilities,
          AiroValidationGateId.adaptiveUi,
          AiroValidationGateId.playbackEngine,
          AiroValidationGateId.mediaRouting,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.physicalDeviceEvidence,
        },
      ),
      AiroValidationTarget(
        targetId: 'backend-cloud-control-plane',
        displayName: 'Backend Cloud Control Plane',
        platform: AiroValidationPlatform.backendCloud,
        productProfile: AiroValidationProductProfile.backendControlPlane,
        releasePhase: AiroValidationReleasePhase.cloudBoundary,
        status: AiroValidationStatus.required,
        requiredGates: const {
          AiroValidationGateId.orchestrationStorage,
          AiroValidationGateId.cloudPrivacy,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.dependencyGovernance,
        },
        notes: const [
          'Cloud validation cannot advertise playback-device certification.',
        ],
      ),
    ];
  }

  static List<AiroValidationGate> _gates() {
    return [
      AiroValidationGate(
        gateId: AiroValidationGateId.productCapabilities,
        displayName: 'Product capabilities',
        description:
            'Selected product profile exposes only declared modules and permissions.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.adaptiveUi,
        displayName: 'Adaptive UI',
        description:
            'Adaptive mode contract resolves interaction, density, focus, and accessibility behavior for the target.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.remoteFocus,
        displayName: 'Remote focus',
        description:
            'Remote or D-pad navigation remains deterministic during content and artwork loading.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.physicalDevice,
          AiroValidationEvidenceTier.manualReview,
        },
        requiresPhysicalDevice: true,
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.touchInput,
        displayName: 'Touch input',
        description:
            'Touch companion controls satisfy target size, accessibility, and pairing workflows.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.physicalDevice,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.pointerInput,
        displayName: 'Pointer input',
        description:
            'Pointer and keyboard surfaces use pointer-safe focus and navigation.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.manualReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.playbackEngine,
        displayName: 'Playback engine',
        description:
            'Playback engine contract supports the target profile without direct app-layer player shortcuts.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.physicalDevice,
        },
        requiresPhysicalDevice: true,
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.mediaRouting,
        displayName: 'Media routing',
        description:
            'Media routing decisions use route handles and decision logs instead of raw provider auth material.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.securityPrivacyReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.pairingController,
        displayName: 'Pairing controller',
        description:
            'Pairing and controller permissions use trusted-device contracts and scoped commands.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.physicalDevice,
          AiroValidationEvidenceTier.securityPrivacyReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.sessionSync,
        displayName: 'Session sync',
        description:
            'Session and handoff state uses receiver-authoritative revisions and conflict policy.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.analyticsRedaction,
        displayName: 'Analytics redaction',
        description:
            'Validation rejects prohibited analytics fields and verifies consent/local-only behavior.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.securityPrivacyReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.dependencyGovernance,
        displayName: 'Dependency governance',
        description:
            'Target dependency set satisfies profile and release-line governance rules.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.releaseConfigReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.packageContentScan,
        displayName: 'Package content scan',
        description:
            'Release artifact contains no bundled playlists, provider media, raw URLs, or credentials.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.localNetworkPrivacy,
        displayName: 'Local network privacy',
        description:
            'Local-network discovery and pairing permissions are disclosed and scoped.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.securityPrivacyReview,
          AiroValidationEvidenceTier.manualReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.importExportDataGovernance,
        displayName: 'Import/export data governance',
        description:
            'Playlist import/export and local data paths follow platform data contracts.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.securityPrivacyReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.accessibility,
        displayName: 'Accessibility',
        description:
            'Target validates text scale, target size, focus, contrast, and reduced-motion behavior.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.manualReview,
          AiroValidationEvidenceTier.physicalDevice,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.nativeTarget,
        displayName: 'Native target',
        description:
            'Native platform target, signing, entitlement, and build path exist.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.hostAutomation,
          AiroValidationEvidenceTier.releaseConfigReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.storePolicy,
        displayName: 'Store policy',
        description:
            'Store-channel metadata, permissions, device support, and policy checks pass.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.storeReview,
          AiroValidationEvidenceTier.manualReview,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.orchestrationStorage,
        displayName: 'Orchestration storage',
        description:
            'Cloud orchestration storage contracts are versioned, scoped, and rollback-safe.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.cloudContract,
          AiroValidationEvidenceTier.hostAutomation,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.cloudPrivacy,
        displayName: 'Cloud privacy',
        description:
            'Cloud control-plane validation covers retention, redaction, identity, and access boundaries.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.securityPrivacyReview,
          AiroValidationEvidenceTier.cloudContract,
        },
      ),
      AiroValidationGate(
        gateId: AiroValidationGateId.physicalDeviceEvidence,
        displayName: 'Physical device evidence',
        description:
            'Target has recent physical-device evidence for certification claims.',
        acceptedEvidenceTiers: const {
          AiroValidationEvidenceTier.physicalDevice,
        },
        requiresPhysicalDevice: true,
      ),
    ];
  }
}

class AiroTvLegacyCertification {
  const AiroTvLegacyCertification._();

  static AiroCertificationMatrix matrix() {
    return AiroCertificationMatrix(targets: _targets(), gates: _gates());
  }

  static List<AiroCertificationTarget> _targets() {
    const liteRequiredGates = {
      AiroCertificationGateId.installLaunch,
      AiroCertificationGateId.dpadFocus,
      AiroCertificationGateId.playbackBaseline,
      AiroCertificationGateId.subtitleRendering,
      AiroCertificationGateId.pairingFlow,
      AiroCertificationGateId.compactEpg,
      AiroCertificationGateId.memoryPressure,
      AiroCertificationGateId.lowStorage,
      AiroCertificationGateId.sleepWake,
      AiroCertificationGateId.credentialPreservation,
      AiroCertificationGateId.packageContentScan,
      AiroCertificationGateId.dependencyBaseline,
    };

    return [
      AiroCertificationTarget(
        targetId: 'android-tv-api-26-lite',
        displayName: 'Android TV API 26 Lite Receiver',
        kind: AiroCertificationTargetKind.androidTvApi26,
        minimumLevel: AiroCertificationLevel.certified,
        requiredGates: liteRequiredGates,
        minAndroidApi: 26,
        maxAndroidApi: 27,
        minMemoryMb: 1024,
        minStorageMb: 256,
        notes: const [
          'Requires physical Android 8 or Android 8.1 TV evidence.',
          'Full EPG, recording, downloads, local AI, and multiview stay excluded.',
        ],
      ),
      AiroCertificationTarget(
        targetId: 'android-tv-api-28-lite',
        displayName: 'Android TV API 28 Lite Receiver',
        kind: AiroCertificationTargetKind.androidTvApi28,
        minimumLevel: AiroCertificationLevel.compatible,
        requiredGates: liteRequiredGates,
        minAndroidApi: 28,
        maxAndroidApi: 28,
        minMemoryMb: 1024,
        minStorageMb: 256,
        notes: const [
          'Requires physical Android 9 TV evidence.',
          'Compatible support can graduate to certified after device inventory expands.',
        ],
      ),
      AiroCertificationTarget(
        targetId: 'fire-tv-legacy-lite',
        displayName: 'Fire TV Legacy Lite Receiver',
        kind: AiroCertificationTargetKind.fireTvLegacy,
        minimumLevel: AiroCertificationLevel.compatible,
        requiredGates: {
          ...liteRequiredGates,
          AiroCertificationGateId.thermalStability,
        },
        minAndroidApi: 26,
        minMemoryMb: 1024,
        minStorageMb: 256,
        notes: const [
          'Requires Fire TV remote and store-channel evidence.',
          'Thermal stability is mandatory before support claims.',
        ],
      ),
      AiroCertificationTarget(
        targetId: 'lower-api-experimental',
        displayName: 'Lower API Experimental Receiver',
        kind: AiroCertificationTargetKind.lowerApiExperimental,
        minimumLevel: AiroCertificationLevel.unsupported,
        requiredGates: const {},
        minAndroidApi: 23,
        maxAndroidApi: 25,
        notes: const [
          'Lower API devices remain unsupported until dependency, security, and device certification gates pass.',
        ],
      ),
    ];
  }

  static List<AiroCertificationGate> _gates() {
    return [
      AiroCertificationGate(
        gateId: AiroCertificationGateId.installLaunch,
        displayName: 'Install and launch',
        description: 'Release APK installs, launches, and reaches TV home.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.dpadFocus,
        displayName: 'D-pad focus',
        description:
            'Remote-only navigation remains stable during artwork loading.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.playbackBaseline,
        displayName: 'Baseline playback',
        description:
            'H.264/AAC/HLS/MPEG-TS/MP4 fixtures play with native rendering.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
          AiroCertificationEvidenceKind.mediaFixtureRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.subtitleRendering,
        displayName: 'Subtitle rendering',
        description:
            'Baseline subtitle fixtures render without focus or playback regression.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
          AiroCertificationEvidenceKind.mediaFixtureRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.pairingFlow,
        displayName: 'Pairing flow',
        description:
            'Pairing and restricted receiver trust flow works on real hardware.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
          AiroCertificationEvidenceKind.manualChecklist,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.compactEpg,
        displayName: 'Compact EPG',
        description:
            'Current/next guide displays without loading full XMLTV data locally.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.memoryPressure,
        displayName: 'Memory pressure',
        description:
            'Receiver reduces caches while preserving active playback.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
          AiroCertificationEvidenceKind.benchmarkTrace,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.lowStorage,
        displayName: 'Low storage',
        description:
            'Low-storage flow preserves credentials, favorites, and progress.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.sleepWake,
        displayName: 'Sleep and wake',
        description:
            'Playback state and navigation recover after device sleep/wake.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.thermalStability,
        displayName: 'Thermal stability',
        description:
            'Long playback session avoids thermal runaway and keeps controls usable.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
          AiroCertificationEvidenceKind.benchmarkTrace,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.credentialPreservation,
        displayName: 'Credential preservation',
        description:
            'Credential storage remains intact during pressure and update flows.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.physicalDeviceRun,
          AiroCertificationEvidenceKind.manualChecklist,
        },
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.packageContentScan,
        displayName: 'Packaged content scan',
        description:
            'Release package contains no bundled playlists or provider media.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.hostStaticScan,
        },
        requiresPhysicalDevice: false,
      ),
      AiroCertificationGate(
        gateId: AiroCertificationGateId.dependencyBaseline,
        displayName: 'Dependency baseline',
        description:
            'Release profile keeps API 26-compatible dependency constraints.',
        acceptedEvidenceKinds: const {
          AiroCertificationEvidenceKind.releaseConfigReview,
          AiroCertificationEvidenceKind.hostStaticScan,
        },
        requiresPhysicalDevice: false,
      ),
    ];
  }
}
