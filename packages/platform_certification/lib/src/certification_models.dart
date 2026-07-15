import 'package:equatable/equatable.dart';

const String kAiroCertificationSchemaVersion = '1.0.0';
const String kAiroValidationSchemaVersion = '1.0.0';
const String kAiroDistributionSchemaVersion = '1.0.0';
const String kAiroLowerApiEvaluationSchemaVersion = '1.0.0';

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

enum AiroDistributionChannel {
  googlePlayTv('google_play_tv'),
  amazonAppstore('amazon_appstore'),
  directApk('direct_apk'),
  operatorBox('operator_box');

  const AiroDistributionChannel(this.stableId);

  final String stableId;
}

enum AiroDistributionTargetStatus {
  publishable('publishable'),
  internalOnly('internal_only'),
  blocked('blocked'),
  deferred('deferred');

  const AiroDistributionTargetStatus(this.stableId);

  final String stableId;
}

enum AiroDistributionEvidenceKind {
  apkArtifact('apk_artifact'),
  playAabArtifact('play_aab_artifact'),
  sha256Sums('sha256_sums'),
  releaseManifest('release_manifest'),
  packageContentScan('package_content_scan'),
  storeListing('store_listing'),
  storePolicyReview('store_policy_review'),
  contentRating('content_rating'),
  dataSafety('data_safety'),
  legalReview('legal_review'),
  physicalDeviceEvidence('physical_device_evidence'),
  remoteNavigationEvidence('remote_navigation_evidence'),
  operatorApproval('operator_approval');

  const AiroDistributionEvidenceKind(this.stableId);

  final String stableId;
}

enum AiroDistributionBlockerCode {
  targetMissing('target_missing'),
  targetBlocked('target_blocked'),
  targetDeferred('target_deferred'),
  evidenceMissing('evidence_missing'),
  evidenceWrongTarget('evidence_wrong_target'),
  evidenceWrongKind('evidence_wrong_kind'),
  evidenceStale('evidence_stale');

  const AiroDistributionBlockerCode(this.stableId);

  final String stableId;
}

enum AiroLowerApiEvidenceKind {
  dependencyBaseline('dependency_baseline'),
  flutterEmbedding('flutter_embedding'),
  packageContentScan('package_content_scan'),
  installLaunch('install_launch'),
  remoteFocus('remote_focus'),
  playbackBaseline('playback_baseline'),
  memoryPressure('memory_pressure'),
  lowStorage('low_storage'),
  sleepWake('sleep_wake'),
  restrictedTrust('restricted_trust'),
  securityPatchReview('security_patch_review');

  const AiroLowerApiEvidenceKind(this.stableId);

  final String stableId;
}

enum AiroLowerApiEvaluationStatus {
  blocked('blocked'),
  experimentalEligible('experimental_eligible');

  const AiroLowerApiEvaluationStatus(this.stableId);

  final String stableId;
}

enum AiroLowerApiEvaluationCode {
  accepted('accepted'),
  apiRangeUnsupported('api_range_unsupported'),
  publicSupportBlocked('public_support_blocked'),
  evidenceMissing('evidence_missing'),
  evidenceWrongCandidate('evidence_wrong_candidate'),
  evidenceStale('evidence_stale');

  const AiroLowerApiEvaluationCode(this.stableId);

  final String stableId;
}

class AiroLowerApiCandidate extends Equatable {
  const AiroLowerApiCandidate({
    required this.candidateId,
    required this.minAndroidApi,
    required this.maxAndroidApi,
    required this.productProfile,
    required this.releaseChannel,
    this.requestsPublicSupportClaim = false,
    this.schemaVersion = kAiroLowerApiEvaluationSchemaVersion,
  }) : assert(minAndroidApi > 0),
       assert(maxAndroidApi > 0);

  final String schemaVersion;
  final String candidateId;
  final int minAndroidApi;
  final int maxAndroidApi;
  final AiroValidationProductProfile productProfile;
  final AiroDistributionChannel releaseChannel;
  final bool requestsPublicSupportClaim;

  bool get isLowerThanApi26 => maxAndroidApi < 26;

  Map<String, Object?> toPublicMap() {
    return {
      'candidateId': candidateId,
      'minAndroidApi': minAndroidApi,
      'maxAndroidApi': maxAndroidApi,
      'productProfile': productProfile.stableId,
      'releaseChannel': releaseChannel.stableId,
      'requestsPublicSupportClaim': requestsPublicSupportClaim,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    candidateId,
    minAndroidApi,
    maxAndroidApi,
    productProfile,
    releaseChannel,
    requestsPublicSupportClaim,
  ];
}

class AiroLowerApiEvidence extends Equatable {
  const AiroLowerApiEvidence({
    required this.evidenceId,
    required this.candidateId,
    required this.kind,
    required this.capturedAt,
    required this.passed,
    this.schemaVersion = kAiroLowerApiEvaluationSchemaVersion,
  });

  final String schemaVersion;
  final String evidenceId;
  final String candidateId;
  final AiroLowerApiEvidenceKind kind;
  final DateTime capturedAt;
  final bool passed;

  @override
  List<Object?> get props => [
    schemaVersion,
    evidenceId,
    candidateId,
    kind,
    capturedAt,
    passed,
  ];
}

class AiroLowerApiEvaluationBlocker extends Equatable {
  const AiroLowerApiEvaluationBlocker({
    required this.code,
    required this.candidateId,
    this.evidenceKind,
  });

  final AiroLowerApiEvaluationCode code;
  final String candidateId;
  final AiroLowerApiEvidenceKind? evidenceKind;

  @override
  List<Object?> get props => [code, candidateId, evidenceKind];
}

class AiroLowerApiEvaluationResult extends Equatable {
  AiroLowerApiEvaluationResult({
    required this.candidate,
    required this.status,
    required List<AiroLowerApiEvaluationBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final AiroLowerApiCandidate candidate;
  final AiroLowerApiEvaluationStatus status;
  final List<AiroLowerApiEvaluationBlocker> blockers;

  bool get accepted => blockers.isEmpty;

  bool get canEnterExperimentalCertification =>
      accepted && status == AiroLowerApiEvaluationStatus.experimentalEligible;

  bool get canAdvertisePublicSupport => false;

  Map<String, Object?> toPublicMap() {
    return {
      'candidate': candidate.toPublicMap(),
      'status': status.stableId,
      'accepted': accepted,
      'canEnterExperimentalCertification': canEnterExperimentalCertification,
      'canAdvertisePublicSupport': canAdvertisePublicSupport,
      'blockers': [
        for (final blocker in blockers)
          {
            'code': blocker.code.stableId,
            'evidenceKind': blocker.evidenceKind?.stableId,
          },
      ],
    };
  }

  @override
  List<Object?> get props => [candidate, status, blockers];
}

class AiroLowerApiEvaluationPolicy extends Equatable {
  AiroLowerApiEvaluationPolicy({
    this.minExperimentalApi = 23,
    this.maxExperimentalApi = 25,
    this.maxEvidenceAge = const Duration(days: 30),
    Set<AiroLowerApiEvidenceKind> requiredEvidenceKinds = const {
      AiroLowerApiEvidenceKind.dependencyBaseline,
      AiroLowerApiEvidenceKind.flutterEmbedding,
      AiroLowerApiEvidenceKind.packageContentScan,
      AiroLowerApiEvidenceKind.installLaunch,
      AiroLowerApiEvidenceKind.remoteFocus,
      AiroLowerApiEvidenceKind.playbackBaseline,
      AiroLowerApiEvidenceKind.memoryPressure,
      AiroLowerApiEvidenceKind.lowStorage,
      AiroLowerApiEvidenceKind.sleepWake,
      AiroLowerApiEvidenceKind.restrictedTrust,
      AiroLowerApiEvidenceKind.securityPatchReview,
    },
  }) : requiredEvidenceKinds = Set.unmodifiable(requiredEvidenceKinds);

  final int minExperimentalApi;
  final int maxExperimentalApi;
  final Duration maxEvidenceAge;
  final Set<AiroLowerApiEvidenceKind> requiredEvidenceKinds;

  AiroLowerApiEvaluationResult evaluate({
    required AiroLowerApiCandidate candidate,
    required Iterable<AiroLowerApiEvidence> evidence,
    required DateTime now,
  }) {
    final blockers = <AiroLowerApiEvaluationBlocker>[];
    if (candidate.minAndroidApi < minExperimentalApi ||
        candidate.maxAndroidApi > maxExperimentalApi ||
        candidate.minAndroidApi > candidate.maxAndroidApi) {
      blockers.add(
        AiroLowerApiEvaluationBlocker(
          code: AiroLowerApiEvaluationCode.apiRangeUnsupported,
          candidateId: candidate.candidateId,
        ),
      );
    }
    if (candidate.requestsPublicSupportClaim) {
      blockers.add(
        AiroLowerApiEvaluationBlocker(
          code: AiroLowerApiEvaluationCode.publicSupportBlocked,
          candidateId: candidate.candidateId,
        ),
      );
    }

    final passedEvidence = evidence.where((record) => record.passed).toList();
    for (final requiredKind in requiredEvidenceKinds) {
      final kindRecords = passedEvidence
          .where((record) => record.kind == requiredKind)
          .toList();
      if (kindRecords.isEmpty) {
        blockers.add(
          AiroLowerApiEvaluationBlocker(
            code: AiroLowerApiEvaluationCode.evidenceMissing,
            candidateId: candidate.candidateId,
            evidenceKind: requiredKind,
          ),
        );
        continue;
      }
      final candidateRecords = kindRecords
          .where((record) => record.candidateId == candidate.candidateId)
          .toList();
      if (candidateRecords.isEmpty) {
        blockers.add(
          AiroLowerApiEvaluationBlocker(
            code: AiroLowerApiEvaluationCode.evidenceWrongCandidate,
            candidateId: candidate.candidateId,
            evidenceKind: requiredKind,
          ),
        );
        continue;
      }
      final freshRecords = candidateRecords.where(
        (record) => !record.capturedAt.add(maxEvidenceAge).isBefore(now),
      );
      if (freshRecords.isEmpty) {
        blockers.add(
          AiroLowerApiEvaluationBlocker(
            code: AiroLowerApiEvaluationCode.evidenceStale,
            candidateId: candidate.candidateId,
            evidenceKind: requiredKind,
          ),
        );
      }
    }

    return AiroLowerApiEvaluationResult(
      candidate: candidate,
      status: blockers.isEmpty
          ? AiroLowerApiEvaluationStatus.experimentalEligible
          : AiroLowerApiEvaluationStatus.blocked,
      blockers: blockers,
    );
  }

  @override
  List<Object?> get props => [
    minExperimentalApi,
    maxExperimentalApi,
    maxEvidenceAge,
    requiredEvidenceKinds,
  ];
}

class AiroDistributionTarget extends Equatable {
  AiroDistributionTarget({
    required this.targetId,
    required this.displayName,
    required this.channel,
    required this.platform,
    required this.productProfile,
    required this.status,
    required Set<AiroDistributionEvidenceKind> requiredEvidenceKinds,
    this.maxEvidenceAge = const Duration(days: 30),
    List<String> notes = const [],
    this.schemaVersion = kAiroDistributionSchemaVersion,
  }) : requiredEvidenceKinds = Set.unmodifiable(requiredEvidenceKinds),
       notes = List.unmodifiable(notes);

  final String schemaVersion;
  final String targetId;
  final String displayName;
  final AiroDistributionChannel channel;
  final AiroValidationPlatform platform;
  final AiroValidationProductProfile productProfile;
  final AiroDistributionTargetStatus status;
  final Set<AiroDistributionEvidenceKind> requiredEvidenceKinds;
  final Duration maxEvidenceAge;
  final List<String> notes;

  bool get canAdvertiseWhenEvidenced =>
      status == AiroDistributionTargetStatus.publishable;

  Map<String, Object?> toPublicMap() {
    return {
      'targetId': targetId,
      'displayName': displayName,
      'channel': channel.stableId,
      'platform': platform.stableId,
      'productProfile': productProfile.stableId,
      'status': status.stableId,
      'requiredEvidenceKinds': _distributionEvidenceKindStableIds(
        requiredEvidenceKinds,
      ),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    targetId,
    displayName,
    channel,
    platform,
    productProfile,
    status,
    requiredEvidenceKinds,
    maxEvidenceAge,
    notes,
  ];
}

class AiroDistributionEvidence extends Equatable {
  const AiroDistributionEvidence({
    required this.evidenceId,
    required this.targetId,
    required this.kind,
    required this.capturedAt,
    required this.passed,
    this.summary,
    this.schemaVersion = kAiroDistributionSchemaVersion,
  });

  final String schemaVersion;
  final String evidenceId;
  final String targetId;
  final AiroDistributionEvidenceKind kind;
  final DateTime capturedAt;
  final bool passed;
  final String? summary;

  @override
  List<Object?> get props => [
    schemaVersion,
    evidenceId,
    targetId,
    kind,
    capturedAt,
    passed,
    summary,
  ];
}

class AiroDistributionBlocker extends Equatable {
  const AiroDistributionBlocker({
    required this.code,
    required this.targetId,
    this.evidenceKind,
  });

  final AiroDistributionBlockerCode code;
  final String targetId;
  final AiroDistributionEvidenceKind? evidenceKind;

  @override
  List<Object?> get props => [code, targetId, evidenceKind];
}

class AiroDistributionResult extends Equatable {
  AiroDistributionResult({
    required this.target,
    required List<AiroDistributionBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final AiroDistributionTarget target;
  final List<AiroDistributionBlocker> blockers;

  bool get passed => blockers.isEmpty;

  bool get canAdvertiseChannelSupport =>
      passed && target.canAdvertiseWhenEvidenced;

  Map<String, Object?> toPublicMap() {
    return {
      'targetId': target.targetId,
      'channel': target.channel.stableId,
      'platform': target.platform.stableId,
      'productProfile': target.productProfile.stableId,
      'status': target.status.stableId,
      'passed': passed,
      'canAdvertiseChannelSupport': canAdvertiseChannelSupport,
      'blockers': [
        for (final blocker in blockers)
          {
            'code': blocker.code.stableId,
            'evidenceKind': blocker.evidenceKind?.stableId,
          },
      ],
    };
  }

  @override
  List<Object?> get props => [target, blockers];
}

class AiroDistributionMatrix extends Equatable {
  AiroDistributionMatrix({
    required Iterable<AiroDistributionTarget> targets,
    this.schemaVersion = kAiroDistributionSchemaVersion,
  }) : targets = List.unmodifiable(targets);

  final String schemaVersion;
  final List<AiroDistributionTarget> targets;

  AiroDistributionTarget? targetById(String targetId) {
    for (final target in targets) {
      if (target.targetId == targetId) return target;
    }
    return null;
  }

  AiroDistributionResult evaluate({
    required String targetId,
    required Iterable<AiroDistributionEvidence> evidence,
    required DateTime now,
  }) {
    final target = targetById(targetId);
    if (target == null) {
      return AiroDistributionResult(
        target: AiroDistributionTarget(
          targetId: targetId,
          displayName: targetId,
          channel: AiroDistributionChannel.directApk,
          platform: AiroValidationPlatform.androidTv,
          productProfile: AiroValidationProductProfile.liteReceiver,
          status: AiroDistributionTargetStatus.blocked,
          requiredEvidenceKinds: const {},
        ),
        blockers: [
          AiroDistributionBlocker(
            code: AiroDistributionBlockerCode.targetMissing,
            targetId: targetId,
          ),
        ],
      );
    }

    final blockers = <AiroDistributionBlocker>[];
    if (target.status == AiroDistributionTargetStatus.blocked) {
      blockers.add(
        AiroDistributionBlocker(
          code: AiroDistributionBlockerCode.targetBlocked,
          targetId: targetId,
        ),
      );
    }
    if (target.status == AiroDistributionTargetStatus.deferred) {
      blockers.add(
        AiroDistributionBlocker(
          code: AiroDistributionBlockerCode.targetDeferred,
          targetId: targetId,
        ),
      );
    }

    final passedEvidence = evidence.where((record) => record.passed).toList();
    for (final requiredKind in target.requiredEvidenceKinds) {
      final records = passedEvidence
          .where((record) => record.kind == requiredKind)
          .toList();
      if (records.isEmpty) {
        blockers.add(
          AiroDistributionBlocker(
            code: AiroDistributionBlockerCode.evidenceMissing,
            targetId: targetId,
            evidenceKind: requiredKind,
          ),
        );
        continue;
      }
      final targetRecords = records
          .where((record) => record.targetId == targetId)
          .toList();
      if (targetRecords.isEmpty) {
        blockers.add(
          AiroDistributionBlocker(
            code: AiroDistributionBlockerCode.evidenceWrongTarget,
            targetId: targetId,
            evidenceKind: requiredKind,
          ),
        );
        continue;
      }
      final freshRecords = targetRecords.where(
        (record) => !record.capturedAt.add(target.maxEvidenceAge).isBefore(now),
      );
      if (freshRecords.isEmpty) {
        blockers.add(
          AiroDistributionBlocker(
            code: AiroDistributionBlockerCode.evidenceStale,
            targetId: targetId,
            evidenceKind: requiredKind,
          ),
        );
      }
    }

    return AiroDistributionResult(target: target, blockers: blockers);
  }

  List<AiroDistributionTarget> targetsForChannel(
    AiroDistributionChannel channel,
  ) {
    return targets.where((target) => target.channel == channel).toList();
  }

  @override
  List<Object?> get props => [schemaVersion, targets];
}

class AiroTvLegacyDistribution {
  const AiroTvLegacyDistribution._();

  static AiroDistributionMatrix matrix() {
    return AiroDistributionMatrix(targets: _targets());
  }

  static List<AiroDistributionTarget> _targets() {
    return [
      AiroDistributionTarget(
        targetId: 'google-play-tv-android-tv',
        displayName: 'Google Play TV Android TV release',
        channel: AiroDistributionChannel.googlePlayTv,
        platform: AiroValidationPlatform.androidTv,
        productProfile: AiroValidationProductProfile.fullTv,
        status: AiroDistributionTargetStatus.publishable,
        requiredEvidenceKinds: const {
          AiroDistributionEvidenceKind.playAabArtifact,
          AiroDistributionEvidenceKind.storeListing,
          AiroDistributionEvidenceKind.contentRating,
          AiroDistributionEvidenceKind.dataSafety,
          AiroDistributionEvidenceKind.storePolicyReview,
          AiroDistributionEvidenceKind.physicalDeviceEvidence,
        },
        notes: const [
          'Google Play TV publication requires TV listing and release evidence.',
        ],
      ),
      AiroDistributionTarget(
        targetId: 'amazon-appstore-fire-tv',
        displayName: 'Amazon Appstore Fire TV release',
        channel: AiroDistributionChannel.amazonAppstore,
        platform: AiroValidationPlatform.fireTv,
        productProfile: AiroValidationProductProfile.liteReceiver,
        status: AiroDistributionTargetStatus.publishable,
        requiredEvidenceKinds: const {
          AiroDistributionEvidenceKind.apkArtifact,
          AiroDistributionEvidenceKind.storeListing,
          AiroDistributionEvidenceKind.storePolicyReview,
          AiroDistributionEvidenceKind.legalReview,
          AiroDistributionEvidenceKind.remoteNavigationEvidence,
          AiroDistributionEvidenceKind.physicalDeviceEvidence,
        },
        notes: const [
          'Fire TV support claims require remote-navigation and store-channel evidence.',
        ],
      ),
      AiroDistributionTarget(
        targetId: 'direct-apk-legacy-android-tv',
        displayName: 'Direct APK legacy Android TV release',
        channel: AiroDistributionChannel.directApk,
        platform: AiroValidationPlatform.androidTv,
        productProfile: AiroValidationProductProfile.liteReceiver,
        status: AiroDistributionTargetStatus.publishable,
        requiredEvidenceKinds: const {
          AiroDistributionEvidenceKind.apkArtifact,
          AiroDistributionEvidenceKind.sha256Sums,
          AiroDistributionEvidenceKind.releaseManifest,
          AiroDistributionEvidenceKind.packageContentScan,
          AiroDistributionEvidenceKind.legalReview,
          AiroDistributionEvidenceKind.physicalDeviceEvidence,
        },
        notes: const [
          'Direct APKs require checksum, manifest, package scan, and install evidence.',
        ],
      ),
      AiroDistributionTarget(
        targetId: 'operator-box-legacy-receiver',
        displayName: 'Operator box legacy receiver release',
        channel: AiroDistributionChannel.operatorBox,
        platform: AiroValidationPlatform.androidTv,
        productProfile: AiroValidationProductProfile.liteReceiver,
        status: AiroDistributionTargetStatus.publishable,
        requiredEvidenceKinds: const {
          AiroDistributionEvidenceKind.operatorApproval,
          AiroDistributionEvidenceKind.apkArtifact,
          AiroDistributionEvidenceKind.releaseManifest,
          AiroDistributionEvidenceKind.storePolicyReview,
          AiroDistributionEvidenceKind.legalReview,
          AiroDistributionEvidenceKind.physicalDeviceEvidence,
        },
        notes: const [
          'Operator boxes remain blocked until operator approval and channel evidence exist.',
        ],
      ),
    ];
  }
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

class AiroCertificationProgram extends Equatable {
  AiroCertificationProgram({
    required this.programId,
    required this.releaseLine,
    required Iterable<String> targetIds,
    required this.createdAt,
    this.matrixProvider = AiroTvLegacyCertification.matrix,
    this.schemaVersion = kAiroCertificationSchemaVersion,
  }) : targetIds = List.unmodifiable(targetIds);

  final String schemaVersion;
  final String programId;
  final String releaseLine;
  final List<String> targetIds;
  final DateTime createdAt;
  final AiroCertificationMatrix Function() matrixProvider;

  AiroCertificationProgramReport evaluate({
    required Iterable<AiroCertificationEvidence> evidence,
    required DateTime now,
  }) {
    final matrix = matrixProvider();
    final results = [
      for (final targetId in targetIds)
        matrix.evaluate(targetId: targetId, evidence: evidence, now: now),
    ];

    return AiroCertificationProgramReport(
      programId: programId,
      releaseLine: releaseLine,
      matrixSchemaVersion: matrix.schemaVersion,
      results: results,
      createdAt: createdAt,
      generatedAt: now,
      schemaVersion: schemaVersion,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    programId,
    releaseLine,
    targetIds,
    createdAt,
    matrixProvider,
  ];
}

class AiroCertificationSupportClaim extends Equatable {
  const AiroCertificationSupportClaim({
    required this.targetId,
    required this.level,
  });

  final String targetId;
  final AiroCertificationLevel level;

  Map<String, Object?> toPublicMap() {
    return {'targetId': targetId, 'level': level.stableId};
  }

  @override
  List<Object?> get props => [targetId, level];
}

class AiroCertificationProgramReport extends Equatable {
  AiroCertificationProgramReport({
    required this.programId,
    required this.releaseLine,
    required this.matrixSchemaVersion,
    required Iterable<AiroCertificationResult> results,
    required this.createdAt,
    required this.generatedAt,
    this.schemaVersion = kAiroCertificationSchemaVersion,
  }) : results = List.unmodifiable(results);

  final String schemaVersion;
  final String programId;
  final String releaseLine;
  final String matrixSchemaVersion;
  final List<AiroCertificationResult> results;
  final DateTime createdAt;
  final DateTime generatedAt;

  bool get passed => results.every((result) => result.passed);

  List<String> get blockedTargets {
    return List.unmodifiable(
      results
          .where((result) => !result.passed)
          .map((result) => result.targetId),
    );
  }

  Set<AiroCertificationBlockerCode> get blockerCodes {
    return Set.unmodifiable(
      results.expand(
        (result) => result.blockers.map((blocker) => blocker.code),
      ),
    );
  }

  List<AiroCertificationSupportClaim> get advertisedSupportClaims {
    return List.unmodifiable(
      results
          .where((result) => result.canAdvertiseSupport)
          .map(
            (result) => AiroCertificationSupportClaim(
              targetId: result.targetId,
              level: result.claimedLevel,
            ),
          ),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'programId': programId,
      'releaseLine': releaseLine,
      'matrixSchemaVersion': matrixSchemaVersion,
      'passed': passed,
      'blockedTargets': blockedTargets,
      'blockerCodes': blockerCodes
          .map((code) => code.stableId)
          .toList(growable: false),
      'advertisedSupportClaims': advertisedSupportClaims
          .map((claim) => claim.toPublicMap())
          .toList(growable: false),
      'results': results.map(_resultToPublicMap).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> _resultToPublicMap(AiroCertificationResult result) {
    return {
      'targetId': result.targetId,
      'claimedLevel': result.claimedLevel.stableId,
      'passed': result.passed,
      'canAdvertiseSupport': result.canAdvertiseSupport,
      'blockers': result.blockers
          .map(
            (blocker) => {
              'code': blocker.code.stableId,
              'targetId': blocker.targetId,
              'gateId': blocker.gateId?.stableId,
            },
          )
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    programId,
    releaseLine,
    matrixSchemaVersion,
    results,
    createdAt,
    generatedAt,
  ];
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

List<String> _distributionEvidenceKindStableIds(
  Iterable<AiroDistributionEvidenceKind> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}
