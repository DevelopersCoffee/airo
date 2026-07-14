import 'package:core_commands/core_commands.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo session sync contracts', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroSessionRevision revision(
      int value, {
      String reporterNodeId = 'receiver-tv-1',
      DateTime? updatedAt,
    }) {
      return AiroSessionRevision(
        value: value,
        updatedAt: updatedAt ?? now,
        reporterNodeId: reporterNodeId,
      );
    }

    AiroPlaybackSessionSnapshot snapshot({
      int revisionValue = 1,
      String reporterNodeId = 'receiver-tv-1',
      DateTime? updatedAt,
      DateTime? capturedAt,
      DateTime? expiresAt,
      AiroPlaybackSessionPhase phase = AiroPlaybackSessionPhase.playing,
    }) {
      return AiroPlaybackSessionSnapshot(
        sessionId: 'session-1',
        receiverNodeId: 'receiver-tv-1',
        activeControllerNodeId: 'phone-1',
        revision: revision(
          revisionValue,
          reporterNodeId: reporterNodeId,
          updatedAt: updatedAt,
        ),
        actual: AiroActualPlaybackState(
          phase: phase,
          position: const Duration(seconds: 30),
          reportedByReceiverNodeId: reporterNodeId,
          reportedAt: updatedAt ?? now,
        ),
        desired: AiroDesiredPlaybackState(
          phase: AiroPlaybackSessionPhase.playing,
          position: const Duration(seconds: 31),
          updatedByControllerNodeId: 'phone-1',
          updatedAt: now,
          commandReference: AiroSessionCommandReference.fromEnvelope(
            commandEnvelope(now),
          ),
        ),
        mediaHandle: AiroSessionPayloadHandle.redacted('media-ref-1'),
        capturedAt: capturedAt ?? now,
        expiresAt: expiresAt,
      );
    }

    test('newer receiver revision wins over stale controller state', () {
      const policy = AiroSessionConflictPolicy();
      final current = snapshot(revisionValue: 2);
      final stale = snapshot(
        revisionValue: 1,
        reporterNodeId: 'phone-1',
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      final result = policy.merge(current: current, incoming: stale);

      expect(result.code, AiroSessionMergeCode.ignoredStale);
      expect(result.snapshot, current);
    });

    test('equal revision from different reporters is conflict', () {
      const policy = AiroSessionConflictPolicy();
      final receiver = snapshot(reporterNodeId: 'receiver-tv-1');
      final controller = snapshot(reporterNodeId: 'phone-1');

      final result = policy.merge(current: receiver, incoming: controller);

      expect(result.code, AiroSessionMergeCode.conflict);
      expect(receiver.revision.conflictsWith(controller.revision), isTrue);
    });

    test('sync policy rejects expired and stale deltas', () {
      const policy = AiroSessionSyncPolicy();
      final delta = AiroSessionSyncDelta(
        deltaId: 'delta-1',
        sessionId: 'session-1',
        entityKind: AiroSessionSyncEntityKind.playbackSession,
        operation: AiroSessionSyncOperation.upsert,
        revision: revision(1),
        payloadHandle: AiroSessionPayloadHandle.redacted('snapshot-ref-1'),
        issuedAt: now,
        expiresAt: now,
      );

      final result = policy.validate(
        delta: delta,
        now: now.add(const Duration(seconds: 1)),
        currentRevision: revision(2),
      );

      expect(result.has(AiroSessionSyncValidationCode.expired), isTrue);
      expect(result.has(AiroSessionSyncValidationCode.staleRevision), isTrue);
    });

    test('payload handles reject unsafe sync data references', () {
      expect(
        AiroSessionPayloadHandle.validate(''),
        AiroSessionPayloadRejectionCode.empty,
      );
      expect(
        AiroSessionPayloadHandle.validate('https://example.com/snapshot'),
        AiroSessionPayloadRejectionCode.urlValue,
      );
      expect(
        AiroSessionPayloadHandle.validate('/Users/example/session.json'),
        AiroSessionPayloadRejectionCode.localPathValue,
      );
      expect(
        AiroSessionPayloadHandle.validate('seen at 192.168.1.10'),
        AiroSessionPayloadRejectionCode.localIpValue,
      );
      expect(
        AiroSessionPayloadHandle.validate('Bearer abc.def'),
        AiroSessionPayloadRejectionCode.credentialLikeValue,
      );
    });

    test('snapshot and delta string output redact handles', () {
      final session = snapshot();
      final delta = AiroSessionSyncDelta(
        deltaId: 'delta-1',
        sessionId: 'session-1',
        entityKind: AiroSessionSyncEntityKind.playbackSession,
        operation: AiroSessionSyncOperation.upsert,
        revision: revision(2),
        payloadHandle: AiroSessionPayloadHandle.redacted('private-ref-1'),
        issuedAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
      );

      expect(session.toString(), isNot(contains('media-ref-1')));
      expect(delta.toString(), isNot(contains('private-ref-1')));
      expect(session.toString(), contains('mediaHandle: redacted'));
      expect(delta.toString(), contains('payloadHandle: redacted'));
    });

    test('handoff preflight accepts trusted compatible snapshots', () {
      final policy = AiroHandoffPreflightPolicy(
        requiredDestinationCapabilities: const {AiroNodeCapability.playback},
      );

      final result = policy.evaluate(
        request: handoffRequest(now),
        now: now,
        sourceSnapshot: snapshot(),
        destinationSnapshot: snapshot(phase: AiroPlaybackSessionPhase.paused),
        trustRecord: trustRecord(now),
        destinationAdvertisement: advertisement(now),
      );

      expect(result.accepted, isTrue);
    });

    test(
      'handoff preflight rejects stale, inactive, and incompatible state',
      () {
        final policy = AiroHandoffPreflightPolicy(
          requiredDestinationCapabilities: const {AiroNodeCapability.playback},
        );

        final result = policy.evaluate(
          request: handoffRequest(now),
          now: now,
          sourceSnapshot: snapshot(
            capturedAt: now.subtract(const Duration(seconds: 20)),
            phase: AiroPlaybackSessionPhase.stopped,
          ),
          destinationSnapshot: snapshot(
            capturedAt: now.subtract(const Duration(seconds: 20)),
          ),
          trustRecord: trustRecord(
            now,
            scopes: const {AiroPairingScope.textInput},
          ),
          destinationAdvertisement: advertisement(
            now,
            capabilities: const {AiroNodeCapability.display},
          ),
        );

        expect(result.has(AiroHandoffPreflightCode.sourceStale), isTrue);
        expect(result.has(AiroHandoffPreflightCode.destinationStale), isTrue);
        expect(result.has(AiroHandoffPreflightCode.sourceNotActive), isTrue);
        expect(result.has(AiroHandoffPreflightCode.capabilityMissing), isTrue);
        expect(result.has(AiroHandoffPreflightCode.trustInsufficient), isTrue);
      },
    );

    test(
      'fake repository emits accepted snapshots and ignores stale updates',
      () async {
        final repository = AiroFakePlaybackSessionRepository();
        final events = <AiroPlaybackSessionSnapshot>[];
        final subscription = repository.snapshots.listen(events.add);

        final first = await repository.upsert(snapshot(revisionValue: 1));
        final second = await repository.upsert(snapshot(revisionValue: 2));
        final stale = await repository.upsert(snapshot(revisionValue: 1));

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();
        await repository.dispose();

        expect(first.code, AiroSessionMergeCode.acceptedRemote);
        expect(second.code, AiroSessionMergeCode.acceptedRemote);
        expect(stale.code, AiroSessionMergeCode.ignoredStale);
        expect(events.map((event) => event.revision.value), [1, 2]);
      },
    );

    test('no-op repository never stores sessions', () async {
      const repository = AiroNoOpPlaybackSessionRepository();

      await repository.upsert(snapshot());

      expect(await repository.getById('session-1'), isNull);
    });
  });
}

AiroCommandEnvelope commandEnvelope(DateTime now) {
  return AiroCommandEnvelope(
    commandId: 'command-1',
    sessionId: 'session-1',
    senderNodeId: 'phone-1',
    targetNodeId: 'receiver-tv-1',
    kind: AiroCommandKind.playback,
    action: AiroCommandAction.play,
    requiredScope: AiroPairingScope.playbackControl,
    issuedAt: now,
    expiresAt: now.add(const Duration(seconds: 30)),
    idempotencyKey: 'idempotency-1',
  );
}

AiroHandoffRequest handoffRequest(DateTime now) {
  return AiroHandoffRequest(
    handoffId: 'handoff-1',
    sessionId: 'session-1',
    sourceReceiverNodeId: 'receiver-tv-1',
    destinationReceiverNodeId: 'receiver-tv-2',
    controllerNodeId: 'phone-1',
    requiredScope: AiroPairingScope.playbackControl,
    issuedAt: now,
    expiresAt: now.add(const Duration(seconds: 30)),
  );
}

AiroTrustedDeviceRecord trustRecord(
  DateTime now, {
  Set<AiroPairingScope> scopes = const {AiroPairingScope.playbackControl},
}) {
  return AiroTrustedDeviceRecord(
    relationshipId: 'trusted-device-1',
    controllerDeviceId: 'phone-1',
    receiverDeviceId: 'receiver-tv-2',
    controllerRole: AiroDeviceRole.mobileController,
    receiverRole: AiroDeviceRole.tvReceiver,
    scopes: scopes,
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 5)),
    trustLevel: AiroTrustedDeviceTrustLevel.trusted,
  );
}

AiroNodeCapabilityAdvertisement advertisement(
  DateTime now, {
  Set<AiroNodeCapability> capabilities = const {AiroNodeCapability.playback},
}) {
  return AiroNodeCapabilityAdvertisement(
    identity: const AiroNodeIdentity(
      nodeId: 'receiver-tv-2',
      role: AiroNodeRole.tvReceiver,
      productProfile: AiroNodeProductProfile.liteReceiver,
      platformCategory: AiroNodePlatformCategory.androidTv,
    ),
    lifecycle: AiroNodeLifecycleState.available,
    trustState: AiroNodeTrustState.trusted,
    capabilities: capabilities,
    issuedAt: now,
    expiresAt: now.add(const Duration(seconds: 30)),
  );
}
