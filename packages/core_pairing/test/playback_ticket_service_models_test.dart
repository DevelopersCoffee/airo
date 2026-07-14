import 'package:core_pairing/core_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final issuedAt = DateTime.utc(2026, 7, 14, 12);
  final notBefore = issuedAt.add(const Duration(seconds: 5));
  final expiresAt = issuedAt.add(const Duration(minutes: 2));
  final policy = AiroPlaybackTicketServicePolicy(
    minLifetime: const Duration(seconds: 5),
    maxLifetime: const Duration(minutes: 5),
    keyRotationInterval: const Duration(days: 30),
  );

  group('AiroPlaybackTicketServicePolicy', () {
    test('issues a receiver-bound short-lived ticket from trusted issuer', () {
      final decision = policy.evaluateIssue(
        request: _issueRequest(
          issuedAt: issuedAt,
          notBefore: notBefore,
          expiresAt: expiresAt,
        ),
        issuer: _issuer(issuedAt: issuedAt),
        now: issuedAt.add(const Duration(seconds: 1)),
      );

      expect(decision.accepted, isTrue);
      expect(decision.action, AiroPlaybackTicketServiceAction.issue);
      expect(decision.ticket?.receiverDeviceId, 'receiver-tv-1');
      expect(decision.ticket?.sessionId, 'session-1');
      expect(decision.toDiagnosticMap(), {
        'action': 'issue',
        'codes': ['accepted'],
        'ticketId': 'playback-ticket-1',
        'receiverDeviceId': 'receiver-tv-1',
        'sessionId': 'session-1',
      });
    });

    test(
      'rejects issuer access, trust, receiver, scope, and lifetime failures',
      () {
        final decision = policy.evaluateIssue(
          request: _issueRequest(
            issuedAt: issuedAt,
            notBefore: notBefore,
            expiresAt: notBefore.add(const Duration(hours: 1)),
            scopes: const {AiroPairingScope.sourceSelection},
          ),
          issuer: _issuer(
            issuedAt: issuedAt,
            receiverDeviceId: 'other-tv',
            scopes: const {AiroPairingScope.playbackControl},
            trustLevel: AiroTrustedDeviceTrustLevel.restricted,
          ),
          now: issuedAt.add(const Duration(seconds: 1)),
        );

        expect(decision.action, AiroPlaybackTicketServiceAction.deny);
        expect(decision.codes, [
          AiroPlaybackTicketServiceCode.issuerAccessDenied,
          AiroPlaybackTicketServiceCode.issuerTrustInsufficient,
          AiroPlaybackTicketServiceCode.receiverMismatch,
          AiroPlaybackTicketServiceCode.scopeMissing,
          AiroPlaybackTicketServiceCode.invalidLifetime,
        ]);
      },
    );

    test(
      'rejects missing, unsupported, early, expired, revoked, and rotating keys',
      () {
        AiroPlaybackTicketServiceDecision evaluate(
          AiroTrustedDeviceRecord issuer,
        ) {
          return policy.evaluateIssue(
            request: _issueRequest(
              issuedAt: issuedAt,
              notBefore: notBefore,
              expiresAt: expiresAt,
            ),
            issuer: issuer,
            now: issuedAt.add(const Duration(days: 31)),
          );
        }

        expect(
          evaluate(
            _issuer(issuedAt: issuedAt, includeKeyDescriptor: false),
          ).codes,
          [AiroPlaybackTicketServiceCode.issuerKeyMissing],
        );
        expect(
          AiroPlaybackTicketServicePolicy(
                allowedKeyAlgorithms: const {
                  AiroTrustedDeviceKeyAlgorithm.p256,
                },
              )
              .evaluateIssue(
                request: _issueRequest(
                  issuedAt: issuedAt,
                  notBefore: notBefore,
                  expiresAt: expiresAt,
                ),
                issuer: _issuer(issuedAt: issuedAt),
                now: issuedAt.add(const Duration(seconds: 1)),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.issuerKeyUnsupported],
        );
        expect(
          evaluate(
            _issuer(
              issuedAt: issuedAt,
              keyDescriptor: _key(
                issuedAt: issuedAt.add(const Duration(days: 32)),
                expiresAt: issuedAt.add(const Duration(days: 90)),
              ),
            ),
          ).codes,
          [AiroPlaybackTicketServiceCode.issuerKeyNotYetValid],
        );
        expect(
          evaluate(
            _issuer(
              issuedAt: issuedAt,
              keyDescriptor: _key(
                issuedAt: issuedAt,
                expiresAt: issuedAt.add(const Duration(days: 10)),
              ),
            ),
          ).codes,
          [AiroPlaybackTicketServiceCode.issuerKeyExpired],
        );
        expect(
          evaluate(
            _issuer(
              issuedAt: issuedAt,
              keyDescriptor: _key(
                issuedAt: issuedAt,
                expiresAt: issuedAt.add(const Duration(days: 90)),
                revokedAt: issuedAt.add(const Duration(days: 10)),
              ),
            ),
          ).codes,
          [AiroPlaybackTicketServiceCode.issuerKeyRevoked],
        );
        expect(evaluate(_issuer(issuedAt: issuedAt)).codes, [
          AiroPlaybackTicketServiceCode.issuerKeyRotationRequired,
        ]);
      },
    );

    test('redeems a ticket once and rejects second use', () {
      final ticket = _ticket(
        issuedAt: issuedAt,
        notBefore: notBefore,
        expiresAt: expiresAt,
      );
      final first = policy.evaluateRedeem(
        ticket: ticket,
        request: _redeemRequest(redeemedAt: notBefore),
      );
      final second = policy.evaluateRedeem(
        ticket: first.ticket!,
        request: _redeemRequest(
          redeemedAt: notBefore.add(const Duration(seconds: 1)),
        ),
      );

      expect(first.accepted, isTrue);
      expect(first.action, AiroPlaybackTicketServiceAction.redeem);
      expect(first.ticket?.usedAt, notBefore);
      expect(second.action, AiroPlaybackTicketServiceAction.deny);
      expect(second.codes, [AiroPlaybackTicketServiceCode.alreadyUsed]);
    });

    test(
      'rejects receiver, session, scope, timing, revocation, and unsafe source',
      () {
        final ticket = _ticket(
          issuedAt: issuedAt,
          notBefore: notBefore,
          expiresAt: expiresAt,
        );

        expect(
          policy
              .evaluateRedeem(
                ticket: ticket,
                request: _redeemRequest(
                  receiverDeviceId: 'other-tv',
                  redeemedAt: notBefore,
                ),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.receiverMismatch],
        );
        expect(
          policy
              .evaluateRedeem(
                ticket: ticket,
                request: _redeemRequest(
                  sessionId: 'other-session',
                  redeemedAt: notBefore,
                ),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.sessionMismatch],
        );
        expect(
          policy
              .evaluateRedeem(
                ticket: _ticket(
                  issuedAt: issuedAt,
                  notBefore: notBefore,
                  expiresAt: expiresAt,
                  scopes: const {AiroPairingScope.sourceSelection},
                ),
                request: _redeemRequest(redeemedAt: notBefore),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.scopeMissing],
        );
        expect(
          policy
              .evaluateRedeem(
                ticket: ticket,
                request: _redeemRequest(redeemedAt: issuedAt),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.notYetValid],
        );
        expect(
          policy
              .evaluateRedeem(
                ticket: ticket,
                request: _redeemRequest(redeemedAt: expiresAt),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.expired],
        );
        expect(
          policy
              .evaluateRedeem(
                ticket: ticket.copyWith(revokedAt: notBefore),
                request: _redeemRequest(redeemedAt: notBefore),
              )
              .codes,
          [AiroPlaybackTicketServiceCode.revoked],
        );
        expect(
          AiroPlaybackSourceHandle.validate('https://example.test/live.m3u8'),
          AiroPlaybackSourceHandleRejectionCode.urlValue,
        );
      },
    );

    test('issue request and diagnostics redact source handles', () {
      final request = _issueRequest(
        issuedAt: issuedAt,
        notBefore: notBefore,
        expiresAt: expiresAt,
      );
      final decision = policy.evaluateIssue(
        request: request,
        issuer: _issuer(issuedAt: issuedAt),
        now: issuedAt.add(const Duration(seconds: 1)),
      );

      expect(request.sourceHandle.value, 'source-ref-1');
      expect(request.toString(), isNot(contains('source-ref-1')));
      expect(
        decision.toDiagnosticMap().toString(),
        isNot(contains('source-ref-1')),
      );
      expect(decision.ticket.toString(), isNot(contains('source-ref-1')));
    });
  });

  group('AiroPlaybackTicketService implementations', () {
    test(
      'fake service issues, redeems, and revokes deterministically',
      () async {
        final service = AiroFakePlaybackTicketService(policy: policy);
        final issued = await service.issue(
          request: _issueRequest(
            issuedAt: issuedAt,
            notBefore: notBefore,
            expiresAt: expiresAt,
          ),
          issuer: _issuer(issuedAt: issuedAt),
          now: issuedAt.add(const Duration(seconds: 1)),
        );
        final redeemed = await service.redeem(
          request: _redeemRequest(redeemedAt: notBefore),
        );
        final repeat = await service.redeem(
          request: _redeemRequest(
            redeemedAt: notBefore.add(const Duration(seconds: 1)),
          ),
        );
        final revoked = await service.revoke(
          ticketId: 'playback-ticket-1',
          revokedAt: notBefore.add(const Duration(seconds: 2)),
        );

        expect(issued.accepted, isTrue);
        expect(redeemed.accepted, isTrue);
        expect(repeat.codes, [AiroPlaybackTicketServiceCode.alreadyUsed]);
        expect(revoked?.revokedAt, notBefore.add(const Duration(seconds: 2)));
      },
    );

    test('no-op service has no side effects', () async {
      const service = AiroNoOpPlaybackTicketService();

      final issued = await service.issue(
        request: _issueRequest(
          issuedAt: issuedAt,
          notBefore: notBefore,
          expiresAt: expiresAt,
        ),
        issuer: _issuer(issuedAt: issuedAt),
        now: issuedAt,
      );
      final redeemed = await service.redeem(
        request: _redeemRequest(redeemedAt: notBefore),
      );

      expect(issued.action, AiroPlaybackTicketServiceAction.noOp);
      expect(redeemed.action, AiroPlaybackTicketServiceAction.noOp);
      expect(issued.codes, [AiroPlaybackTicketServiceCode.serviceUnavailable]);
      expect(
        await service.revoke(
          ticketId: 'playback-ticket-1',
          revokedAt: notBefore,
        ),
        isNull,
      );
    });
  });
}

AiroPlaybackTicketIssueRequest _issueRequest({
  required DateTime issuedAt,
  required DateTime notBefore,
  required DateTime expiresAt,
  Set<AiroPairingScope> scopes = const {
    AiroPairingScope.playbackControl,
    AiroPairingScope.sourceSelection,
  },
}) {
  return AiroPlaybackTicketIssueRequest(
    requestId: 'ticket-request-1',
    ticketId: 'playback-ticket-1',
    receiverDeviceId: 'receiver-tv-1',
    sessionId: 'session-1',
    sourceHandle: AiroPlaybackSourceHandle.redacted('source-ref-1'),
    scopes: scopes,
    issuerDeviceId: 'phone-1',
    issuedAt: issuedAt,
    notBefore: notBefore,
    expiresAt: expiresAt,
  );
}

AiroPlaybackTicketRedeemRequest _redeemRequest({
  String receiverDeviceId = 'receiver-tv-1',
  String sessionId = 'session-1',
  required DateTime redeemedAt,
}) {
  return AiroPlaybackTicketRedeemRequest(
    requestId: 'redeem-request-1',
    ticketId: 'playback-ticket-1',
    receiverDeviceId: receiverDeviceId,
    sessionId: sessionId,
    requiredScope: AiroPairingScope.playbackControl,
    redeemedAt: redeemedAt,
  );
}

AiroPlaybackTicket _ticket({
  required DateTime issuedAt,
  required DateTime notBefore,
  required DateTime expiresAt,
  Set<AiroPairingScope> scopes = const {
    AiroPairingScope.playbackControl,
    AiroPairingScope.sourceSelection,
  },
}) {
  return AiroPlaybackTicket(
    ticketId: 'playback-ticket-1',
    receiverDeviceId: 'receiver-tv-1',
    sessionId: 'session-1',
    sourceHandle: AiroPlaybackSourceHandle.redacted('source-ref-1'),
    scopes: scopes,
    issuedAt: issuedAt,
    notBefore: notBefore,
    expiresAt: expiresAt,
  );
}

AiroTrustedDeviceRecord _issuer({
  required DateTime issuedAt,
  String receiverDeviceId = 'receiver-tv-1',
  Set<AiroPairingScope> scopes = const {
    AiroPairingScope.playbackTicketIssue,
    AiroPairingScope.playbackControl,
  },
  AiroTrustedDeviceTrustLevel trustLevel = AiroTrustedDeviceTrustLevel.trusted,
  AiroTrustedDeviceKeyDescriptor? keyDescriptor,
  bool includeKeyDescriptor = true,
}) {
  return AiroTrustedDeviceRecord(
    relationshipId: 'trusted-device-1',
    controllerDeviceId: 'phone-1',
    receiverDeviceId: receiverDeviceId,
    controllerRole: AiroDeviceRole.mobileController,
    receiverRole: AiroDeviceRole.tvReceiver,
    scopes: scopes,
    createdAt: issuedAt,
    expiresAt: issuedAt.add(const Duration(days: 90)),
    trustLevel: trustLevel,
    keyDescriptor: includeKeyDescriptor
        ? keyDescriptor ??
              _key(
                issuedAt: issuedAt,
                expiresAt: issuedAt.add(const Duration(days: 90)),
              )
        : null,
  );
}

AiroTrustedDeviceKeyDescriptor _key({
  required DateTime issuedAt,
  required DateTime expiresAt,
  DateTime? revokedAt,
}) {
  return AiroTrustedDeviceKeyDescriptor(
    keyId: 'key-1',
    algorithm: AiroTrustedDeviceKeyAlgorithm.ed25519,
    publicKeyFingerprint: 'pub-fingerprint-1',
    createdAt: issuedAt,
    notBefore: issuedAt,
    expiresAt: expiresAt,
    revokedAt: revokedAt,
  );
}
