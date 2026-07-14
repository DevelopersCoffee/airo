import 'package:core_commands/core_commands.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:equatable/equatable.dart';

const String kAiroRemoteControlSchemaVersion = '1.0.0';

enum AiroRemoteControlMode {
  disabled('disabled'),
  localOnly('local_only'),
  sameAccountRemote('same_account_remote'),
  approvalRequired('approval_required');

  const AiroRemoteControlMode(this.stableId);

  final String stableId;
}

enum AiroRemoteControlDecisionAction {
  allow('allow'),
  requireApproval('require_approval'),
  deny('deny'),
  noOp('no_op');

  const AiroRemoteControlDecisionAction(this.stableId);

  final String stableId;
}

enum AiroRemoteControlProfileKind {
  standard('standard'),
  child('child'),
  restricted('restricted');

  const AiroRemoteControlProfileKind(this.stableId);

  final String stableId;
}

enum AiroRemoteControlApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  expired('expired'),
  revoked('revoked');

  const AiroRemoteControlApprovalStatus(this.stableId);

  final String stableId;
}

enum AiroRemoteControlPermissionCode {
  accepted('accepted'),
  remoteControlDisabled('remote_control_disabled'),
  localOnlyCloudBlocked('local_only_cloud_blocked'),
  accountMismatch('account_mismatch'),
  trustedDeviceMissing('trusted_device_missing'),
  trustedDeviceMismatch('trusted_device_mismatch'),
  accessDenied('access_denied'),
  trustLevelInsufficient('trust_level_insufficient'),
  keyMissing('key_missing'),
  keyUnsupported('key_unsupported'),
  keyNotYetValid('key_not_yet_valid'),
  keyExpired('key_expired'),
  keyRevoked('key_revoked'),
  keyRotationRequired('key_rotation_required'),
  receiverMissing('receiver_missing'),
  receiverMismatch('receiver_mismatch'),
  receiverUnavailable('receiver_unavailable'),
  receiverCapabilityMissing('receiver_capability_missing'),
  commandSenderMismatch('command_sender_mismatch'),
  commandExpired('command_expired'),
  commandTargetMismatch('command_target_mismatch'),
  commandScopeMissing('command_scope_missing'),
  commandUnsafePayload('command_unsafe_payload'),
  commandDenied('command_denied'),
  profileRouteRestricted('profile_route_restricted'),
  profileActionRestricted('profile_action_restricted'),
  approvalRequired('approval_required'),
  approvalPending('approval_pending'),
  approvalRejected('approval_rejected'),
  approvalExpired('approval_expired'),
  approvalRevoked('approval_revoked'),
  sessionExpired('session_expired'),
  sessionReceiverMismatch('session_receiver_mismatch'),
  sessionMemberMissing('session_member_missing'),
  sessionMemberExpired('session_member_expired'),
  sessionMemberRevoked('session_member_revoked'),
  sessionPermissionMissing('session_permission_missing'),
  sourceUnavailable('source_unavailable');

  const AiroRemoteControlPermissionCode(this.stableId);

  final String stableId;
}

class AiroRemoteControlSettings extends Equatable {
  AiroRemoteControlSettings({
    required this.mode,
    Set<AiroCommandDeliveryPath> allowedRemotePaths = const {
      AiroCommandDeliveryPath.cloud,
      AiroCommandDeliveryPath.recoveryReplay,
    },
    this.minimumTrustLevel = AiroTrustedDeviceTrustLevel.paired,
    this.requiresKeyDescriptor = true,
    this.keyRotationInterval,
    this.schemaVersion = kAiroRemoteControlSchemaVersion,
  }) : allowedRemotePaths = Set.unmodifiable(allowedRemotePaths);

  final String schemaVersion;
  final AiroRemoteControlMode mode;
  final Set<AiroCommandDeliveryPath> allowedRemotePaths;
  final AiroTrustedDeviceTrustLevel minimumTrustLevel;
  final bool requiresKeyDescriptor;
  final Duration? keyRotationInterval;

  bool isRemotePath(AiroCommandDeliveryPath path) {
    return path == AiroCommandDeliveryPath.cloud ||
        path == AiroCommandDeliveryPath.recoveryReplay;
  }

  bool allowsPath(AiroCommandDeliveryPath path) {
    if (!isRemotePath(path)) return true;
    return allowedRemotePaths.contains(path);
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    mode,
    allowedRemotePaths,
    minimumTrustLevel,
    requiresKeyDescriptor,
    keyRotationInterval,
  ];
}

class AiroRemoteControlProfilePolicy extends Equatable {
  AiroRemoteControlProfilePolicy({
    required this.kind,
    Set<AiroCommandAction> allowedActions = const {
      AiroCommandAction.play,
      AiroCommandAction.pause,
      AiroCommandAction.stop,
      AiroCommandAction.seek,
      AiroCommandAction.select,
      AiroCommandAction.back,
      AiroCommandAction.home,
      AiroCommandAction.focus,
      AiroCommandAction.submitTextHandle,
      AiroCommandAction.searchHandle,
      AiroCommandAction.askAssistantHandle,
      AiroCommandAction.refreshCapabilities,
      AiroCommandAction.diagnosticsPing,
    },
    Set<AiroPairingScope> allowedScopes = const {
      AiroPairingScope.playbackControl,
      AiroPairingScope.textInput,
      AiroPairingScope.sourceSelection,
      AiroPairingScope.diagnostics,
      AiroPairingScope.companionSearch,
      AiroPairingScope.playbackTicketIssue,
    },
    this.allowsRemotePaths = true,
    this.schemaVersion = kAiroRemoteControlSchemaVersion,
  }) : allowedActions = Set.unmodifiable(allowedActions),
       allowedScopes = Set.unmodifiable(allowedScopes);

  factory AiroRemoteControlProfilePolicy.standard() {
    return AiroRemoteControlProfilePolicy(
      kind: AiroRemoteControlProfileKind.standard,
    );
  }

  factory AiroRemoteControlProfilePolicy.child() {
    return AiroRemoteControlProfilePolicy(
      kind: AiroRemoteControlProfileKind.child,
      allowsRemotePaths: false,
      allowedActions: const {
        AiroCommandAction.play,
        AiroCommandAction.pause,
        AiroCommandAction.stop,
        AiroCommandAction.seek,
        AiroCommandAction.select,
        AiroCommandAction.back,
        AiroCommandAction.home,
        AiroCommandAction.focus,
      },
      allowedScopes: const {AiroPairingScope.playbackControl},
    );
  }

  factory AiroRemoteControlProfilePolicy.restricted() {
    return AiroRemoteControlProfilePolicy(
      kind: AiroRemoteControlProfileKind.restricted,
      allowsRemotePaths: false,
      allowedActions: const {
        AiroCommandAction.pause,
        AiroCommandAction.stop,
        AiroCommandAction.back,
        AiroCommandAction.home,
      },
      allowedScopes: const {AiroPairingScope.playbackControl},
    );
  }

  final String schemaVersion;
  final AiroRemoteControlProfileKind kind;
  final Set<AiroCommandAction> allowedActions;
  final Set<AiroPairingScope> allowedScopes;
  final bool allowsRemotePaths;

  AiroRemoteControlPermissionCode? blockerFor(
    AiroCommandEnvelope envelope, {
    required bool remotePath,
  }) {
    if (remotePath && !allowsRemotePaths) {
      return AiroRemoteControlPermissionCode.profileRouteRestricted;
    }
    if (!allowedActions.contains(envelope.action) ||
        !allowedScopes.contains(envelope.requiredScope)) {
      return AiroRemoteControlPermissionCode.profileActionRestricted;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    kind,
    allowedActions,
    allowedScopes,
    allowsRemotePaths,
  ];
}

class AiroRemoteControlApprovalGrant extends Equatable {
  AiroRemoteControlApprovalGrant({
    required this.grantId,
    required this.controllerNodeId,
    required this.receiverNodeId,
    required this.status,
    required this.issuedAt,
    required this.expiresAt,
    Set<AiroCommandAction> approvedActions = const {},
    this.revokedAt,
    this.schemaVersion = kAiroRemoteControlSchemaVersion,
  }) : approvedActions = Set.unmodifiable(approvedActions);

  final String schemaVersion;
  final String grantId;
  final String controllerNodeId;
  final String receiverNodeId;
  final AiroRemoteControlApprovalStatus status;
  final Set<AiroCommandAction> approvedActions;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  AiroRemoteControlApprovalStatus statusAt(DateTime now) {
    if (revokedAt != null && !now.isBefore(revokedAt!)) {
      return AiroRemoteControlApprovalStatus.revoked;
    }
    if (status == AiroRemoteControlApprovalStatus.approved && isExpired(now)) {
      return AiroRemoteControlApprovalStatus.expired;
    }
    return status;
  }

  bool approves({
    required AiroCommandEnvelope envelope,
    required DateTime now,
  }) {
    if (statusAt(now) != AiroRemoteControlApprovalStatus.approved) {
      return false;
    }
    if (controllerNodeId != envelope.senderNodeId ||
        receiverNodeId != envelope.targetNodeId) {
      return false;
    }
    return approvedActions.isEmpty || approvedActions.contains(envelope.action);
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    grantId,
    controllerNodeId,
    receiverNodeId,
    status,
    approvedActions,
    issuedAt,
    expiresAt,
    revokedAt,
  ];
}

class AiroRemoteControlRequest extends Equatable {
  const AiroRemoteControlRequest({
    required this.controllerAccountId,
    required this.receiverAccountId,
    required this.controllerDeviceId,
    required this.receiverDeviceId,
    required this.controllerNodeId,
    required this.receiverNodeId,
    required this.envelope,
    this.trustedDevice,
    this.receiverAdvertisement,
    this.sessionSnapshot,
    this.approvalGrant,
    this.schemaVersion = kAiroRemoteControlSchemaVersion,
  });

  final String schemaVersion;
  final String controllerAccountId;
  final String receiverAccountId;
  final String controllerDeviceId;
  final String receiverDeviceId;
  final String controllerNodeId;
  final String receiverNodeId;
  final AiroCommandEnvelope envelope;
  final AiroTrustedDeviceRecord? trustedDevice;
  final AiroNodeCapabilityAdvertisement? receiverAdvertisement;
  final AiroUniversalPlaybackSessionSnapshot? sessionSnapshot;
  final AiroRemoteControlApprovalGrant? approvalGrant;

  bool get sameAccount => controllerAccountId == receiverAccountId;

  @override
  List<Object?> get props => [
    schemaVersion,
    controllerAccountId,
    receiverAccountId,
    controllerDeviceId,
    receiverDeviceId,
    controllerNodeId,
    receiverNodeId,
    envelope,
    trustedDevice,
    receiverAdvertisement,
    sessionSnapshot,
    approvalGrant,
  ];
}

class AiroRemoteControlDecision extends Equatable {
  AiroRemoteControlDecision({
    required this.action,
    required Iterable<AiroRemoteControlPermissionCode> codes,
    required this.commandResult,
    required this.mode,
    required this.deliveryPath,
    this.schemaVersion = kAiroRemoteControlSchemaVersion,
  }) : codes = List.unmodifiable(codes);

  final String schemaVersion;
  final AiroRemoteControlDecisionAction action;
  final List<AiroRemoteControlPermissionCode> codes;
  final AiroCommandResult commandResult;
  final AiroRemoteControlMode mode;
  final AiroCommandDeliveryPath deliveryPath;

  bool get allowed =>
      action == AiroRemoteControlDecisionAction.allow &&
      codes.length == 1 &&
      codes.single == AiroRemoteControlPermissionCode.accepted;

  bool has(AiroRemoteControlPermissionCode code) => codes.contains(code);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'commandId': commandResult.commandId,
      'commandStatus': commandResult.status.stableId,
      'mode': mode.stableId,
      'deliveryPath': deliveryPath.stableId,
    };
  }

  @override
  String toString() {
    return 'AiroRemoteControlDecision('
        'action: ${action.stableId}, '
        'codes: ${codes.map((code) => code.stableId).join(',')}, '
        'commandId: ${commandResult.commandId}, '
        'mode: ${mode.stableId}, '
        'deliveryPath: ${deliveryPath.stableId}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    action,
    codes,
    commandResult,
    mode,
    deliveryPath,
  ];
}

class AiroRemoteControlPermissionPolicy extends Equatable {
  const AiroRemoteControlPermissionPolicy({
    required this.settings,
    required this.profilePolicy,
  });

  final AiroRemoteControlSettings settings;
  final AiroRemoteControlProfilePolicy profilePolicy;

  AiroRemoteControlDecision evaluate({
    required AiroRemoteControlRequest request,
    required DateTime now,
  }) {
    final codes = <AiroRemoteControlPermissionCode>[];
    final envelope = request.envelope;
    final remotePath = settings.isRemotePath(envelope.deliveryPath);

    _evaluateMode(codes, request);
    _evaluateTrust(codes, request, now);
    _evaluateReceiver(codes, request, now);
    _evaluateCommand(codes, request, now);
    _evaluateProfile(codes, envelope, remotePath: remotePath);
    _evaluateSession(codes, request, now);
    _evaluateApproval(codes, request, now, remotePath: remotePath);

    if (codes.isEmpty) {
      codes.add(AiroRemoteControlPermissionCode.accepted);
      return _decision(
        action: AiroRemoteControlDecisionAction.allow,
        codes: codes,
        envelope: envelope,
        status: AiroCommandResultStatus.accepted,
        now: now,
      );
    }

    if (_onlyRequiresApproval(codes)) {
      return _decision(
        action: AiroRemoteControlDecisionAction.requireApproval,
        codes: codes,
        envelope: envelope,
        status: AiroCommandResultStatus.authRequired,
        now: now,
      );
    }

    return _decision(
      action: AiroRemoteControlDecisionAction.deny,
      codes: codes,
      envelope: envelope,
      status: _statusFor(codes),
      now: now,
    );
  }

  void _evaluateMode(
    List<AiroRemoteControlPermissionCode> codes,
    AiroRemoteControlRequest request,
  ) {
    final deliveryPath = request.envelope.deliveryPath;
    final remotePath = settings.isRemotePath(deliveryPath);

    if (settings.mode == AiroRemoteControlMode.disabled) {
      codes.add(AiroRemoteControlPermissionCode.remoteControlDisabled);
    }
    if (settings.mode == AiroRemoteControlMode.localOnly && remotePath) {
      codes.add(AiroRemoteControlPermissionCode.localOnlyCloudBlocked);
    }
    if (!settings.allowsPath(deliveryPath)) {
      codes.add(AiroRemoteControlPermissionCode.localOnlyCloudBlocked);
    }
    if (remotePath && !request.sameAccount) {
      codes.add(AiroRemoteControlPermissionCode.accountMismatch);
    }
  }

  void _evaluateTrust(
    List<AiroRemoteControlPermissionCode> codes,
    AiroRemoteControlRequest request,
    DateTime now,
  ) {
    final record = request.trustedDevice;
    if (record == null) {
      codes.add(AiroRemoteControlPermissionCode.trustedDeviceMissing);
      return;
    }
    if (record.controllerDeviceId != request.controllerDeviceId ||
        record.receiverDeviceId != request.receiverDeviceId) {
      codes.add(AiroRemoteControlPermissionCode.trustedDeviceMismatch);
    }

    final result = AiroTrustedDeviceSecurityPolicy(
      requiredScope: request.envelope.requiredScope,
      minimumTrustLevel: settings.minimumTrustLevel,
      keyRotationInterval: settings.keyRotationInterval,
      requiresKeyDescriptor: settings.requiresKeyDescriptor,
    ).evaluate(record: record, now: now);

    for (final blocker in result.blockers) {
      codes.add(_remoteCodeForTrustBlocker(blocker));
    }
  }

  void _evaluateReceiver(
    List<AiroRemoteControlPermissionCode> codes,
    AiroRemoteControlRequest request,
    DateTime now,
  ) {
    final advertisement = request.receiverAdvertisement;
    if (advertisement == null) {
      codes.add(AiroRemoteControlPermissionCode.receiverMissing);
      return;
    }
    if (advertisement.identity.nodeId != request.receiverNodeId) {
      codes.add(AiroRemoteControlPermissionCode.receiverMismatch);
    }
    if (advertisement.isExpired(now) || !advertisement.lifecycle.canNegotiate) {
      codes.add(AiroRemoteControlPermissionCode.receiverUnavailable);
    }
    if (!advertisement.advertises(AiroNodeCapability.remoteControl) ||
        !advertisement.advertises(AiroNodeCapability.commandRouting)) {
      codes.add(AiroRemoteControlPermissionCode.receiverCapabilityMissing);
    }
  }

  void _evaluateCommand(
    List<AiroRemoteControlPermissionCode> codes,
    AiroRemoteControlRequest request,
    DateTime now,
  ) {
    final envelope = request.envelope;
    if (envelope.senderNodeId != request.controllerNodeId) {
      codes.add(AiroRemoteControlPermissionCode.commandSenderMismatch);
    }

    final grantedScopes =
        request.trustedDevice?.scopes ?? const <AiroPairingScope>{};
    final result = AiroCommandValidationPolicy(
      grantedScopes: grantedScopes,
      targetNodeId: request.receiverNodeId,
    ).evaluate(envelope: envelope, now: now);

    for (final blocker in result.blockers) {
      codes.add(_remoteCodeForCommandBlocker(blocker.code));
    }
  }

  void _evaluateProfile(
    List<AiroRemoteControlPermissionCode> codes,
    AiroCommandEnvelope envelope, {
    required bool remotePath,
  }) {
    final code = profilePolicy.blockerFor(envelope, remotePath: remotePath);
    if (code != null) codes.add(code);
  }

  void _evaluateSession(
    List<AiroRemoteControlPermissionCode> codes,
    AiroRemoteControlRequest request,
    DateTime now,
  ) {
    final session = request.sessionSnapshot;
    if (session == null) return;
    if (session.isExpired(now)) {
      codes.add(AiroRemoteControlPermissionCode.sessionExpired);
    }
    if (session.activeReceiverNodeId != request.receiverNodeId) {
      codes.add(AiroRemoteControlPermissionCode.sessionReceiverMismatch);
    }

    final member = session.memberFor(request.controllerNodeId);
    if (member == null) {
      codes.add(AiroRemoteControlPermissionCode.sessionMemberMissing);
      return;
    }
    if (member.isExpired(now)) {
      codes.add(AiroRemoteControlPermissionCode.sessionMemberExpired);
    }
    if (member.isRevoked(now)) {
      codes.add(AiroRemoteControlPermissionCode.sessionMemberRevoked);
    }
    final permission = _sessionPermissionFor(request.envelope);
    if (!member.permissions.contains(permission)) {
      codes.add(AiroRemoteControlPermissionCode.sessionPermissionMissing);
    }
  }

  void _evaluateApproval(
    List<AiroRemoteControlPermissionCode> codes,
    AiroRemoteControlRequest request,
    DateTime now, {
    required bool remotePath,
  }) {
    if (settings.mode != AiroRemoteControlMode.approvalRequired ||
        !remotePath) {
      return;
    }

    final grant = request.approvalGrant;
    if (grant == null) {
      codes.add(AiroRemoteControlPermissionCode.approvalRequired);
      return;
    }

    switch (grant.statusAt(now)) {
      case AiroRemoteControlApprovalStatus.approved:
        if (!grant.approves(envelope: request.envelope, now: now)) {
          codes.add(AiroRemoteControlPermissionCode.approvalRequired);
        }
      case AiroRemoteControlApprovalStatus.pending:
        codes.add(AiroRemoteControlPermissionCode.approvalPending);
      case AiroRemoteControlApprovalStatus.rejected:
        codes.add(AiroRemoteControlPermissionCode.approvalRejected);
      case AiroRemoteControlApprovalStatus.expired:
        codes.add(AiroRemoteControlPermissionCode.approvalExpired);
      case AiroRemoteControlApprovalStatus.revoked:
        codes.add(AiroRemoteControlPermissionCode.approvalRevoked);
    }
  }

  AiroRemoteControlDecision _decision({
    required AiroRemoteControlDecisionAction action,
    required List<AiroRemoteControlPermissionCode> codes,
    required AiroCommandEnvelope envelope,
    required AiroCommandResultStatus status,
    required DateTime now,
  }) {
    return AiroRemoteControlDecision(
      action: action,
      codes: codes,
      mode: settings.mode,
      deliveryPath: envelope.deliveryPath,
      commandResult: AiroCommandResult(
        commandId: envelope.commandId,
        status: status,
        code: codes.map((code) => code.stableId).join(','),
        completedAt: now,
      ),
    );
  }

  bool _onlyRequiresApproval(List<AiroRemoteControlPermissionCode> codes) {
    return codes.isNotEmpty &&
        codes.every(
          (code) =>
              code == AiroRemoteControlPermissionCode.approvalRequired ||
              code == AiroRemoteControlPermissionCode.approvalPending,
        );
  }

  AiroCommandResultStatus _statusFor(
    List<AiroRemoteControlPermissionCode> codes,
  ) {
    if (codes.contains(AiroRemoteControlPermissionCode.commandExpired) ||
        codes.contains(AiroRemoteControlPermissionCode.approvalExpired) ||
        codes.contains(AiroRemoteControlPermissionCode.sessionExpired)) {
      return AiroCommandResultStatus.expired;
    }
    if (codes.contains(AiroRemoteControlPermissionCode.receiverUnavailable) ||
        codes.contains(AiroRemoteControlPermissionCode.receiverMissing)) {
      return AiroCommandResultStatus.receiverUnavailable;
    }
    if (codes.contains(
      AiroRemoteControlPermissionCode.receiverCapabilityMissing,
    )) {
      return AiroCommandResultStatus.unsupported;
    }
    if (codes.contains(AiroRemoteControlPermissionCode.accessDenied) ||
        codes.contains(AiroRemoteControlPermissionCode.trustedDeviceMissing) ||
        codes.contains(
          AiroRemoteControlPermissionCode.trustLevelInsufficient,
        )) {
      return AiroCommandResultStatus.authRequired;
    }
    return AiroCommandResultStatus.rejected;
  }

  AiroRemoteControlPermissionCode _remoteCodeForTrustBlocker(
    AiroTrustedDeviceSecurityBlocker blocker,
  ) {
    return switch (blocker.code) {
      AiroTrustedDeviceSecurityCode.accepted =>
        AiroRemoteControlPermissionCode.accepted,
      AiroTrustedDeviceSecurityCode.accessDenied =>
        AiroRemoteControlPermissionCode.accessDenied,
      AiroTrustedDeviceSecurityCode.trustLevelInsufficient =>
        AiroRemoteControlPermissionCode.trustLevelInsufficient,
      AiroTrustedDeviceSecurityCode.keyMissing =>
        AiroRemoteControlPermissionCode.keyMissing,
      AiroTrustedDeviceSecurityCode.keyUnsupported =>
        AiroRemoteControlPermissionCode.keyUnsupported,
      AiroTrustedDeviceSecurityCode.keyNotYetValid =>
        AiroRemoteControlPermissionCode.keyNotYetValid,
      AiroTrustedDeviceSecurityCode.keyExpired =>
        AiroRemoteControlPermissionCode.keyExpired,
      AiroTrustedDeviceSecurityCode.keyRevoked =>
        AiroRemoteControlPermissionCode.keyRevoked,
      AiroTrustedDeviceSecurityCode.keyRotationRequired =>
        AiroRemoteControlPermissionCode.keyRotationRequired,
    };
  }

  AiroRemoteControlPermissionCode _remoteCodeForCommandBlocker(
    AiroCommandValidationCode code,
  ) {
    return switch (code) {
      AiroCommandValidationCode.accepted =>
        AiroRemoteControlPermissionCode.accepted,
      AiroCommandValidationCode.expired =>
        AiroRemoteControlPermissionCode.commandExpired,
      AiroCommandValidationCode.targetMismatch =>
        AiroRemoteControlPermissionCode.commandTargetMismatch,
      AiroCommandValidationCode.scopeMissing =>
        AiroRemoteControlPermissionCode.commandScopeMissing,
      AiroCommandValidationCode.unsafePayload =>
        AiroRemoteControlPermissionCode.commandUnsafePayload,
      AiroCommandValidationCode.schemaMismatch ||
      AiroCommandValidationCode.protocolTooOld ||
      AiroCommandValidationCode.protocolTooNew ||
      AiroCommandValidationCode.duplicateIdempotencyKey =>
        AiroRemoteControlPermissionCode.commandDenied,
    };
  }

  AiroUniversalSessionPermission _sessionPermissionFor(
    AiroCommandEnvelope envelope,
  ) {
    if (envelope.requiredScope == AiroPairingScope.sourceSelection) {
      return AiroUniversalSessionPermission.transferSession;
    }
    return AiroUniversalSessionPermission.requestDesiredState;
  }

  @override
  List<Object?> get props => [settings, profilePolicy];
}

abstract interface class AiroRemoteControlPermissionSource {
  Future<AiroRemoteControlDecision> authorize({
    required AiroRemoteControlRequest request,
    required DateTime now,
  });
}

class AiroNoOpRemoteControlPermissionSource
    implements AiroRemoteControlPermissionSource {
  const AiroNoOpRemoteControlPermissionSource();

  @override
  Future<AiroRemoteControlDecision> authorize({
    required AiroRemoteControlRequest request,
    required DateTime now,
  }) async {
    return AiroRemoteControlDecision(
      action: AiroRemoteControlDecisionAction.noOp,
      codes: const [AiroRemoteControlPermissionCode.sourceUnavailable],
      mode: AiroRemoteControlMode.disabled,
      deliveryPath: request.envelope.deliveryPath,
      commandResult: AiroCommandResult(
        commandId: request.envelope.commandId,
        status: AiroCommandResultStatus.receiverUnavailable,
        code: AiroRemoteControlPermissionCode.sourceUnavailable.stableId,
        completedAt: now,
      ),
    );
  }
}

class AiroFakeRemoteControlPermissionSource
    implements AiroRemoteControlPermissionSource {
  const AiroFakeRemoteControlPermissionSource({required this.policy});

  final AiroRemoteControlPermissionPolicy policy;

  @override
  Future<AiroRemoteControlDecision> authorize({
    required AiroRemoteControlRequest request,
    required DateTime now,
  }) async {
    return policy.evaluate(request: request, now: now);
  }
}
