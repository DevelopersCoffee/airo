import 'package:equatable/equatable.dart';

const String kAiroNodeProtocolSchemaVersion = '1.0.0';
const int kAiroNodeProtocolVersion = 1;

enum AiroNodeRole {
  tvReceiver('tv_receiver'),
  mobileCompanion('mobile_companion'),
  desktopCompanion('desktop_companion'),
  homeNode('home_node'),
  cloudCoordinator('cloud_coordinator');

  const AiroNodeRole(this.stableId);

  final String stableId;
}

enum AiroNodeProductProfile {
  fullTv('full_tv'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  experimentalLegacy('experimental_legacy'),
  mobileCompanion('mobile_companion'),
  desktopCompanion('desktop_companion'),
  homeNode('home_node');

  const AiroNodeProductProfile(this.stableId);

  final String stableId;
}

enum AiroNodePlatformCategory {
  androidTv('android_tv'),
  fireTv('fire_tv'),
  androidMobile('android_mobile'),
  ios('ios'),
  desktop('desktop'),
  server('server'),
  cloud('cloud'),
  unknown('unknown');

  const AiroNodePlatformCategory(this.stableId);

  final String stableId;
}

enum AiroNodeLifecycleState {
  available('available'),
  pairing('pairing'),
  connected('connected'),
  busy('busy'),
  sleeping('sleeping'),
  offline('offline'),
  incompatible('incompatible'),
  updateRequired('update_required'),
  blocked('blocked');

  const AiroNodeLifecycleState(this.stableId);

  final String stableId;

  bool get canNegotiate =>
      this == available || this == pairing || this == connected || this == busy;
}

enum AiroNodeTrustState {
  unknown('unknown'),
  untrusted('untrusted'),
  paired('paired'),
  trusted('trusted'),
  revoked('revoked');

  const AiroNodeTrustState(this.stableId);

  final String stableId;

  bool get allowsPrivateCompatibility => this == paired || this == trusted;
}

enum AiroNodeCapability {
  playback('playback'),
  display('display'),
  voiceInput('voice_input'),
  keyboardInput('keyboard_input'),
  localAi('local_ai'),
  mediaIndexing('media_indexing'),
  storage('storage'),
  remoteControl('remote_control'),
  diagnostics('diagnostics'),
  recording('recording'),
  transcoding('transcoding'),
  metadataProcessing('metadata_processing'),
  compactEpg('compact_epg'),
  basicSearch('basic_search'),
  aiDelegation('ai_delegation'),
  pairing('pairing'),
  commandRouting('command_routing');

  const AiroNodeCapability(this.stableId);

  final String stableId;
}

enum AiroNodeCompatibilityBlockerCode {
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  staleAdvertisement('stale_advertisement'),
  missingCapability('missing_capability'),
  lifecycleUnavailable('lifecycle_unavailable'),
  untrustedNode('untrusted_node'),
  blockedNode('blocked_node');

  const AiroNodeCompatibilityBlockerCode(this.stableId);

  final String stableId;
}

class AiroNodeIdentity extends Equatable {
  const AiroNodeIdentity({
    required this.nodeId,
    required this.role,
    required this.productProfile,
    required this.platformCategory,
    this.schemaVersion = kAiroNodeProtocolSchemaVersion,
    this.protocolVersion = kAiroNodeProtocolVersion,
  });

  final String schemaVersion;
  final int protocolVersion;
  final String nodeId;
  final AiroNodeRole role;
  final AiroNodeProductProfile productProfile;
  final AiroNodePlatformCategory platformCategory;

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    nodeId,
    role,
    productProfile,
    platformCategory,
  ];
}

class AiroNodeCapabilityAdvertisement extends Equatable {
  AiroNodeCapabilityAdvertisement({
    required this.identity,
    required this.lifecycle,
    required Set<AiroNodeCapability> capabilities,
    required this.issuedAt,
    required this.expiresAt,
    this.trustState = AiroNodeTrustState.unknown,
    this.schemaVersion = kAiroNodeProtocolSchemaVersion,
    this.protocolVersion = kAiroNodeProtocolVersion,
  }) : capabilities = Set.unmodifiable(capabilities);

  final String schemaVersion;
  final int protocolVersion;
  final AiroNodeIdentity identity;
  final AiroNodeLifecycleState lifecycle;
  final AiroNodeTrustState trustState;
  final Set<AiroNodeCapability> capabilities;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool advertises(AiroNodeCapability capability) =>
      capabilities.contains(capability);

  bool advertisesAll(Set<AiroNodeCapability> requiredCapabilities) =>
      capabilities.containsAll(requiredCapabilities);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'protocolVersion': protocolVersion,
      'nodeId': identity.nodeId,
      'role': identity.role.stableId,
      'productProfile': identity.productProfile.stableId,
      'platformCategory': identity.platformCategory.stableId,
      'lifecycle': lifecycle.stableId,
      'capabilities': capabilities
          .map((capability) => capability.stableId)
          .toList(growable: false),
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AiroNodeCapabilityAdvertisement('
        'nodeId: ${identity.nodeId}, '
        'role: ${identity.role.stableId}, '
        'productProfile: ${identity.productProfile.stableId}, '
        'platformCategory: ${identity.platformCategory.stableId}, '
        'lifecycle: ${lifecycle.stableId}, '
        'capabilities: ${capabilities.map((capability) => capability.stableId).join(',')}, '
        'issuedAt: $issuedAt, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    identity,
    lifecycle,
    trustState,
    capabilities,
    issuedAt,
    expiresAt,
  ];
}

class AiroNodeCompatibilityPolicy extends Equatable {
  AiroNodeCompatibilityPolicy({
    required Set<AiroNodeCapability> requiredCapabilities,
    this.acceptedSchemaVersion = kAiroNodeProtocolSchemaVersion,
    this.minProtocolVersion = kAiroNodeProtocolVersion,
    this.maxProtocolVersion = kAiroNodeProtocolVersion,
    this.requiresTrustedNode = false,
  }) : requiredCapabilities = Set.unmodifiable(requiredCapabilities);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final bool requiresTrustedNode;
  final Set<AiroNodeCapability> requiredCapabilities;

  AiroNodeCompatibilityResult evaluate({
    required AiroNodeCapabilityAdvertisement advertisement,
    required DateTime now,
  }) {
    final blockers = <AiroNodeCompatibilityBlocker>[];

    if (advertisement.schemaVersion != acceptedSchemaVersion ||
        advertisement.identity.schemaVersion != acceptedSchemaVersion) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.schemaMismatch,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    if (advertisement.protocolVersion < minProtocolVersion ||
        advertisement.identity.protocolVersion < minProtocolVersion) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.protocolTooOld,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    if (advertisement.protocolVersion > maxProtocolVersion ||
        advertisement.identity.protocolVersion > maxProtocolVersion) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.protocolTooNew,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    if (advertisement.isExpired(now)) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.staleAdvertisement,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    if (advertisement.lifecycle == AiroNodeLifecycleState.blocked ||
        advertisement.trustState == AiroNodeTrustState.revoked) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.blockedNode,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    } else if (!advertisement.lifecycle.canNegotiate) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.lifecycleUnavailable,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    if (requiresTrustedNode &&
        !advertisement.trustState.allowsPrivateCompatibility) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.untrustedNode,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    if (!advertisement.advertisesAll(requiredCapabilities)) {
      blockers.add(
        AiroNodeCompatibilityBlocker(
          code: AiroNodeCompatibilityBlockerCode.missingCapability,
          nodeId: advertisement.identity.nodeId,
        ),
      );
    }

    return AiroNodeCompatibilityResult(
      nodeId: advertisement.identity.nodeId,
      blockers: blockers,
    );
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    requiresTrustedNode,
    requiredCapabilities,
  ];
}

class AiroNodeCompatibilityBlocker extends Equatable {
  const AiroNodeCompatibilityBlocker({
    required this.code,
    required this.nodeId,
  });

  final AiroNodeCompatibilityBlockerCode code;
  final String nodeId;

  @override
  List<Object?> get props => [code, nodeId];
}

class AiroNodeCompatibilityResult extends Equatable {
  AiroNodeCompatibilityResult({
    required this.nodeId,
    required List<AiroNodeCompatibilityBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String nodeId;
  final List<AiroNodeCompatibilityBlocker> blockers;

  bool get compatible => blockers.isEmpty;

  @override
  List<Object?> get props => [nodeId, blockers];
}
