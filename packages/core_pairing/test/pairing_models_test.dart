import 'package:core_pairing/core_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo pairing contracts', () {
    final issuedAt = DateTime.utc(2026, 7, 14, 10);
    final expiresAt = issuedAt.add(const Duration(minutes: 5));

    test('pairing challenge exposes stable schema and expiry', () {
      final challenge = AiroPairingChallenge(
        challengeId: 'pairing-challenge-1',
        receiverDeviceId: 'receiver-tv-1',
        receiverRole: AiroDeviceRole.tvReceiver,
        requestedScopes: const {
          AiroPairingScope.playbackControl,
          AiroPairingScope.companionSearch,
        },
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      );

      expect(challenge.schemaVersion, kAiroPairingSchemaVersion);
      expect(challenge.statusAt(issuedAt), AiroPairingChallengeStatus.pending);
      expect(challenge.canApproveAt(expiresAt), isFalse);
      expect(challenge.statusAt(expiresAt), AiroPairingChallengeStatus.expired);
    });

    test('trusted device allows only scoped, unexpired access', () {
      final relationship = AiroTrustedDeviceRecord(
        relationshipId: 'trusted-device-1',
        controllerDeviceId: 'phone-1',
        receiverDeviceId: 'receiver-tv-1',
        controllerRole: AiroDeviceRole.mobileController,
        receiverRole: AiroDeviceRole.tvReceiver,
        scopes: const {AiroPairingScope.playbackControl},
        createdAt: issuedAt,
        expiresAt: expiresAt,
      );

      expect(
        relationship.allows(
          requiredScope: AiroPairingScope.playbackControl,
          now: issuedAt.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        relationship
            .evaluateAccess(
              requiredScope: AiroPairingScope.companionSearch,
              now: issuedAt.add(const Duration(seconds: 1)),
            )
            .code,
        AiroTrustedDeviceAccessCode.scopeMissing,
      );
      expect(
        relationship
            .evaluateAccess(
              requiredScope: AiroPairingScope.playbackControl,
              now: expiresAt,
            )
            .code,
        AiroTrustedDeviceAccessCode.expired,
      );
    });

    test('trusted device revocation blocks future commands', () {
      final relationship = AiroTrustedDeviceRecord(
        relationshipId: 'trusted-device-1',
        controllerDeviceId: 'phone-1',
        receiverDeviceId: 'receiver-tv-1',
        controllerRole: AiroDeviceRole.mobileController,
        receiverRole: AiroDeviceRole.tvReceiver,
        scopes: const {AiroPairingScope.playbackControl},
        createdAt: issuedAt,
        revokedAt: issuedAt.add(const Duration(minutes: 1)),
      );

      expect(
        relationship
            .evaluateAccess(
              requiredScope: AiroPairingScope.playbackControl,
              now: issuedAt.add(const Duration(minutes: 1)),
            )
            .code,
        AiroTrustedDeviceAccessCode.revoked,
      );
    });
  });

  group('Airo playback-ticket contracts', () {
    final issuedAt = DateTime.utc(2026, 7, 14, 10);
    final notBefore = issuedAt.add(const Duration(seconds: 5));
    final expiresAt = issuedAt.add(const Duration(minutes: 2));

    AiroPlaybackTicket ticket({
      String receiverDeviceId = 'receiver-tv-1',
      String sessionId = 'session-1',
      Set<AiroPairingScope> scopes = const {
        AiroPairingScope.playbackControl,
        AiroPairingScope.sourceSelection,
      },
      DateTime? revokedAt,
      DateTime? usedAt,
    }) {
      return AiroPlaybackTicket(
        ticketId: 'playback-ticket-1',
        receiverDeviceId: receiverDeviceId,
        sessionId: sessionId,
        sourceHandle: AiroPlaybackSourceHandle.redacted('source-ref-1'),
        scopes: scopes,
        issuedAt: issuedAt,
        notBefore: notBefore,
        expiresAt: expiresAt,
        revokedAt: revokedAt,
        usedAt: usedAt,
      );
    }

    test('validates receiver, session, scope, and validity window', () {
      final result = ticket().validate(
        receiverDeviceId: 'receiver-tv-1',
        sessionId: 'session-1',
        requiredScope: AiroPairingScope.playbackControl,
        now: notBefore,
      );

      expect(result.code, AiroPlaybackTicketValidationCode.accepted);
      expect(result.accepted, isTrue);
    });

    test('rejects mismatched receiver and session deterministically', () {
      expect(
        ticket()
            .validate(
              receiverDeviceId: 'other-tv',
              sessionId: 'session-1',
              requiredScope: AiroPairingScope.playbackControl,
              now: notBefore,
            )
            .code,
        AiroPlaybackTicketValidationCode.receiverMismatch,
      );
      expect(
        ticket()
            .validate(
              receiverDeviceId: 'receiver-tv-1',
              sessionId: 'other-session',
              requiredScope: AiroPairingScope.playbackControl,
              now: notBefore,
            )
            .code,
        AiroPlaybackTicketValidationCode.sessionMismatch,
      );
    });

    test('rejects missing scope, early use, expiry, revocation, and reuse', () {
      expect(
        ticket(scopes: const {AiroPairingScope.sourceSelection})
            .validate(
              receiverDeviceId: 'receiver-tv-1',
              sessionId: 'session-1',
              requiredScope: AiroPairingScope.playbackControl,
              now: notBefore,
            )
            .code,
        AiroPlaybackTicketValidationCode.scopeMissing,
      );
      expect(
        ticket()
            .validate(
              receiverDeviceId: 'receiver-tv-1',
              sessionId: 'session-1',
              requiredScope: AiroPairingScope.playbackControl,
              now: issuedAt,
            )
            .code,
        AiroPlaybackTicketValidationCode.notYetValid,
      );
      expect(
        ticket()
            .validate(
              receiverDeviceId: 'receiver-tv-1',
              sessionId: 'session-1',
              requiredScope: AiroPairingScope.playbackControl,
              now: expiresAt,
            )
            .code,
        AiroPlaybackTicketValidationCode.expired,
      );
      expect(
        ticket(revokedAt: notBefore)
            .validate(
              receiverDeviceId: 'receiver-tv-1',
              sessionId: 'session-1',
              requiredScope: AiroPairingScope.playbackControl,
              now: notBefore,
            )
            .code,
        AiroPlaybackTicketValidationCode.revoked,
      );
      expect(
        ticket(usedAt: notBefore)
            .validate(
              receiverDeviceId: 'receiver-tv-1',
              sessionId: 'session-1',
              requiredScope: AiroPairingScope.playbackControl,
              now: notBefore,
            )
            .code,
        AiroPlaybackTicketValidationCode.alreadyUsed,
      );
    });

    test('redacted source handles reject unsafe media references', () {
      expect(
        AiroPlaybackSourceHandle.validate(''),
        AiroPlaybackSourceHandleRejectionCode.empty,
      );
      expect(
        AiroPlaybackSourceHandle.validate('https://example.com/live.m3u8'),
        AiroPlaybackSourceHandleRejectionCode.urlValue,
      );
      expect(
        AiroPlaybackSourceHandle.validate('/Users/example/live.m3u8'),
        AiroPlaybackSourceHandleRejectionCode.localPathValue,
      );
      expect(
        AiroPlaybackSourceHandle.validate('source at 192.168.1.10'),
        AiroPlaybackSourceHandleRejectionCode.localIpValue,
      );
      expect(
        AiroPlaybackSourceHandle.validate('Bearer abc.def'),
        AiroPlaybackSourceHandleRejectionCode.credentialLikeValue,
      );
    });

    test('ticket string output does not expose the source handle value', () {
      final playbackTicket = ticket();

      expect(playbackTicket.sourceHandle.value, 'source-ref-1');
      expect(playbackTicket.toString(), isNot(contains('source-ref-1')));
      expect(
        playbackTicket.sourceHandle.toString(),
        'AiroPlaybackSourceHandle(redacted)',
      );
    });
  });
}
