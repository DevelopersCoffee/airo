import 'package:core_media_routing/core_media_routing.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 11);
  const policy = AiroUniversalPlaybackSessionPolicy();

  group('AiroUniversalPlaybackSessionPolicy', () {
    test(
      'accepts receiver-authoritative actual state and clears stale desired',
      () {
        final incoming = _snapshot(
          now,
          revisionValue: 2,
          actualReportedAt: now.add(const Duration(seconds: 5)),
          desiredUpdatedAt: now,
        );

        final decision = policy.evaluateIncoming(
          incoming: incoming,
          current: _snapshot(now),
          now: now.add(const Duration(seconds: 6)),
        );

        expect(decision.accepted, isTrue);
        expect(decision.snapshot.revision.value, 2);
        expect(decision.snapshot.desired, isNull);
        expect(decision.toDiagnosticMap(), {
          'sessionId': 'session-1',
          'action': 'accept',
          'codes': ['accepted'],
          'revision': 2,
          'reporterNodeId': 'receiver-tv-1',
        });
      },
    );

    test('preserves optimistic desired state until receiver catches up', () {
      final incoming = _snapshot(
        now,
        revisionValue: 2,
        actualReportedAt: now,
        desiredUpdatedAt: now.add(const Duration(seconds: 5)),
      );

      final decision = policy.evaluateIncoming(
        incoming: incoming,
        current: _snapshot(now),
        now: now.add(const Duration(seconds: 1)),
      );

      expect(decision.accepted, isTrue);
      expect(decision.snapshot.desired, isNotNull);
      expect(decision.snapshot.desired?.updatedByControllerNodeId, 'phone-1');
    });

    test('rejects stale and conflicting revisions', () {
      final current = _snapshot(now, revisionValue: 2);
      final stale = policy.evaluateIncoming(
        incoming: _snapshot(now, revisionValue: 1),
        current: current,
        now: now,
      );
      final conflict = policy.evaluateIncoming(
        incoming: _snapshot(
          now,
          revisionValue: 2,
          reporterNodeId: 'receiver-tv-2',
          actualReporterNodeId: 'receiver-tv-2',
          activeReceiverNodeId: 'receiver-tv-2',
          members: {
            _member(
              nodeId: 'receiver-tv-2',
              role: AiroUniversalSessionMemberRole.receiver,
              permissions: const {
                AiroUniversalSessionPermission.reportActualState,
              },
              now: now,
            ),
          },
        ),
        current: current,
        now: now,
      );

      expect(stale.action, AiroUniversalSessionDecisionAction.deny);
      expect(stale.codes, [AiroUniversalSessionCode.staleRevision]);
      expect(conflict.action, AiroUniversalSessionDecisionAction.deny);
      expect(conflict.codes, [AiroUniversalSessionCode.revisionConflict]);
    });

    test('rejects invalid authority, membership, and expiry', () {
      final expired = policy.evaluateIncoming(
        incoming: _snapshot(
          now,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        now: now,
      );
      final receiverMismatch = policy.evaluateIncoming(
        incoming: _snapshot(
          now,
          reporterNodeId: 'phone-1',
          actualReporterNodeId: 'phone-1',
        ),
        now: now,
      );
      final missingPermission = policy.evaluateIncoming(
        incoming: _snapshot(
          now,
          members: {
            _member(
              nodeId: 'receiver-tv-1',
              role: AiroUniversalSessionMemberRole.receiver,
              permissions: const {},
              now: now,
            ),
          },
        ),
        now: now,
      );

      expect(expired.codes, [AiroUniversalSessionCode.expiredSnapshot]);
      expect(
        receiverMismatch.codes,
        contains(AiroUniversalSessionCode.receiverMismatch),
      );
      expect(
        receiverMismatch.codes,
        contains(AiroUniversalSessionCode.permissionMissing),
      );
      expect(missingPermission.codes, [
        AiroUniversalSessionCode.permissionMissing,
      ]);
      expect(
        AiroSessionPayloadHandle.validate('https://example.test/movie.m3u8'),
        AiroSessionPayloadRejectionCode.urlValue,
      );
    });

    test('public diagnostics redact media handle details', () {
      final snapshot = _snapshot(now);
      final rendered = snapshot.toPublicMap().toString();

      expect(rendered, contains('session-1'));
      expect(rendered, contains('hasMediaHandle: true'));
      expect(rendered, isNot(contains('media-ref-1')));
      expect(snapshot.toString(), isNot(contains('media-ref-1')));
      expect(snapshot.toString(), contains('mediaHandle: redacted'));
    });
  });

  group('AiroUniversalPlaybackSessionRepository implementations', () {
    test(
      'fake repository recovers latest receiver-authoritative snapshot',
      () async {
        final repository = AiroFakeUniversalPlaybackSessionRepository();
        final first = await repository.upsert(_snapshot(now), now: now);
        final second = await repository.upsert(
          _snapshot(now, revisionValue: 2, actualReportedAt: now),
          now: now,
        );

        final recovered = await repository.recoverLatest(
          sessionId: 'session-1',
          now: now.add(const Duration(seconds: 1)),
        );

        expect(first.accepted, isTrue);
        expect(second.accepted, isTrue);
        expect(recovered?.revision.value, 2);
        expect(recovered?.isReceiverAuthoritative, isTrue);
      },
    );

    test('fake repository refuses expired recovery snapshots', () async {
      final repository = AiroFakeUniversalPlaybackSessionRepository();
      await repository.upsert(
        _snapshot(now, expiresAt: now.add(const Duration(seconds: 1))),
        now: now,
      );

      final recovered = await repository.recoverLatest(
        sessionId: 'session-1',
        now: now.add(const Duration(seconds: 1)),
      );

      expect(recovered, isNull);
    });

    test('no-op repository never stores sessions', () async {
      const repository = AiroNoOpUniversalPlaybackSessionRepository();

      final decision = await repository.upsert(_snapshot(now), now: now);

      expect(decision.action, AiroUniversalSessionDecisionAction.noOp);
      expect(decision.codes, [AiroUniversalSessionCode.repositoryUnavailable]);
      expect(
        await repository.recoverLatest(sessionId: 'session-1', now: now),
        isNull,
      );
    });
  });
}

AiroUniversalPlaybackSessionSnapshot _snapshot(
  DateTime now, {
  int revisionValue = 1,
  String reporterNodeId = 'receiver-tv-1',
  String actualReporterNodeId = 'receiver-tv-1',
  String activeReceiverNodeId = 'receiver-tv-1',
  DateTime? actualReportedAt,
  DateTime? desiredUpdatedAt,
  DateTime? expiresAt,
  AiroSessionPayloadHandle? mediaHandle,
  Set<AiroUniversalSessionMember>? members,
}) {
  return AiroUniversalPlaybackSessionSnapshot(
    sessionId: 'session-1',
    activeReceiverNodeId: activeReceiverNodeId,
    activeControllerNodeId: 'phone-1',
    revision: AiroSessionRevision(
      value: revisionValue,
      updatedAt: now,
      reporterNodeId: reporterNodeId,
    ),
    actual: AiroActualPlaybackState(
      phase: AiroPlaybackSessionPhase.playing,
      position: const Duration(seconds: 42),
      duration: const Duration(minutes: 42),
      liveOffset: const Duration(seconds: 3),
      playbackSpeed: 1,
      volume: 0.7,
      reportedByReceiverNodeId: actualReporterNodeId,
      reportedAt: actualReportedAt ?? now,
    ),
    desired: AiroDesiredPlaybackState(
      phase: AiroPlaybackSessionPhase.playing,
      position: const Duration(seconds: 45),
      updatedByControllerNodeId: 'phone-1',
      updatedAt: desiredUpdatedAt ?? now.add(const Duration(seconds: 1)),
      playbackSpeed: 1,
      volume: 0.7,
    ),
    mediaHandle:
        mediaHandle ?? AiroSessionPayloadHandle.redacted('media-ref-1'),
    routeId: 'route-1',
    routeKind: AiroMediaRouteKind.cloudCommandOnly,
    members:
        members ??
        {
          _member(
            nodeId: 'receiver-tv-1',
            role: AiroUniversalSessionMemberRole.receiver,
            permissions: const {
              AiroUniversalSessionPermission.reportActualState,
              AiroUniversalSessionPermission.recoverSnapshot,
            },
            now: now,
          ),
          _member(
            nodeId: 'phone-1',
            role: AiroUniversalSessionMemberRole.activeController,
            permissions: const {
              AiroUniversalSessionPermission.requestDesiredState,
            },
            now: now,
          ),
        },
    capturedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
  );
}

AiroUniversalSessionMember _member({
  required String nodeId,
  required AiroUniversalSessionMemberRole role,
  required Set<AiroUniversalSessionPermission> permissions,
  required DateTime now,
}) {
  return AiroUniversalSessionMember(
    memberId: 'member-$nodeId',
    nodeId: nodeId,
    deviceId: 'device-$nodeId',
    role: role,
    permissions: permissions,
    joinedAt: now,
    expiresAt: now.add(const Duration(minutes: 10)),
  );
}
