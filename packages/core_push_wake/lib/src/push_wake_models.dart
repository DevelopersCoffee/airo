import 'package:core_cloud_orchestration/core_cloud_orchestration.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';

const String kAiroPushWakeSchemaVersion = '1.0.0';
const int kAiroPushWakeProtocolVersion = 1;
const int kAiroPushWakeDefaultMaxPayloadBytes = 2048;

enum AiroPushWakeReason {
  commandReconnect('command_reconnect'),
  sessionRecovery('session_recovery'),
  remoteControl('remote_control'),
  transferPrepare('transfer_prepare'),
  progressSync('progress_sync');

  const AiroPushWakeReason(this.stableId);

  final String stableId;
}

enum AiroPushWakeAction {
  send('send'),
  visibleNotification('visible_notification'),
  localReconnect('local_reconnect'),
  userActionRequired('user_action_required'),
  deny('deny'),
  noOp('no_op');

  const AiroPushWakeAction(this.stableId);

  final String stableId;
}

enum AiroPushWakeCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  expiredRequest('expired_request'),
  unsafeStableId('unsafe_stable_id'),
  payloadTooLarge('payload_too_large'),
  cloudDisabled('cloud_disabled'),
  localOnlyMode('local_only_mode'),
  providerUnavailable('provider_unavailable'),
  unsupportedPlatform('unsupported_platform'),
  lifecycleUnavailable('lifecycle_unavailable'),
  silentWakeUnsupported('silent_wake_unsupported'),
  visibleNotificationRequired('visible_notification_required'),
  localReconnectAvailable('local_reconnect_available'),
  userActionRequired('user_action_required'),
  dispatcherUnavailable('dispatcher_unavailable');

  const AiroPushWakeCode(this.stableId);

  final String stableId;
}

class AiroPushWakeCapabilityProfile extends Equatable {
  const AiroPushWakeCapabilityProfile({
    required this.profileId,
    required this.platformCategory,
    this.supportsSilentWake = false,
    this.supportsVisibleNotification = false,
    this.supportsLocalReconnect = true,
    this.requiresUserVisibleNotification = false,
    this.providerAvailable = true,
    this.maxPayloadBytes = kAiroPushWakeDefaultMaxPayloadBytes,
    this.schemaVersion = kAiroPushWakeSchemaVersion,
  });

  factory AiroPushWakeCapabilityProfile.androidTv({
    bool providerAvailable = true,
  }) {
    return AiroPushWakeCapabilityProfile(
      profileId: 'android-tv-visible-notification',
      platformCategory: AiroNodePlatformCategory.androidTv,
      supportsVisibleNotification: true,
      supportsLocalReconnect: true,
      requiresUserVisibleNotification: true,
      providerAvailable: providerAvailable,
    );
  }

  factory AiroPushWakeCapabilityProfile.fireTv({
    bool providerAvailable = true,
  }) {
    return AiroPushWakeCapabilityProfile(
      profileId: 'fire-tv-user-action',
      platformCategory: AiroNodePlatformCategory.fireTv,
      supportsVisibleNotification: true,
      supportsLocalReconnect: true,
      requiresUserVisibleNotification: true,
      providerAvailable: providerAvailable,
    );
  }

  factory AiroPushWakeCapabilityProfile.mobile({
    required AiroNodePlatformCategory platformCategory,
    bool providerAvailable = true,
  }) {
    return AiroPushWakeCapabilityProfile(
      profileId: '${platformCategory.stableId}-data-push',
      platformCategory: platformCategory,
      supportsSilentWake: true,
      supportsVisibleNotification: true,
      supportsLocalReconnect: false,
      providerAvailable: providerAvailable,
    );
  }

  factory AiroPushWakeCapabilityProfile.homeNode() {
    return const AiroPushWakeCapabilityProfile(
      profileId: 'home-node-local-reconnect',
      platformCategory: AiroNodePlatformCategory.server,
      supportsLocalReconnect: true,
      providerAvailable: false,
    );
  }

  final String schemaVersion;
  final String profileId;
  final AiroNodePlatformCategory platformCategory;
  final bool supportsSilentWake;
  final bool supportsVisibleNotification;
  final bool supportsLocalReconnect;
  final bool requiresUserVisibleNotification;
  final bool providerAvailable;
  final int maxPayloadBytes;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'platformCategory': platformCategory.stableId,
      'supportsSilentWake': supportsSilentWake,
      'supportsVisibleNotification': supportsVisibleNotification,
      'supportsLocalReconnect': supportsLocalReconnect,
      'requiresUserVisibleNotification': requiresUserVisibleNotification,
      'providerAvailable': providerAvailable,
      'maxPayloadBytes': maxPayloadBytes,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    platformCategory,
    supportsSilentWake,
    supportsVisibleNotification,
    supportsLocalReconnect,
    requiresUserVisibleNotification,
    providerAvailable,
    maxPayloadBytes,
  ];
}

class AiroPushWakeRequest extends Equatable {
  const AiroPushWakeRequest({
    required this.wakeId,
    required this.actorNodeId,
    required this.receiverNodeId,
    required this.reason,
    required this.receiverLifecycle,
    required this.issuedAt,
    required this.expiresAt,
    this.payloadBytes = 0,
    this.requiresSilentWake = true,
    this.cloudMode = AiroCloudOrchestrationMode.commandAndState,
    this.schemaVersion = kAiroPushWakeSchemaVersion,
    this.protocolVersion = kAiroPushWakeProtocolVersion,
  });

  final String schemaVersion;
  final int protocolVersion;
  final String wakeId;
  final String actorNodeId;
  final String receiverNodeId;
  final AiroPushWakeReason reason;
  final AiroNodeLifecycleState receiverLifecycle;
  final int payloadBytes;
  final bool requiresSilentWake;
  final AiroCloudOrchestrationMode cloudMode;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    wakeId,
    actorNodeId,
    receiverNodeId,
    reason,
    receiverLifecycle,
    payloadBytes,
    requiresSilentWake,
    cloudMode,
    issuedAt,
    expiresAt,
  ];
}

class AiroPushWakeDecision extends Equatable {
  AiroPushWakeDecision({
    required this.wakeId,
    required this.action,
    required Iterable<AiroPushWakeCode> codes,
    required this.completedAt,
    this.schemaVersion = kAiroPushWakeSchemaVersion,
  }) : codes = List.unmodifiable(codes);

  final String schemaVersion;
  final String wakeId;
  final AiroPushWakeAction action;
  final List<AiroPushWakeCode> codes;
  final DateTime completedAt;

  bool get accepted =>
      action == AiroPushWakeAction.send &&
      codes.length == 1 &&
      codes.single == AiroPushWakeCode.accepted;

  bool has(AiroPushWakeCode code) => codes.contains(code);

  Map<String, Object?> toDiagnosticMap() {
    return {
      'schemaVersion': schemaVersion,
      'wakeId': wakeId,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'completedAt': completedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    wakeId,
    action,
    codes,
    completedAt,
  ];
}

class AiroPushWakePolicy extends Equatable {
  const AiroPushWakePolicy({
    this.acceptedSchemaVersion = kAiroPushWakeSchemaVersion,
    this.minProtocolVersion = kAiroPushWakeProtocolVersion,
    this.maxProtocolVersion = kAiroPushWakeProtocolVersion,
  });

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;

  AiroPushWakeDecision evaluate({
    required AiroPushWakeCapabilityProfile profile,
    required AiroPushWakeRequest request,
    required DateTime now,
  }) {
    final codes = <AiroPushWakeCode>[];
    _addVersionCodes(profile, request, codes);
    _addRequestCodes(profile, request, now, codes);
    _addModeAndPlatformCodes(profile, request, codes);

    return AiroPushWakeDecision(
      wakeId: request.wakeId,
      action: _actionFor(codes),
      codes: codes.isEmpty ? const [AiroPushWakeCode.accepted] : codes,
      completedAt: now,
    );
  }

  void _addVersionCodes(
    AiroPushWakeCapabilityProfile profile,
    AiroPushWakeRequest request,
    List<AiroPushWakeCode> codes,
  ) {
    if (profile.schemaVersion != acceptedSchemaVersion ||
        request.schemaVersion != acceptedSchemaVersion) {
      codes.add(AiroPushWakeCode.schemaMismatch);
    }
    if (request.protocolVersion < minProtocolVersion) {
      codes.add(AiroPushWakeCode.protocolTooOld);
    }
    if (request.protocolVersion > maxProtocolVersion) {
      codes.add(AiroPushWakeCode.protocolTooNew);
    }
  }

  void _addRequestCodes(
    AiroPushWakeCapabilityProfile profile,
    AiroPushWakeRequest request,
    DateTime now,
    List<AiroPushWakeCode> codes,
  ) {
    if (request.isExpired(now)) {
      codes.add(AiroPushWakeCode.expiredRequest);
    }
    if (_unsafeStableId(request.wakeId) ||
        _unsafeStableId(request.actorNodeId) ||
        _unsafeStableId(request.receiverNodeId)) {
      codes.add(AiroPushWakeCode.unsafeStableId);
    }
    if (request.payloadBytes > profile.maxPayloadBytes) {
      codes.add(AiroPushWakeCode.payloadTooLarge);
    }
    if (request.receiverLifecycle == AiroNodeLifecycleState.offline ||
        request.receiverLifecycle == AiroNodeLifecycleState.blocked ||
        request.receiverLifecycle == AiroNodeLifecycleState.incompatible) {
      codes.add(AiroPushWakeCode.lifecycleUnavailable);
    }
  }

  void _addModeAndPlatformCodes(
    AiroPushWakeCapabilityProfile profile,
    AiroPushWakeRequest request,
    List<AiroPushWakeCode> codes,
  ) {
    if (request.cloudMode == AiroCloudOrchestrationMode.disabled) {
      codes.add(AiroPushWakeCode.cloudDisabled);
    }
    if (request.cloudMode == AiroCloudOrchestrationMode.localOnly) {
      codes.add(AiroPushWakeCode.localOnlyMode);
    }
    if (!profile.providerAvailable) {
      codes.add(AiroPushWakeCode.providerUnavailable);
    }
    if (!profile.supportsSilentWake && request.requiresSilentWake) {
      codes.add(AiroPushWakeCode.silentWakeUnsupported);
    }
    if (profile.requiresUserVisibleNotification &&
        profile.supportsVisibleNotification) {
      codes.add(AiroPushWakeCode.visibleNotificationRequired);
    }
    if (profile.supportsLocalReconnect) {
      codes.add(AiroPushWakeCode.localReconnectAvailable);
    }
    if (!profile.supportsSilentWake &&
        !profile.supportsVisibleNotification &&
        !profile.supportsLocalReconnect) {
      codes.add(AiroPushWakeCode.unsupportedPlatform);
    }
  }

  AiroPushWakeAction _actionFor(List<AiroPushWakeCode> codes) {
    if (codes.isEmpty) return AiroPushWakeAction.send;
    if (codes.any(_isHardDeny)) return AiroPushWakeAction.deny;
    if (codes.contains(AiroPushWakeCode.visibleNotificationRequired) &&
        !codes.contains(AiroPushWakeCode.providerUnavailable) &&
        !codes.contains(AiroPushWakeCode.localOnlyMode) &&
        !codes.contains(AiroPushWakeCode.cloudDisabled)) {
      return AiroPushWakeAction.visibleNotification;
    }
    if (codes.contains(AiroPushWakeCode.localReconnectAvailable)) {
      return AiroPushWakeAction.localReconnect;
    }
    return AiroPushWakeAction.userActionRequired;
  }

  bool _isHardDeny(AiroPushWakeCode code) {
    return switch (code) {
      AiroPushWakeCode.accepted ||
      AiroPushWakeCode.cloudDisabled ||
      AiroPushWakeCode.localOnlyMode ||
      AiroPushWakeCode.providerUnavailable ||
      AiroPushWakeCode.silentWakeUnsupported ||
      AiroPushWakeCode.visibleNotificationRequired ||
      AiroPushWakeCode.localReconnectAvailable ||
      AiroPushWakeCode.userActionRequired => false,
      AiroPushWakeCode.schemaMismatch ||
      AiroPushWakeCode.protocolTooOld ||
      AiroPushWakeCode.protocolTooNew ||
      AiroPushWakeCode.expiredRequest ||
      AiroPushWakeCode.unsafeStableId ||
      AiroPushWakeCode.payloadTooLarge ||
      AiroPushWakeCode.unsupportedPlatform ||
      AiroPushWakeCode.lifecycleUnavailable ||
      AiroPushWakeCode.dispatcherUnavailable => true,
    };
  }

  bool _unsafeStableId(String value) {
    return AiroCloudStableValue.validate(value) != null;
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
  ];
}

abstract interface class AiroPushWakeDispatcher {
  Future<AiroPushWakeDecision> dispatch({
    required AiroPushWakeRequest request,
    required DateTime now,
  });
}

class AiroNoOpPushWakeDispatcher implements AiroPushWakeDispatcher {
  const AiroNoOpPushWakeDispatcher();

  @override
  Future<AiroPushWakeDecision> dispatch({
    required AiroPushWakeRequest request,
    required DateTime now,
  }) async {
    return AiroPushWakeDecision(
      wakeId: request.wakeId,
      action: AiroPushWakeAction.noOp,
      codes: const [AiroPushWakeCode.dispatcherUnavailable],
      completedAt: now,
    );
  }
}

class AiroFakePushWakeDispatcher implements AiroPushWakeDispatcher {
  AiroFakePushWakeDispatcher({
    required this.profile,
    this.policy = const AiroPushWakePolicy(),
  });

  final AiroPushWakeCapabilityProfile profile;
  final AiroPushWakePolicy policy;
  final List<AiroPushWakeRequest> acceptedRequests = [];

  @override
  Future<AiroPushWakeDecision> dispatch({
    required AiroPushWakeRequest request,
    required DateTime now,
  }) async {
    final decision = policy.evaluate(
      profile: profile,
      request: request,
      now: now,
    );
    if (decision.accepted) {
      acceptedRequests.add(request);
    }
    return decision;
  }
}
