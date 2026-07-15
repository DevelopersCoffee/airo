import 'package:core_commands/core_commands.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:core_remote_control/core_remote_control.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);

  group('AiroRemoteControlPermissionPolicy', () {
    test('blocks cloud commands in local-only mode but allows LAN', () {
      final policy = _policy(mode: AiroRemoteControlMode.localOnly);
      final cloudDecision = policy.evaluate(
        request: _request(now, deliveryPath: AiroCommandDeliveryPath.cloud),
        now: now,
      );
      final lanDecision = policy.evaluate(
        request: _request(now, deliveryPath: AiroCommandDeliveryPath.lan),
        now: now,
      );

      expect(cloudDecision.action, AiroRemoteControlDecisionAction.deny);
      expect(
        cloudDecision.has(
          AiroRemoteControlPermissionCode.localOnlyCloudBlocked,
        ),
        isTrue,
      );
      expect(lanDecision.allowed, isTrue);
      expect(
        lanDecision.commandResult.status,
        AiroCommandResultStatus.accepted,
      );
    });

    test(
      'allows same-account remote command after trust and capability checks',
      () {
        final decision = _policy(mode: AiroRemoteControlMode.sameAccountRemote)
            .evaluate(
              request: _request(
                now,
                deliveryPath: AiroCommandDeliveryPath.cloud,
              ),
              now: now,
            );

        expect(decision.allowed, isTrue);
        expect(decision.codes, [AiroRemoteControlPermissionCode.accepted]);
      },
    );

    test('requires approval for remote route until approved grant exists', () {
      final policy = _policy(mode: AiroRemoteControlMode.approvalRequired);
      final pending = policy.evaluate(
        request: _request(now, deliveryPath: AiroCommandDeliveryPath.cloud),
        now: now,
      );
      final approved = policy.evaluate(
        request: _request(
          now,
          deliveryPath: AiroCommandDeliveryPath.cloud,
          approvalGrant: _approval(now),
        ),
        now: now,
      );

      expect(pending.action, AiroRemoteControlDecisionAction.requireApproval);
      expect(pending.codes, [AiroRemoteControlPermissionCode.approvalRequired]);
      expect(approved.allowed, isTrue);
    });

    test('child profile blocks cloud routes and elevated actions', () {
      final cloudDecision =
          _policy(
            mode: AiroRemoteControlMode.sameAccountRemote,
            profilePolicy: AiroRemoteControlProfilePolicy.child(),
          ).evaluate(
            request: _request(now, deliveryPath: AiroCommandDeliveryPath.cloud),
            now: now,
          );
      final sourceDecision =
          _policy(
            profilePolicy: AiroRemoteControlProfilePolicy.child(),
          ).evaluate(
            request: _request(
              now,
              action: AiroCommandAction.refreshCapabilities,
              requiredScope: AiroPairingScope.diagnostics,
            ),
            now: now,
          );

      expect(
        cloudDecision.has(
          AiroRemoteControlPermissionCode.profileRouteRestricted,
        ),
        isTrue,
      );
      expect(
        sourceDecision.has(
          AiroRemoteControlPermissionCode.profileActionRestricted,
        ),
        isTrue,
      );
    });

    test('denies revoked trusted device before command dispatch', () {
      final decision = _policy().evaluate(
        request: _request(
          now,
          trustedDevice: _trustedDevice(now, revokedAt: now),
        ),
        now: now,
      );

      expect(decision.action, AiroRemoteControlDecisionAction.deny);
      expect(
        decision.has(AiroRemoteControlPermissionCode.accessDenied),
        isTrue,
      );
      expect(
        decision.commandResult.status,
        AiroCommandResultStatus.authRequired,
      );
    });

    test('denies missing receiver capability and unavailable lifecycle', () {
      final missingCapability = _policy().evaluate(
        request: _request(
          now,
          receiverAdvertisement: _receiverAdvertisement(
            now,
            capabilities: const {AiroNodeCapability.playback},
          ),
        ),
        now: now,
      );
      final unavailable = _policy().evaluate(
        request: _request(
          now,
          receiverAdvertisement: _receiverAdvertisement(
            now,
            lifecycle: AiroNodeLifecycleState.offline,
          ),
        ),
        now: now,
      );

      expect(
        missingCapability.has(
          AiroRemoteControlPermissionCode.receiverCapabilityMissing,
        ),
        isTrue,
      );
      expect(
        missingCapability.commandResult.status,
        AiroCommandResultStatus.unsupported,
      );
      expect(
        unavailable.has(AiroRemoteControlPermissionCode.receiverUnavailable),
        isTrue,
      );
    });

    test('enforces optional session membership permissions', () {
      final missingMember = _policy().evaluate(
        request: _request(now, sessionSnapshot: _session(now, members: {})),
        now: now,
      );
      final missingPermission = _policy().evaluate(
        request: _request(
          now,
          sessionSnapshot: _session(
            now,
            members: {
              _member(
                now,
                permissions: const {
                  AiroUniversalSessionPermission.recoverSnapshot,
                },
              ),
            },
          ),
        ),
        now: now,
      );

      expect(
        missingMember.has(AiroRemoteControlPermissionCode.sessionMemberMissing),
        isTrue,
      );
      expect(
        missingPermission.has(
          AiroRemoteControlPermissionCode.sessionPermissionMissing,
        ),
        isTrue,
      );
    });

    test('public map and toString expose only stable decision metadata', () {
      final decision = _policy().evaluate(
        request: _request(
          now,
          envelope: _envelope(
            now,
            payload: AiroCommandPayload.safe(const {'handle': 'opaque-ref-1'}),
          ),
        ),
        now: now,
      );

      expect(decision.toPublicMap(), {
        'schemaVersion': kAiroRemoteControlSchemaVersion,
        'action': 'allow',
        'codes': ['accepted'],
        'commandId': 'command-1',
        'commandStatus': 'accepted',
        'mode': 'same_account_remote',
        'deliveryPath': 'lan',
      });
      expect(decision.toString(), isNot(contains('opaque-ref-1')));
    });
  });

  group('AiroRemoteControlPermissionSource', () {
    test('fake source delegates to deterministic policy', () async {
      final source = AiroFakeRemoteControlPermissionSource(
        policy: _policy(mode: AiroRemoteControlMode.localOnly),
      );

      final decision = await source.authorize(
        request: _request(now, deliveryPath: AiroCommandDeliveryPath.cloud),
        now: now,
      );

      expect(
        decision.has(AiroRemoteControlPermissionCode.localOnlyCloudBlocked),
        isTrue,
      );
    });

    test('no-op source fails closed', () async {
      const source = AiroNoOpRemoteControlPermissionSource();

      final decision = await source.authorize(request: _request(now), now: now);

      expect(decision.action, AiroRemoteControlDecisionAction.noOp);
      expect(decision.codes, [
        AiroRemoteControlPermissionCode.sourceUnavailable,
      ]);
      expect(
        decision.commandResult.status,
        AiroCommandResultStatus.receiverUnavailable,
      );
    });
  });
}

AiroRemoteControlPermissionPolicy _policy({
  AiroRemoteControlMode mode = AiroRemoteControlMode.sameAccountRemote,
  AiroRemoteControlProfilePolicy? profilePolicy,
}) {
  return AiroRemoteControlPermissionPolicy(
    settings: AiroRemoteControlSettings(mode: mode),
    profilePolicy: profilePolicy ?? AiroRemoteControlProfilePolicy.standard(),
  );
}

AiroRemoteControlRequest _request(
  DateTime now, {
  AiroCommandDeliveryPath deliveryPath = AiroCommandDeliveryPath.lan,
  AiroCommandAction action = AiroCommandAction.play,
  AiroPairingScope requiredScope = AiroPairingScope.playbackControl,
  AiroTrustedDeviceRecord? trustedDevice,
  AiroNodeCapabilityAdvertisement? receiverAdvertisement,
  AiroUniversalPlaybackSessionSnapshot? sessionSnapshot,
  AiroRemoteControlApprovalGrant? approvalGrant,
  AiroCommandEnvelope? envelope,
}) {
  return AiroRemoteControlRequest(
    controllerAccountId: 'account-1',
    receiverAccountId: 'account-1',
    controllerDeviceId: 'phone-device-1',
    receiverDeviceId: 'tv-device-1',
    controllerNodeId: 'phone-node-1',
    receiverNodeId: 'tv-node-1',
    envelope:
        envelope ??
        _envelope(
          now,
          deliveryPath: deliveryPath,
          action: action,
          requiredScope: requiredScope,
        ),
    trustedDevice:
        trustedDevice ??
        _trustedDevice(
          now,
          scopes: {requiredScope, AiroPairingScope.playbackControl},
        ),
    receiverAdvertisement: receiverAdvertisement ?? _receiverAdvertisement(now),
    sessionSnapshot: sessionSnapshot,
    approvalGrant: approvalGrant,
  );
}

AiroCommandEnvelope _envelope(
  DateTime now, {
  AiroCommandDeliveryPath deliveryPath = AiroCommandDeliveryPath.lan,
  AiroCommandAction action = AiroCommandAction.play,
  AiroPairingScope requiredScope = AiroPairingScope.playbackControl,
  AiroCommandPayload? payload,
}) {
  return AiroCommandEnvelope(
    commandId: 'command-1',
    sessionId: 'session-1',
    senderNodeId: 'phone-node-1',
    targetNodeId: 'tv-node-1',
    kind: AiroCommandKind.playback,
    action: action,
    requiredScope: requiredScope,
    issuedAt: now,
    expiresAt: now.add(const Duration(seconds: 30)),
    idempotencyKey: 'idempotency-1',
    deliveryPath: deliveryPath,
    payload: payload,
  );
}

AiroTrustedDeviceRecord _trustedDevice(
  DateTime now, {
  Set<AiroPairingScope> scopes = const {AiroPairingScope.playbackControl},
  DateTime? revokedAt,
}) {
  return AiroTrustedDeviceRecord(
    relationshipId: 'relationship-1',
    controllerDeviceId: 'phone-device-1',
    receiverDeviceId: 'tv-device-1',
    controllerRole: AiroDeviceRole.mobileController,
    receiverRole: AiroDeviceRole.tvReceiver,
    scopes: scopes,
    createdAt: now.subtract(const Duration(minutes: 5)),
    revokedAt: revokedAt,
    trustLevel: AiroTrustedDeviceTrustLevel.trusted,
    keyDescriptor: AiroTrustedDeviceKeyDescriptor(
      keyId: 'key-1',
      algorithm: AiroTrustedDeviceKeyAlgorithm.ed25519,
      publicKeyFingerprint: 'fingerprint-1',
      createdAt: now.subtract(const Duration(days: 1)),
      notBefore: now.subtract(const Duration(days: 1)),
      expiresAt: now.add(const Duration(days: 30)),
    ),
  );
}

AiroNodeCapabilityAdvertisement _receiverAdvertisement(
  DateTime now, {
  AiroNodeLifecycleState lifecycle = AiroNodeLifecycleState.connected,
  Set<AiroNodeCapability> capabilities = const {
    AiroNodeCapability.playback,
    AiroNodeCapability.remoteControl,
    AiroNodeCapability.commandRouting,
  },
}) {
  return AiroNodeCapabilityAdvertisement(
    identity: const AiroNodeIdentity(
      nodeId: 'tv-node-1',
      role: AiroNodeRole.tvReceiver,
      productProfile: AiroNodeProductProfile.standardTv,
      platformCategory: AiroNodePlatformCategory.androidTv,
    ),
    lifecycle: lifecycle,
    capabilities: capabilities,
    issuedAt: now.subtract(const Duration(seconds: 5)),
    expiresAt: now.add(const Duration(seconds: 30)),
    trustState: AiroNodeTrustState.trusted,
  );
}

AiroRemoteControlApprovalGrant _approval(DateTime now) {
  return AiroRemoteControlApprovalGrant(
    grantId: 'approval-1',
    controllerNodeId: 'phone-node-1',
    receiverNodeId: 'tv-node-1',
    status: AiroRemoteControlApprovalStatus.approved,
    issuedAt: now.subtract(const Duration(seconds: 5)),
    expiresAt: now.add(const Duration(minutes: 5)),
  );
}

AiroUniversalPlaybackSessionSnapshot _session(
  DateTime now, {
  required Set<AiroUniversalSessionMember> members,
}) {
  return AiroUniversalPlaybackSessionSnapshot(
    sessionId: 'session-1',
    activeReceiverNodeId: 'tv-node-1',
    activeControllerNodeId: 'phone-node-1',
    revision: AiroSessionRevision(
      value: 1,
      updatedAt: now,
      reporterNodeId: 'tv-node-1',
    ),
    actual: AiroActualPlaybackState(
      phase: AiroPlaybackSessionPhase.playing,
      position: Duration.zero,
      reportedByReceiverNodeId: 'tv-node-1',
      reportedAt: now,
    ),
    members: members,
    capturedAt: now,
    expiresAt: now.add(const Duration(minutes: 5)),
  );
}

AiroUniversalSessionMember _member(
  DateTime now, {
  Set<AiroUniversalSessionPermission> permissions = const {
    AiroUniversalSessionPermission.requestDesiredState,
  },
}) {
  return AiroUniversalSessionMember(
    memberId: 'member-1',
    nodeId: 'phone-node-1',
    deviceId: 'phone-device-1',
    role: AiroUniversalSessionMemberRole.activeController,
    permissions: permissions,
    joinedAt: now.subtract(const Duration(minutes: 1)),
    expiresAt: now.add(const Duration(minutes: 5)),
  );
}
