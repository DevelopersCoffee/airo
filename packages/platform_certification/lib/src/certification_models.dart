import 'package:equatable/equatable.dart';

const String kAiroCertificationSchemaVersion = '1.0.0';

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
