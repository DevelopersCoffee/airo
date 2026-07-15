import 'package:core_pairing/core_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo pairing contracts', () {
    final issuedAt = DateTime.utc(2026, 7, 14, 10);
    final expiresAt = issuedAt.add(const Duration(minutes: 5));
    final trustedUntil = issuedAt.add(const Duration(days: 90));

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

    test('trusted device security policy accepts active trusted key', () {
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
      );
      final policy = AiroTrustedDeviceSecurityPolicy(
        requiredScope: AiroPairingScope.playbackControl,
        minimumTrustLevel: AiroTrustedDeviceTrustLevel.trusted,
        keyRotationInterval: const Duration(days: 30),
      );

      final result = policy.evaluate(
        record: relationship,
        now: issuedAt.add(const Duration(days: 1)),
      );

      expect(result.accepted, isTrue);
    });

    test('trusted device security rejects insufficient trust level', () {
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
        trustLevel: AiroTrustedDeviceTrustLevel.restricted,
      );
      final policy = AiroTrustedDeviceSecurityPolicy(
        requiredScope: AiroPairingScope.playbackControl,
        minimumTrustLevel: AiroTrustedDeviceTrustLevel.trusted,
      );

      final result = policy.evaluate(
        record: relationship,
        now: issuedAt.add(const Duration(days: 1)),
      );

      expect(
        result.has(AiroTrustedDeviceSecurityCode.trustLevelInsufficient),
        isTrue,
      );
    });

    test('trusted device security rejects missing key descriptor', () {
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
        includeKeyDescriptor: false,
      );
      final policy = AiroTrustedDeviceSecurityPolicy(
        requiredScope: AiroPairingScope.playbackControl,
      );

      final result = policy.evaluate(
        record: relationship,
        now: issuedAt.add(const Duration(days: 1)),
      );

      expect(result.has(AiroTrustedDeviceSecurityCode.keyMissing), isTrue);
    });

    test('trusted device security rejects key lifecycle failures', () {
      final policy = AiroTrustedDeviceSecurityPolicy(
        requiredScope: AiroPairingScope.playbackControl,
        keyRotationInterval: const Duration(days: 30),
      );

      AiroTrustedDeviceSecurityResult evaluate(
        AiroTrustedDeviceKeyDescriptor keyDescriptor,
      ) {
        return policy.evaluate(
          record: trustedDeviceRecord(
            issuedAt: issuedAt,
            expiresAt: trustedUntil,
            keyDescriptor: keyDescriptor,
          ),
          now: issuedAt.add(const Duration(days: 31)),
        );
      }

      expect(
        evaluate(
          trustedKeyDescriptor(
            issuedAt: issuedAt.add(const Duration(days: 32)),
            expiresAt: trustedUntil,
          ),
        ).has(AiroTrustedDeviceSecurityCode.keyNotYetValid),
        isTrue,
      );
      expect(
        evaluate(
          trustedKeyDescriptor(
            issuedAt: issuedAt,
            expiresAt: issuedAt.add(const Duration(days: 20)),
          ),
        ).has(AiroTrustedDeviceSecurityCode.keyExpired),
        isTrue,
      );
      expect(
        evaluate(
          trustedKeyDescriptor(
            issuedAt: issuedAt,
            expiresAt: trustedUntil,
            revokedAt: issuedAt.add(const Duration(days: 10)),
          ),
        ).has(AiroTrustedDeviceSecurityCode.keyRevoked),
        isTrue,
      );
      expect(
        evaluate(
          trustedKeyDescriptor(issuedAt: issuedAt, expiresAt: trustedUntil),
        ).has(AiroTrustedDeviceSecurityCode.keyRotationRequired),
        isTrue,
      );
    });

    test('trusted device security rejects unsupported key algorithm', () {
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
      );
      final policy = AiroTrustedDeviceSecurityPolicy(
        requiredScope: AiroPairingScope.playbackControl,
        allowedKeyAlgorithms: const {AiroTrustedDeviceKeyAlgorithm.p256},
      );

      final result = policy.evaluate(
        record: relationship,
        now: issuedAt.add(const Duration(days: 1)),
      );

      expect(result.has(AiroTrustedDeviceSecurityCode.keyUnsupported), isTrue);
    });

    test('trusted device security preserves revocation as access denial', () {
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
        revokedAt: issuedAt.add(const Duration(minutes: 1)),
      );
      final policy = AiroTrustedDeviceSecurityPolicy(
        requiredScope: AiroPairingScope.playbackControl,
      );

      final result = policy.evaluate(
        record: relationship,
        now: issuedAt.add(const Duration(minutes: 1)),
      );

      expect(result.has(AiroTrustedDeviceSecurityCode.accessDenied), isTrue);
      expect(
        result.blockers
            .where(
              (blocker) =>
                  blocker.accessCode == AiroTrustedDeviceAccessCode.revoked,
            )
            .length,
        1,
      );
    });

    test('restricted receiver allows valid playback ticket redemption', () {
      final policy = AiroRestrictedReceiverTrustPolicy();
      final now = issuedAt.add(const Duration(minutes: 1));
      final ticket = AiroPlaybackTicket(
        ticketId: 'playback-ticket-1',
        receiverDeviceId: 'receiver-tv-1',
        sessionId: 'session-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('source-ref-1'),
        scopes: const {AiroPairingScope.playbackControl},
        issuedAt: issuedAt,
        notBefore: issuedAt,
        expiresAt: issuedAt.add(const Duration(minutes: 5)),
      );

      final decision = policy.evaluate(
        relationship: trustedDeviceRecord(
          issuedAt: issuedAt,
          expiresAt: trustedUntil,
          trustLevel: AiroTrustedDeviceTrustLevel.restricted,
        ),
        action: AiroRestrictedReceiverAction.redeemPlaybackTicket,
        receiverDeviceId: 'receiver-tv-1',
        sessionId: 'session-1',
        playbackTicket: ticket,
        now: now,
      );

      expect(decision.accepted, isTrue);
      expect(
        decision.playbackTicketCode,
        AiroPlaybackTicketValidationCode.accepted,
      );
      expect(decision.toPublicMap(), {
        'relationshipId': 'trusted-device-1',
        'receiverDeviceId': 'receiver-tv-1',
        'action': AiroRestrictedReceiverAction.redeemPlaybackTicket.stableId,
        'codes': [AiroRestrictedReceiverTrustCode.accepted.stableId],
        'accessCode': AiroTrustedDeviceAccessCode.accepted.stableId,
        'playbackTicketCode':
            AiroPlaybackTicketValidationCode.accepted.stableId,
      });
    });

    test('restricted receiver allows scoped reporting and basic control', () {
      final policy = AiroRestrictedReceiverTrustPolicy();
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
        trustLevel: AiroTrustedDeviceTrustLevel.restricted,
        scopes: const {
          AiroPairingScope.playbackControl,
          AiroPairingScope.diagnostics,
        },
      );
      final now = issuedAt.add(const Duration(minutes: 1));

      final report = policy.evaluate(
        relationship: relationship,
        action: AiroRestrictedReceiverAction.reportPlaybackState,
        receiverDeviceId: 'receiver-tv-1',
        now: now,
      );
      final control = policy.evaluate(
        relationship: relationship,
        action: AiroRestrictedReceiverAction.playbackControl,
        receiverDeviceId: 'receiver-tv-1',
        now: now,
      );

      expect(report.accepted, isTrue);
      expect(control.accepted, isTrue);
    });

    test('restricted receiver denies privileged product actions', () {
      final policy = AiroRestrictedReceiverTrustPolicy();
      final relationship = trustedDeviceRecord(
        issuedAt: issuedAt,
        expiresAt: trustedUntil,
        trustLevel: AiroTrustedDeviceTrustLevel.owner,
      );
      final now = issuedAt.add(const Duration(minutes: 1));

      final deniedActions = {
        AiroRestrictedReceiverAction.sourceCredentialRead:
            AiroRestrictedReceiverTrustCode.credentialAccessDenied,
        AiroRestrictedReceiverAction.rawSourceHandleRead:
            AiroRestrictedReceiverTrustCode.rawSourceAccessDenied,
        AiroRestrictedReceiverAction.adminAction:
            AiroRestrictedReceiverTrustCode.adminActionDenied,
        AiroRestrictedReceiverAction.billingAction:
            AiroRestrictedReceiverTrustCode.billingActionDenied,
        AiroRestrictedReceiverAction.profileManagement:
            AiroRestrictedReceiverTrustCode.profileManagementDenied,
        AiroRestrictedReceiverAction.trustedDeviceManagement:
            AiroRestrictedReceiverTrustCode.trustedDeviceManagementDenied,
        AiroRestrictedReceiverAction.issuePlaybackTicket:
            AiroRestrictedReceiverTrustCode.ticketIssueDenied,
      };

      for (final entry in deniedActions.entries) {
        final decision = policy.evaluate(
          relationship: relationship,
          action: entry.key,
          receiverDeviceId: 'receiver-tv-1',
          now: now,
        );

        expect(decision.accepted, isFalse);
        expect(
          decision.codes,
          contains(AiroRestrictedReceiverTrustCode.actionNotAllowed),
        );
        expect(decision.codes, contains(entry.value));
      }
    });

    test('restricted receiver maps relationship and ticket failures', () {
      final policy = AiroRestrictedReceiverTrustPolicy();
      final now = issuedAt.add(const Duration(minutes: 1));
      final ticket = AiroPlaybackTicket(
        ticketId: 'playback-ticket-1',
        receiverDeviceId: 'other-tv',
        sessionId: 'session-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('source-ref-1'),
        scopes: const {AiroPairingScope.playbackControl},
        issuedAt: issuedAt,
        notBefore: issuedAt,
        expiresAt: issuedAt.add(const Duration(minutes: 5)),
      );

      final decision = policy.evaluate(
        relationship: trustedDeviceRecord(
          issuedAt: issuedAt,
          expiresAt: trustedUntil,
          revokedAt: now,
          trustLevel: AiroTrustedDeviceTrustLevel.restricted,
        ),
        action: AiroRestrictedReceiverAction.redeemPlaybackTicket,
        receiverDeviceId: 'receiver-tv-1',
        sessionId: 'session-1',
        playbackTicket: ticket,
        now: now,
      );

      expect(
        decision.codes,
        contains(AiroRestrictedReceiverTrustCode.relationshipRevoked),
      );
      expect(
        decision.codes,
        contains(AiroRestrictedReceiverTrustCode.playbackTicketDenied),
      );
      expect(
        decision.playbackTicketCode,
        AiroPlaybackTicketValidationCode.receiverMismatch,
      );
    });

    test('restricted receiver diagnostics omit source material', () {
      final policy = AiroRestrictedReceiverTrustPolicy();

      final decision = policy.evaluate(
        relationship: trustedDeviceRecord(
          issuedAt: issuedAt,
          expiresAt: trustedUntil,
          trustLevel: AiroTrustedDeviceTrustLevel.owner,
        ),
        action: AiroRestrictedReceiverAction.sourceCredentialRead,
        receiverDeviceId: 'receiver-tv-1',
        now: issuedAt.add(const Duration(minutes: 1)),
      );
      final flattened = decision.toPublicMap().toString();

      expect(flattened, isNot(contains('source-ref-1')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('providerPayload')));
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

AiroTrustedDeviceKeyDescriptor trustedKeyDescriptor({
  required DateTime issuedAt,
  required DateTime expiresAt,
  AiroTrustedDeviceKeyAlgorithm algorithm =
      AiroTrustedDeviceKeyAlgorithm.ed25519,
  DateTime? revokedAt,
}) {
  return AiroTrustedDeviceKeyDescriptor(
    keyId: 'key-1',
    algorithm: algorithm,
    publicKeyFingerprint: 'pub-fingerprint-1',
    createdAt: issuedAt,
    notBefore: issuedAt,
    expiresAt: expiresAt,
    revokedAt: revokedAt,
  );
}

AiroTrustedDeviceRecord trustedDeviceRecord({
  required DateTime issuedAt,
  required DateTime expiresAt,
  AiroTrustedDeviceTrustLevel trustLevel = AiroTrustedDeviceTrustLevel.trusted,
  Set<AiroPairingScope> scopes = const {
    AiroPairingScope.playbackControl,
    AiroPairingScope.companionSearch,
  },
  AiroTrustedDeviceKeyDescriptor? keyDescriptor,
  bool includeKeyDescriptor = true,
  DateTime? revokedAt,
}) {
  return AiroTrustedDeviceRecord(
    relationshipId: 'trusted-device-1',
    controllerDeviceId: 'phone-1',
    receiverDeviceId: 'receiver-tv-1',
    controllerRole: AiroDeviceRole.mobileController,
    receiverRole: AiroDeviceRole.tvReceiver,
    scopes: scopes,
    createdAt: issuedAt,
    expiresAt: expiresAt,
    revokedAt: revokedAt,
    trustLevel: trustLevel,
    keyDescriptor: includeKeyDescriptor
        ? keyDescriptor ??
              trustedKeyDescriptor(issuedAt: issuedAt, expiresAt: expiresAt)
        : null,
  );
}
