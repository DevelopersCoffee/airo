import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_presence/core_presence.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';

const String kAiroDeviceMergeSchemaVersion = '1.0.0';

enum AiroDeviceObservationSource {
  local('local'),
  cloud('cloud'),
  merged('merged');

  const AiroDeviceObservationSource(this.stableId);

  final String stableId;
}

enum AiroDeviceReachability {
  localOnly('local_only'),
  cloudOnly('cloud_only'),
  localAndCloud('local_and_cloud'),
  unavailable('unavailable');

  const AiroDeviceReachability(this.stableId);

  final String stableId;
}

enum AiroDeviceMergeAction {
  include('include'),
  suppress('suppress'),
  noOp('no_op');

  const AiroDeviceMergeAction(this.stableId);

  final String stableId;
}

enum AiroDeviceMergeCode {
  accepted('accepted'),
  localPreferred('local_preferred'),
  cloudPreferred('cloud_preferred'),
  localOnlyCloudHidden('local_only_cloud_hidden'),
  duplicateMerged('duplicate_merged'),
  revokedDevice('revoked_device'),
  resetRequired('reset_required'),
  stalePresence('stale_presence'),
  expiredAdvertisement('expired_advertisement'),
  untrustedAdvertisement('untrusted_advertisement'),
  incompatibleAdvertisement('incompatible_advertisement'),
  lifecycleUnavailable('lifecycle_unavailable'),
  updateRequired('update_required'),
  missingIdentity('missing_identity'),
  missingPresence('missing_presence'),
  sourceUnavailable('source_unavailable');

  const AiroDeviceMergeCode(this.stableId);

  final String stableId;
}

class AiroLocalDeviceObservation extends Equatable {
  const AiroLocalDeviceObservation({
    required this.advertisement,
    required this.observedAt,
    this.schemaVersion = kAiroDeviceMergeSchemaVersion,
  });

  final String schemaVersion;
  final AiroNodeCapabilityAdvertisement advertisement;
  final DateTime observedAt;

  String get nodeId => advertisement.identity.nodeId;

  bool isExpired(DateTime now) => advertisement.isExpired(now);

  @override
  List<Object?> get props => [schemaVersion, advertisement, observedAt];
}

class AiroCloudDeviceObservation extends Equatable {
  const AiroCloudDeviceObservation({
    required this.record,
    this.presence,
    this.schemaVersion = kAiroDeviceMergeSchemaVersion,
  });

  final String schemaVersion;
  final AiroRegisteredDeviceRecord record;
  final AiroPresenceLease? presence;

  String get nodeId => record.nodeIdentity.nodeId;

  bool isPresenceExpired(DateTime now) {
    final lease = presence;
    return lease == null || lease.isExpired(now);
  }

  @override
  List<Object?> get props => [schemaVersion, record, presence];
}

class AiroMergedDevice extends Equatable {
  AiroMergedDevice({
    required this.stableDeviceId,
    required this.nodeId,
    required this.role,
    required this.productProfile,
    required this.platformCategory,
    required this.reachability,
    required this.primarySource,
    required Set<AiroNodeCapability> capabilities,
    required Iterable<AiroDeviceMergeCode> codes,
    this.presenceStatus,
    this.lifecycle,
    this.lastSeenAt,
    this.schemaVersion = kAiroDeviceMergeSchemaVersion,
  }) : capabilities = Set.unmodifiable(capabilities),
       codes = List.unmodifiable(codes);

  final String schemaVersion;
  final String stableDeviceId;
  final String nodeId;
  final AiroNodeRole role;
  final AiroNodeProductProfile productProfile;
  final AiroNodePlatformCategory platformCategory;
  final AiroDeviceReachability reachability;
  final AiroDeviceObservationSource primarySource;
  final Set<AiroNodeCapability> capabilities;
  final AiroPresenceStatus? presenceStatus;
  final AiroNodeLifecycleState? lifecycle;
  final DateTime? lastSeenAt;
  final List<AiroDeviceMergeCode> codes;

  bool get included => !codes.any(_isSuppressingCode);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'stableDeviceId': stableDeviceId,
      'nodeId': nodeId,
      'role': role.stableId,
      'productProfile': productProfile.stableId,
      'platformCategory': platformCategory.stableId,
      'reachability': reachability.stableId,
      'primarySource': primarySource.stableId,
      'capabilities': capabilities
          .map((capability) => capability.stableId)
          .toList(growable: false),
      'presenceStatus': presenceStatus?.stableId,
      'lifecycle': lifecycle?.stableId,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  static bool _isSuppressingCode(AiroDeviceMergeCode code) {
    return switch (code) {
      AiroDeviceMergeCode.revokedDevice ||
      AiroDeviceMergeCode.resetRequired ||
      AiroDeviceMergeCode.localOnlyCloudHidden ||
      AiroDeviceMergeCode.untrustedAdvertisement ||
      AiroDeviceMergeCode.incompatibleAdvertisement ||
      AiroDeviceMergeCode.missingIdentity ||
      AiroDeviceMergeCode.sourceUnavailable => true,
      AiroDeviceMergeCode.accepted ||
      AiroDeviceMergeCode.localPreferred ||
      AiroDeviceMergeCode.cloudPreferred ||
      AiroDeviceMergeCode.duplicateMerged ||
      AiroDeviceMergeCode.stalePresence ||
      AiroDeviceMergeCode.expiredAdvertisement ||
      AiroDeviceMergeCode.lifecycleUnavailable ||
      AiroDeviceMergeCode.updateRequired ||
      AiroDeviceMergeCode.missingPresence => false,
    };
  }

  @override
  String toString() {
    return 'AiroMergedDevice('
        'stableDeviceId: $stableDeviceId, '
        'nodeId: $nodeId, '
        'role: ${role.stableId}, '
        'productProfile: ${productProfile.stableId}, '
        'platformCategory: ${platformCategory.stableId}, '
        'reachability: ${reachability.stableId}, '
        'primarySource: ${primarySource.stableId}, '
        'codes: ${codes.map((code) => code.stableId).join(',')}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    stableDeviceId,
    nodeId,
    role,
    productProfile,
    platformCategory,
    reachability,
    primarySource,
    capabilities,
    presenceStatus,
    lifecycle,
    lastSeenAt,
    codes,
  ];
}

class AiroDeviceMergeResult extends Equatable {
  AiroDeviceMergeResult({
    required Iterable<AiroMergedDevice> devices,
    required Iterable<AiroDeviceMergeCode> codes,
  }) : devices = List.unmodifiable(devices),
       codes = List.unmodifiable(codes);

  final List<AiroMergedDevice> devices;
  final List<AiroDeviceMergeCode> codes;

  bool get accepted =>
      codes.isEmpty || codes.contains(AiroDeviceMergeCode.accepted);

  @override
  List<Object?> get props => [devices, codes];
}

class AiroDeviceMergePolicy extends Equatable {
  AiroDeviceMergePolicy({
    Set<AiroNodeCapability> requiredCapabilities = const {},
    this.localOnlyMode = false,
    this.requireTrustedLocal = true,
  }) : requiredCapabilities = Set.unmodifiable(requiredCapabilities);

  final Set<AiroNodeCapability> requiredCapabilities;
  final bool localOnlyMode;
  final bool requireTrustedLocal;

  AiroDeviceMergeResult merge({
    required DateTime now,
    Iterable<AiroLocalDeviceObservation> local = const [],
    Iterable<AiroCloudDeviceObservation> cloud = const [],
  }) {
    final localByNode = {for (final item in local) item.nodeId: item};
    final cloudByNode = {for (final item in cloud) item.nodeId: item};
    final nodeIds = <String>{...localByNode.keys, ...cloudByNode.keys};
    final devices = <AiroMergedDevice>[];
    final resultCodes = <AiroDeviceMergeCode>[];

    for (final nodeId in nodeIds) {
      final localObservation = localByNode[nodeId];
      final cloudObservation = cloudByNode[nodeId];
      final merged = _mergeNode(
        nodeId: nodeId,
        local: localObservation,
        cloud: cloudObservation,
        now: now,
      );
      devices.add(merged);
      resultCodes.addAll(
        merged.codes.where((code) => code != AiroDeviceMergeCode.accepted),
      );
    }

    return AiroDeviceMergeResult(
      devices: devices.where((device) => device.included).toList(),
      codes: resultCodes.isEmpty
          ? const [AiroDeviceMergeCode.accepted]
          : resultCodes,
    );
  }

  AiroMergedDevice _mergeNode({
    required String nodeId,
    required AiroLocalDeviceObservation? local,
    required AiroCloudDeviceObservation? cloud,
    required DateTime now,
  }) {
    final codes = <AiroDeviceMergeCode>[];
    final localAd = local?.advertisement;
    final record = cloud?.record;
    final presence = cloud?.presence;

    if (local == null && cloud == null) {
      return _missing(nodeId);
    }

    if (cloud != null) {
      if (record!.isRevokedAt(now)) {
        codes.add(AiroDeviceMergeCode.revokedDevice);
      }
      if (record.state == AiroDeviceRegistrationState.resetRequired) {
        codes.add(AiroDeviceMergeCode.resetRequired);
      }
      if (presence == null) {
        codes.add(AiroDeviceMergeCode.missingPresence);
      } else if (presence.isExpired(now)) {
        codes.add(AiroDeviceMergeCode.stalePresence);
      }
      if (localOnlyMode && local == null) {
        codes.add(AiroDeviceMergeCode.localOnlyCloudHidden);
      }
    }

    if (local != null) {
      if (local.isExpired(now)) {
        codes.add(AiroDeviceMergeCode.expiredAdvertisement);
      }
      if (requireTrustedLocal &&
          !localAd!.trustState.allowsPrivateCompatibility) {
        codes.add(AiroDeviceMergeCode.untrustedAdvertisement);
      }
      if (!localAd!.advertisesAll(requiredCapabilities)) {
        codes.add(AiroDeviceMergeCode.incompatibleAdvertisement);
      }
      if (!localAd.lifecycle.canNegotiate) {
        codes.add(
          localAd.lifecycle == AiroNodeLifecycleState.updateRequired
              ? AiroDeviceMergeCode.updateRequired
              : AiroDeviceMergeCode.lifecycleUnavailable,
        );
      }
    }

    if (!codes.any(AiroMergedDevice._isSuppressingCode)) {
      if (local != null && cloud != null) {
        codes.add(AiroDeviceMergeCode.duplicateMerged);
        codes.add(AiroDeviceMergeCode.localPreferred);
      } else if (local != null) {
        codes.add(AiroDeviceMergeCode.localPreferred);
      } else {
        codes.add(AiroDeviceMergeCode.cloudPreferred);
      }
    }

    final identity = localAd?.identity ?? record!.nodeIdentity;
    final capabilities = <AiroNodeCapability>{
      if (localAd != null) ...localAd.capabilities,
      if (presence != null) ...presence.visibleCapabilities,
    };
    final stableDeviceId = record?.deviceId.value ?? identity.nodeId;

    return AiroMergedDevice(
      stableDeviceId: stableDeviceId,
      nodeId: identity.nodeId,
      role: identity.role,
      productProfile: identity.productProfile,
      platformCategory: identity.platformCategory,
      reachability: _reachability(local, cloud, now),
      primarySource: local != null
          ? AiroDeviceObservationSource.local
          : AiroDeviceObservationSource.cloud,
      capabilities: capabilities,
      presenceStatus: presence?.status,
      lifecycle: localAd?.lifecycle ?? presence?.lifecycle,
      lastSeenAt: presence?.lastHeartbeatAt ?? local?.observedAt,
      codes: codes.isEmpty ? const [AiroDeviceMergeCode.accepted] : codes,
    );
  }

  AiroDeviceReachability _reachability(
    AiroLocalDeviceObservation? local,
    AiroCloudDeviceObservation? cloud,
    DateTime now,
  ) {
    final localAvailable = local != null && !local.isExpired(now);
    final cloudAvailable = cloud != null && !cloud.isPresenceExpired(now);
    if (localAvailable && cloudAvailable) {
      return AiroDeviceReachability.localAndCloud;
    }
    if (localAvailable) return AiroDeviceReachability.localOnly;
    if (cloudAvailable && !localOnlyMode) {
      return AiroDeviceReachability.cloudOnly;
    }
    return AiroDeviceReachability.unavailable;
  }

  AiroMergedDevice _missing(String nodeId) {
    return AiroMergedDevice(
      stableDeviceId: nodeId,
      nodeId: nodeId,
      role: AiroNodeRole.tvReceiver,
      productProfile: AiroNodeProductProfile.liteReceiver,
      platformCategory: AiroNodePlatformCategory.unknown,
      reachability: AiroDeviceReachability.unavailable,
      primarySource: AiroDeviceObservationSource.merged,
      capabilities: const {},
      codes: const [AiroDeviceMergeCode.missingIdentity],
    );
  }

  @override
  List<Object?> get props => [
    requiredCapabilities,
    localOnlyMode,
    requireTrustedLocal,
  ];
}

abstract interface class AiroDeviceMergeSource {
  Future<List<AiroLocalDeviceObservation>> localDevices({
    required DateTime now,
  });

  Future<List<AiroCloudDeviceObservation>> cloudDevices({
    required DateTime now,
  });
}

class AiroNoOpDeviceMergeSource implements AiroDeviceMergeSource {
  const AiroNoOpDeviceMergeSource();

  @override
  Future<List<AiroCloudDeviceObservation>> cloudDevices({
    required DateTime now,
  }) async {
    return const [];
  }

  @override
  Future<List<AiroLocalDeviceObservation>> localDevices({
    required DateTime now,
  }) async {
    return const [];
  }
}

class AiroFakeDeviceMergeSource implements AiroDeviceMergeSource {
  AiroFakeDeviceMergeSource({
    Iterable<AiroLocalDeviceObservation> local = const [],
    Iterable<AiroCloudDeviceObservation> cloud = const [],
  }) : _local = List.of(local),
       _cloud = List.of(cloud);

  final List<AiroLocalDeviceObservation> _local;
  final List<AiroCloudDeviceObservation> _cloud;

  @override
  Future<List<AiroCloudDeviceObservation>> cloudDevices({
    required DateTime now,
  }) async {
    return List.unmodifiable(_cloud);
  }

  @override
  Future<List<AiroLocalDeviceObservation>> localDevices({
    required DateTime now,
  }) async {
    return List.unmodifiable(_local);
  }
}
