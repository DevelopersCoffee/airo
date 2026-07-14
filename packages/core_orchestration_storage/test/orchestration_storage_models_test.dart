import 'package:core_commands/core_commands.dart';
import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_orchestration_storage/core_orchestration_storage.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_presence/core_presence.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:core_watch_progress/core_watch_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);

  group('AiroOrchestrationStorageManifest', () {
    test('exposes provider-neutral collection metadata', () {
      final manifest = _manifest();

      expect(
        manifest.supports(AiroOrchestrationStorageCollection.deviceRegistry),
        isTrue,
      );
      expect(manifest.toPublicMap(), {
        'schemaVersion': kAiroOrchestrationStorageSchemaVersion,
        'manifestId': 'fake-storage',
        'enabledCollections': [
          'device_registry',
          'presence_leases',
          'playback_sessions',
          'session_controllers',
          'command_lifecycle',
          'watch_progress',
        ],
        'providerAvailable': true,
      });
    });
  });

  group('AiroSessionControllerMembershipStore', () {
    test(
      'upserts active members and filters expired or revoked members',
      () async {
        final store = AiroFakeSessionControllerMembershipStore();
        final active = await store.upsert(
          sessionId: 'session-1',
          member: _member(now),
          now: now,
        );
        final expired = await store.upsert(
          sessionId: 'session-1',
          member: _member(
            now,
            nodeId: 'phone-node-2',
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
          now: now,
        );
        final listed = await store.list(sessionId: 'session-1', now: now);
        final revoked = await store.revoke(
          sessionId: 'session-1',
          nodeId: 'phone-node-1',
          now: now,
        );
        final afterRevoke = await store.list(sessionId: 'session-1', now: now);

        expect(active.accepted, isTrue);
        expect(expired.codes, [
          AiroSessionControllerMembershipCode.expiredMember,
        ]);
        expect(listed.map((member) => member.nodeId), ['phone-node-1']);
        expect(revoked.action, AiroSessionControllerMembershipAction.revoke);
        expect(afterRevoke, isEmpty);
      },
    );

    test('no-op membership store fails closed', () async {
      const store = AiroNoOpSessionControllerMembershipStore();

      final decision = await store.upsert(
        sessionId: 'session-1',
        member: _member(now),
        now: now,
      );

      expect(decision.action, AiroSessionControllerMembershipAction.noOp);
      expect(decision.codes, [
        AiroSessionControllerMembershipCode.storeUnavailable,
      ]);
      expect(await store.list(sessionId: 'session-1', now: now), isEmpty);
    });
  });

  group('AiroOrchestrationStorage', () {
    test(
      'no-op storage reports unavailable health and empty snapshot',
      () async {
        final storage = AiroNoOpOrchestrationStorage();

        final health = await storage.health(now: now);
        final snapshot = await storage.snapshot(now: now);

        expect(health.status, AiroOrchestrationStorageHealthStatus.unavailable);
        expect(
          health.collections.every(
            (collection) =>
                collection.status ==
                AiroOrchestrationStorageHealthStatus.unavailable,
          ),
          isTrue,
        );
        expect(snapshot.toPublicMap()['deviceCount'], 0);
        expect(snapshot.toPublicMap()['sessionControllerCount'], 0);
      },
    );

    test(
      'fake storage composes domain stores into privacy-safe snapshot',
      () async {
        final storage = await _seededStorage(now);

        final health = await storage.health(now: now);
        final snapshot = await storage.snapshot(now: now);
        final publicMap = snapshot.toPublicMap();

        expect(health.status, AiroOrchestrationStorageHealthStatus.available);
        expect(
          health.collections
              .firstWhere(
                (collection) =>
                    collection.collection ==
                    AiroOrchestrationStorageCollection.sessionControllers,
              )
              .recordCount,
          1,
        );
        expect(publicMap['deviceCount'], 1);
        expect(publicMap['presenceLeaseCount'], 1);
        expect(publicMap['sessionCount'], 1);
        expect(publicMap['sessionControllerCount'], 1);
        expect(publicMap['commandCount'], 1);
        expect(publicMap['progressCount'], 1);
        expect(publicMap['sessionIds'], ['session-1']);
        expect(publicMap['commandIds'], ['command-1']);
        expect(publicMap['progressIds'], ['progress-1']);
        expect(publicMap.toString(), isNot(contains('https://')));
      },
    );
  });
}

AiroOrchestrationStorageManifest _manifest() {
  return AiroOrchestrationStorageManifest(
    manifestId: 'fake-storage',
    enabledCollections: Set.of(AiroOrchestrationStorageCollection.values),
  );
}

Future<AiroFakeOrchestrationStorage> _seededStorage(DateTime now) async {
  final device = _device(now);
  final devices = AiroFakeDeviceIdentityRegistry(
    policy: AiroDeviceRegistrationPolicy(),
    seedDevices: [device],
  );
  final presence = AiroFakePresenceStore(
    policy: AiroPresencePolicy(),
    devices: [device],
    leases: [_lease(now)],
  );
  final sessions = AiroFakeUniversalPlaybackSessionRepository();
  await sessions.upsert(_session(now), now: now);

  final controllers = AiroFakeSessionControllerMembershipStore();
  await controllers.upsert(
    sessionId: 'session-1',
    member: _member(now),
    now: now,
  );

  final commands = AiroFakeCommandLifecycleStore(
    policy: AiroCommandLifecyclePolicy(
      grantedScopes: const {AiroPairingScope.playbackControl},
      targetNodeId: 'tv-node-1',
    ),
  );
  await commands.accept(envelope: _command(now), now: now, currentRevision: 1);

  final progress = AiroFakeWatchProgressRepository(
    policy: const AiroWatchProgressPolicy(
      syncMode: AiroWatchProgressSyncMode.cloudEnabled,
    ),
  );
  await progress.upsert(record: _progress(now), now: now);

  return AiroFakeOrchestrationStorage(
    manifest: _manifest(),
    devices: devices,
    presence: presence,
    sessions: sessions,
    controllers: controllers,
    commands: commands,
    progress: progress,
    trackedSessionIds: const {'session-1'},
  );
}

AiroRegisteredDeviceRecord _device(DateTime now) {
  return AiroRegisteredDeviceRecord(
    registrationId: AiroDeviceStableValue.stable('registration-1'),
    accountId: AiroDeviceStableValue.stable('account-1'),
    deviceId: AiroDeviceStableValue.stable('tv-device-1'),
    nodeIdentity: const AiroNodeIdentity(
      nodeId: 'tv-node-1',
      role: AiroNodeRole.tvReceiver,
      productProfile: AiroNodeProductProfile.standardTv,
      platformCategory: AiroNodePlatformCategory.androidTv,
    ),
    scopes: const {AiroPairingScope.playbackControl},
    registeredAt: now.subtract(const Duration(days: 1)),
    lastSeenAt: now,
  );
}

AiroPresenceLease _lease(DateTime now) {
  return AiroPresenceLease(
    leaseId: AiroDeviceStableValue.stable('lease-1'),
    accountId: AiroDeviceStableValue.stable('account-1'),
    deviceId: AiroDeviceStableValue.stable('tv-device-1'),
    registrationId: AiroDeviceStableValue.stable('registration-1'),
    status: AiroPresenceStatus.available,
    lifecycle: AiroNodeLifecycleState.connected,
    visibility: AiroPresenceVisibility.account,
    visibleCapabilities: const {
      AiroNodeCapability.playback,
      AiroNodeCapability.remoteControl,
    },
    sequence: 1,
    issuedAt: now.subtract(const Duration(seconds: 5)),
    lastHeartbeatAt: now,
    expiresAt: now.add(const Duration(minutes: 1)),
    heartbeatInterval: const Duration(seconds: 30),
  );
}

AiroUniversalPlaybackSessionSnapshot _session(DateTime now) {
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
      position: const Duration(minutes: 12),
      reportedByReceiverNodeId: 'tv-node-1',
      reportedAt: now,
    ),
    members: {
      _member(now),
      AiroUniversalSessionMember(
        memberId: 'receiver-member-1',
        nodeId: 'tv-node-1',
        deviceId: 'tv-device-1',
        role: AiroUniversalSessionMemberRole.receiver,
        permissions: const {AiroUniversalSessionPermission.reportActualState},
        joinedAt: now.subtract(const Duration(minutes: 1)),
      ),
    },
    capturedAt: now,
    expiresAt: now.add(const Duration(minutes: 5)),
  );
}

AiroUniversalSessionMember _member(
  DateTime now, {
  String nodeId = 'phone-node-1',
  DateTime? expiresAt,
}) {
  return AiroUniversalSessionMember(
    memberId: 'member-$nodeId',
    nodeId: nodeId,
    deviceId: 'phone-device-1',
    role: AiroUniversalSessionMemberRole.activeController,
    permissions: const {AiroUniversalSessionPermission.requestDesiredState},
    joinedAt: now.subtract(const Duration(minutes: 1)),
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
  );
}

AiroCommandEnvelope _command(DateTime now) {
  return AiroCommandEnvelope(
    commandId: 'command-1',
    sessionId: 'session-1',
    senderNodeId: 'phone-node-1',
    targetNodeId: 'tv-node-1',
    kind: AiroCommandKind.playback,
    action: AiroCommandAction.pause,
    requiredScope: AiroPairingScope.playbackControl,
    issuedAt: now,
    expiresAt: now.add(const Duration(seconds: 30)),
    idempotencyKey: 'idempotency-1',
    expectedRevision: 1,
    deliveryPath: AiroCommandDeliveryPath.cloud,
  );
}

AiroWatchProgressRecord _progress(DateTime now) {
  return AiroWatchProgressRecord(
    progressId: 'progress-1',
    key: const AiroWatchProgressKey(
      profileId: 'profile-1',
      mediaId: 'media-1',
      sourceId: 'source-1',
      resolverId: 'resolver-1',
    ),
    position: const Duration(minutes: 12),
    duration: const Duration(minutes: 60),
    status: AiroWatchProgressStatus.inProgress,
    revision: AiroSessionRevision(
      value: 1,
      updatedAt: now,
      reporterNodeId: 'tv-node-1',
    ),
    updatedByNodeId: 'tv-node-1',
    updatedByDeviceId: 'tv-device-1',
    updatedAt: now,
    retentionExpiresAt: now.add(const Duration(days: 90)),
    cloudEligible: true,
  );
}
