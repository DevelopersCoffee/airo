import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 9);
  final policy = AiroDeviceRegistrationPolicy(
    keyRotationInterval: const Duration(days: 30),
  );

  group('AiroDeviceRegistrationPolicy', () {
    test('accepts a valid receiver registration', () {
      final decision = policy.evaluate(
        request: _request(now),
        now: now.add(const Duration(minutes: 1)),
      );

      expect(decision.accepted, isTrue);
      expect(decision.action, AiroDeviceRegistrationAction.register);
      expect(decision.toDiagnosticMap(), {
        'requestId': 'request-1',
        'action': 'register',
        'codes': ['accepted'],
        'existingDeviceId': null,
      });
    });

    test('merges an idempotent repeat of the same active device', () {
      final request = _request(now);
      final existing = request.toRecord();

      final decision = policy.evaluate(
        request: request,
        now: now.add(const Duration(minutes: 1)),
        existingDevices: [existing],
      );

      expect(decision.accepted, isTrue);
      expect(decision.action, AiroDeviceRegistrationAction.mergeExisting);
      expect(decision.existingDeviceId, existing.deviceId);
    });

    test('denies duplicate node identity and key fingerprint', () {
      final decision = policy.evaluate(
        request: _request(
          now,
          registrationId: 'registration-2',
          deviceId: 'device-tv-2',
        ),
        now: now.add(const Duration(minutes: 1)),
        existingDevices: [_request(now).toRecord()],
      );

      expect(decision.action, AiroDeviceRegistrationAction.deny);
      expect(decision.codes, [
        AiroDeviceRegistrationCode.duplicateNodeIdentity,
        AiroDeviceRegistrationCode.duplicateKeyFingerprint,
      ]);
    });

    test('denies revoked and reset-required existing records', () {
      final revoked = _request(now).toRecord().copyWith(
        state: AiroDeviceRegistrationState.revoked,
        revokedAt: now.add(const Duration(minutes: 1)),
      );
      final resetRequired = _request(now).toRecord().copyWith(
        state: AiroDeviceRegistrationState.resetRequired,
        resetGeneration: 2,
      );

      final revokedDecision = policy.evaluate(
        request: _request(now),
        now: now.add(const Duration(minutes: 1)),
        existingDevices: [revoked],
      );
      final resetDecision = policy.evaluate(
        request: _request(now),
        now: now.add(const Duration(minutes: 1)),
        existingDevices: [resetRequired],
      );

      expect(revokedDecision.codes, [AiroDeviceRegistrationCode.revokedDevice]);
      expect(resetDecision.codes, [AiroDeviceRegistrationCode.resetRequired]);
    });

    test('denies unsupported roles, missing scopes, and expired requests', () {
      final decision = policy.evaluate(
        request: _request(
          now,
          nodeIdentity: _identity(role: AiroNodeRole.cloudCoordinator),
          scopes: const {},
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        now: now,
      );

      expect(decision.action, AiroDeviceRegistrationAction.deny);
      expect(decision.codes, [
        AiroDeviceRegistrationCode.unsupportedRole,
        AiroDeviceRegistrationCode.requiredScopeMissing,
        AiroDeviceRegistrationCode.expiredRequest,
      ]);
    });

    test(
      'denies missing, unsupported, expired, revoked, and rotating keys',
      () {
        AiroDeviceRegistrationDecision evaluate({
          AiroTrustedDeviceKeyDescriptor? keyDescriptor,
          bool includeKeyDescriptor = true,
        }) {
          return policy.evaluate(
            request: _request(
              now,
              keyDescriptor: keyDescriptor,
              includeKeyDescriptor: includeKeyDescriptor,
              expiresAt: now.add(const Duration(days: 40)),
            ),
            now: now.add(const Duration(days: 31)),
          );
        }

        expect(evaluate(includeKeyDescriptor: false).codes, [
          AiroDeviceRegistrationCode.keyMissing,
        ]);
        expect(
          AiroDeviceRegistrationPolicy(
                allowedKeyAlgorithms: const {
                  AiroTrustedDeviceKeyAlgorithm.p256,
                },
              )
              .evaluate(
                request: _request(now),
                now: now.add(const Duration(minutes: 1)),
              )
              .codes,
          [AiroDeviceRegistrationCode.keyUnsupported],
        );
        expect(
          evaluate(
            keyDescriptor: _key(
              now,
              notBefore: now.add(const Duration(days: 32)),
            ),
          ).codes,
          [AiroDeviceRegistrationCode.keyNotYetValid],
        );
        expect(
          evaluate(
            keyDescriptor: _key(
              now,
              expiresAt: now.add(const Duration(days: 10)),
            ),
          ).codes,
          [AiroDeviceRegistrationCode.keyExpired],
        );
        expect(
          evaluate(
            keyDescriptor: _key(
              now,
              revokedAt: now.add(const Duration(days: 10)),
            ),
          ).codes,
          [AiroDeviceRegistrationCode.keyRevoked],
        );
        expect(evaluate(keyDescriptor: _key(now)).codes, [
          AiroDeviceRegistrationCode.keyRotationRequired,
        ]);
      },
    );
  });

  group('AiroDeviceStableValue', () {
    test('rejects raw private identifiers', () {
      expect(
        AiroDeviceStableValue.validate('https://example.test/device'),
        AiroDeviceStableValueRejectionCode.urlValue,
      );
      expect(
        AiroDeviceStableValue.validate('/Users/dev/device.json'),
        AiroDeviceStableValueRejectionCode.localPathValue,
      );
      expect(
        AiroDeviceStableValue.validate('tv-192.168.0.10'),
        AiroDeviceStableValueRejectionCode.localIpValue,
      );
      expect(
        AiroDeviceStableValue.validate('Basic abc123'),
        AiroDeviceStableValueRejectionCode.credentialLikeValue,
      );
      expect(
        AiroDeviceStableValue.validate('device one'),
        AiroDeviceStableValueRejectionCode.invalidStableId,
      );
    });
  });

  group('AiroDeviceIdentityRegistry implementations', () {
    test(
      'fake registry stores accepted records and revokes deterministically',
      () async {
        final registry = AiroFakeDeviceIdentityRegistry(policy: policy);

        final decision = await registry.register(
          request: _request(now),
          now: now.add(const Duration(minutes: 1)),
        );
        final records = await registry.list();
        final revoked = await registry.revoke(
          deviceId: AiroDeviceStableValue.stable('device-tv-1'),
          now: now.add(const Duration(days: 2)),
        );

        expect(decision.accepted, isTrue);
        expect(records, hasLength(1));
        expect(
          records.single.toPublicMap().toString(),
          isNot(contains('SHA256')),
        );
        expect(revoked?.state, AiroDeviceRegistrationState.revoked);
        expect((await registry.list()).single.revokedAt, isNotNull);
      },
    );

    test('no-op registry never connects to storage', () async {
      const registry = AiroNoOpDeviceIdentityRegistry();

      final decision = await registry.register(
        request: _request(now),
        now: now.add(const Duration(minutes: 1)),
      );

      expect(decision.action, AiroDeviceRegistrationAction.noOp);
      expect(decision.codes, [AiroDeviceRegistrationCode.registryUnavailable]);
      expect(await registry.list(), isEmpty);
    });
  });
}

AiroDeviceRegistrationRequest _request(
  DateTime now, {
  String requestId = 'request-1',
  String registrationId = 'registration-1',
  String deviceId = 'device-tv-1',
  AiroNodeIdentity? nodeIdentity,
  AiroTrustedDeviceKeyDescriptor? keyDescriptor,
  bool includeKeyDescriptor = true,
  Set<AiroPairingScope> scopes = const {AiroPairingScope.playbackControl},
  DateTime? expiresAt,
}) {
  return AiroDeviceRegistrationRequest(
    requestId: AiroDeviceStableValue.stable(requestId),
    registrationId: AiroDeviceStableValue.stable(registrationId),
    accountId: AiroDeviceStableValue.stable('account-1'),
    deviceId: AiroDeviceStableValue.stable(deviceId),
    nodeIdentity: nodeIdentity ?? _identity(),
    keyDescriptor: includeKeyDescriptor ? keyDescriptor ?? _key(now) : null,
    trustLevel: AiroTrustedDeviceTrustLevel.paired,
    requestedScopes: scopes,
    channel: AiroDeviceRegistrationChannel.localPairing,
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
  );
}

AiroNodeIdentity _identity({AiroNodeRole role = AiroNodeRole.tvReceiver}) {
  return AiroNodeIdentity(
    nodeId: 'node-tv-1',
    role: role,
    productProfile: AiroNodeProductProfile.liteReceiver,
    platformCategory: AiroNodePlatformCategory.androidTv,
  );
}

AiroTrustedDeviceKeyDescriptor _key(
  DateTime now, {
  DateTime? notBefore,
  DateTime? expiresAt,
  DateTime? revokedAt,
}) {
  return AiroTrustedDeviceKeyDescriptor(
    keyId: 'key-1',
    algorithm: AiroTrustedDeviceKeyAlgorithm.ed25519,
    publicKeyFingerprint: 'SHA256:public-fingerprint-1',
    createdAt: now,
    notBefore: notBefore ?? now,
    expiresAt: expiresAt ?? now.add(const Duration(days: 90)),
    revokedAt: revokedAt,
  );
}
