import 'package:core_media_routing/core_media_routing.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroPlaybackOwnershipSnapshot', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroPlaybackOwnershipSnapshot snapshot({
      DateTime? leaseExpiresAt,
      Set<AiroPlaybackOwnershipOperation> controllerGrant = const {
        AiroPlaybackOwnershipOperation.pause,
      },
    }) {
      return AiroPlaybackOwnershipSnapshot(
        sessionId: 'session-1',
        ownerNodeId: 'tv-1',
        playbackNodeId: 'tv-1',
        sourceNodeId: 'source-1',
        routeId: 'route-1',
        routeKind: AiroMediaRouteKind.receiverDirect,
        analyticsOwnerNodeId: 'analytics-1',
        healthReporterNodeId: 'tv-1',
        activeControllerNodeId: 'phone-1',
        controllerGrant: controllerGrant,
        revision: AiroSessionRevision(
          value: 4,
          updatedAt: now,
          reporterNodeId: 'tv-1',
        ),
        capturedAt: now,
        leaseExpiresAt: leaseExpiresAt ?? now.add(const Duration(minutes: 5)),
      );
    }

    test('playback owner controls playback operations', () {
      final ownership = snapshot();

      expect(
        ownership.canPerform(
          nodeId: 'tv-1',
          operation: AiroPlaybackOwnershipOperation.pause,
          now: now,
        ),
        isTrue,
      );
      expect(
        ownership.canPerform(
          nodeId: 'tv-1',
          operation: AiroPlaybackOwnershipOperation.seek,
          now: now,
        ),
        isTrue,
      );
    });

    test('active controller only receives granted operations', () {
      final ownership = snapshot();

      expect(
        ownership.canPerform(
          nodeId: 'phone-1',
          operation: AiroPlaybackOwnershipOperation.pause,
          now: now,
        ),
        isTrue,
      );
      expect(
        ownership.canPerform(
          nodeId: 'phone-1',
          operation: AiroPlaybackOwnershipOperation.seek,
          now: now,
        ),
        isFalse,
      );
    });

    test('analytics and health reporters are derived from ownership', () {
      final ownership = snapshot();

      expect(
        ownership.canPerform(
          nodeId: 'analytics-1',
          operation: AiroPlaybackOwnershipOperation.analyticsReport,
          now: now,
        ),
        isTrue,
      );
      expect(
        ownership.canPerform(
          nodeId: 'phone-1',
          operation: AiroPlaybackOwnershipOperation.analyticsReport,
          now: now,
        ),
        isFalse,
      );
      expect(
        ownership.canPerform(
          nodeId: 'tv-1',
          operation: AiroPlaybackOwnershipOperation.healthReport,
          now: now,
        ),
        isTrue,
      );
    });

    test('expired ownership lease rejects operation authority', () {
      final ownership = snapshot(leaseExpiresAt: now);

      expect(
        ownership.canPerform(
          nodeId: 'tv-1',
          operation: AiroPlaybackOwnershipOperation.pause,
          now: now,
        ),
        isFalse,
      );
    });

    test('diagnostics avoid media source values and payloads', () {
      final ownership = snapshot();

      expect(ownership.toString(), contains('routeId: route-1'));
      expect(ownership.toString(), contains('routeKind: receiver_direct'));
      expect(ownership.toString(), isNot(contains('http')));
      expect(ownership.toString(), isNot(contains('payload')));
    });
  });

  group('AiroPlaybackOwnershipPolicy', () {
    const policy = AiroPlaybackOwnershipPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroPlaybackOwnershipSnapshot current({
      DateTime? leaseExpiresAt,
      int revision = 4,
    }) {
      return AiroPlaybackOwnershipSnapshot(
        sessionId: 'session-1',
        ownerNodeId: 'tv-1',
        playbackNodeId: 'tv-1',
        sourceNodeId: 'phone-1',
        routeId: 'route-1',
        routeKind: AiroMediaRouteKind.receiverDirect,
        analyticsOwnerNodeId: 'tv-1',
        healthReporterNodeId: 'tv-1',
        activeControllerNodeId: 'phone-1',
        controllerGrant: const {AiroPlaybackOwnershipOperation.pause},
        revision: AiroSessionRevision(
          value: revision,
          updatedAt: now,
          reporterNodeId: 'tv-1',
        ),
        capturedAt: now,
        leaseExpiresAt: leaseExpiresAt ?? now.add(const Duration(minutes: 5)),
      );
    }

    AiroPlaybackOwnershipTransferRequest request({
      String currentOwnerNodeId = 'tv-1',
      String requestedByNodeId = 'tv-1',
      int baseRevision = 4,
      DateTime? expiresAt,
    }) {
      return AiroPlaybackOwnershipTransferRequest(
        transferId: 'transfer-1',
        sessionId: 'session-1',
        currentOwnerNodeId: currentOwnerNodeId,
        newOwnerNodeId: 'desktop-1',
        requestedByNodeId: requestedByNodeId,
        baseRevision: baseRevision,
        issuedAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 1)),
        activeControllerNodeId: 'phone-1',
        controllerGrant: const {
          AiroPlaybackOwnershipOperation.pause,
          AiroPlaybackOwnershipOperation.seek,
        },
      );
    }

    test('valid transfer changes owner and increments revision', () {
      final result = policy.transfer(
        current: current(),
        request: request(),
        now: now,
      );

      expect(result.accepted, isTrue);
      expect(result.snapshot.ownerNodeId, 'desktop-1');
      expect(result.snapshot.analyticsOwnerNodeId, 'desktop-1');
      expect(result.snapshot.healthReporterNodeId, 'desktop-1');
      expect(result.snapshot.revision.value, 5);
      expect(result.snapshot.revision.reporterNodeId, 'tv-1');
      expect(
        result.snapshot.controllerGrant,
        contains(AiroPlaybackOwnershipOperation.seek),
      );
    });

    test('stale transfer revision is rejected', () {
      final result = policy.transfer(
        current: current(),
        request: request(baseRevision: 3),
        now: now,
      );

      expect(result.accepted, isFalse);
      expect(result.code, AiroPlaybackOwnershipTransferCode.staleRevision);
      expect(result.snapshot.ownerNodeId, 'tv-1');
    });

    test('wrong current owner is rejected', () {
      final result = policy.transfer(
        current: current(),
        request: request(currentOwnerNodeId: 'phone-1'),
        now: now,
      );

      expect(result.accepted, isFalse);
      expect(
        result.code,
        AiroPlaybackOwnershipTransferCode.currentOwnerMismatch,
      );
    });

    test('expired transfer and expired lease are rejected', () {
      final expiredRequest = policy.transfer(
        current: current(),
        request: request(expiresAt: now),
        now: now,
      );
      final expiredLease = policy.transfer(
        current: current(leaseExpiresAt: now),
        request: request(),
        now: now,
      );

      expect(
        expiredRequest.code,
        AiroPlaybackOwnershipTransferCode.requestExpired,
      );
      expect(
        expiredLease.code,
        AiroPlaybackOwnershipTransferCode.ownershipExpired,
      );
    });

    test('unauthorized requester cannot transfer ownership', () {
      final result = policy.transfer(
        current: current(),
        request: request(requestedByNodeId: 'unknown-1'),
        now: now,
      );

      expect(
        result.code,
        AiroPlaybackOwnershipTransferCode.requesterUnauthorized,
      );
    });
  });
}
