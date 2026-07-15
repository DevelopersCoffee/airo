import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_presence/core_presence.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 10);
  const minInterval = Duration(seconds: 5);
  const maxInterval = Duration(minutes: 5);
  final policy = AiroPresencePolicy(
    minHeartbeatInterval: minInterval,
    maxHeartbeatInterval: maxInterval,
    minLeaseDuration: const Duration(seconds: 15),
    maxLeaseDuration: const Duration(minutes: 10),
  );

  group('AiroPresencePolicy', () {
    test('accepts an active heartbeat from a registered device', () {
      final decision = policy.evaluate(
        heartbeat: _heartbeat(now),
        now: now,
        deviceRecord: _device(now),
      );

      expect(decision.accepted, isTrue);
      expect(decision.toDiagnosticMap(), {
        'leaseId': 'lease-1',
        'action': 'accept',
        'codes': ['accepted'],
      });
    });

    test('public lease map omits private transport and media fields', () {
      final rendered = _heartbeat(now).toLease().toPublicMap().toString();

      expect(rendered, contains('lease-1'));
      expect(rendered, contains('available'));
      expect(rendered, isNot(contains('192.168')));
      expect(rendered, isNot(contains('playlist')));
      expect(rendered, isNot(contains('mediaUrl')));
      expect(rendered, isNot(contains('credential')));
    });

    test('denies stale sequence, expired lease, and bad heartbeat cadence', () {
      final currentLease = _lease(
        now,
        sequence: 5,
        lastHeartbeatAt: now,
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );
      final decision = policy.evaluate(
        heartbeat: _heartbeat(
          now,
          sequence: 5,
          observedAt: now.add(const Duration(seconds: 1)),
        ),
        now: now,
        currentLease: currentLease,
        deviceRecord: _device(now),
      );

      expect(decision.action, AiroPresenceDecisionAction.deny);
      expect(decision.codes, [
        AiroPresenceCode.expiredLease,
        AiroPresenceCode.staleSequence,
        AiroPresenceCode.heartbeatTooSoon,
      ]);
    });

    test('denies heartbeat too late, lease bounds, and visibility denial', () {
      final restrictedPolicy = AiroPresencePolicy(
        allowedVisibility: const {AiroPresenceVisibility.localNetwork},
        minHeartbeatInterval: minInterval,
        maxHeartbeatInterval: maxInterval,
        minLeaseDuration: const Duration(seconds: 15),
        maxLeaseDuration: const Duration(minutes: 10),
      );

      final tooShort = restrictedPolicy.evaluate(
        heartbeat: _heartbeat(
          now,
          visibility: AiroPresenceVisibility.account,
          expiresAt: now.add(const Duration(seconds: 5)),
        ),
        now: now,
        deviceRecord: _device(now),
      );
      final tooLongAndLate = restrictedPolicy.evaluate(
        heartbeat: _heartbeat(
          now,
          sequence: 2,
          observedAt: now.add(const Duration(minutes: 6)),
          expiresAt: now.add(const Duration(minutes: 30)),
          heartbeatInterval: const Duration(minutes: 6),
        ),
        now: now.add(const Duration(minutes: 6)),
        currentLease: _lease(
          now,
          expiresAt: now.add(const Duration(minutes: 8)),
        ),
        deviceRecord: _device(now),
      );

      expect(tooShort.codes, [
        AiroPresenceCode.visibilityDenied,
        AiroPresenceCode.leaseTooShort,
      ]);
      expect(tooLongAndLate.codes, [
        AiroPresenceCode.heartbeatTooLate,
        AiroPresenceCode.visibilityDenied,
        AiroPresenceCode.heartbeatTooLate,
        AiroPresenceCode.leaseTooLong,
      ]);
    });

    test('denies unregistered, mismatched, revoked, and reset devices', () {
      final unregistered = policy.evaluate(
        heartbeat: _heartbeat(now),
        now: now,
      );
      final mismatched = policy.evaluate(
        heartbeat: _heartbeat(now, accountId: 'account-2'),
        now: now,
        deviceRecord: _device(now),
      );
      final revoked = policy.evaluate(
        heartbeat: _heartbeat(now),
        now: now.add(const Duration(minutes: 1)),
        deviceRecord: _device(
          now,
          state: AiroDeviceRegistrationState.revoked,
          revokedAt: now.add(const Duration(seconds: 30)),
        ),
      );
      final reset = policy.evaluate(
        heartbeat: _heartbeat(now),
        now: now,
        deviceRecord: _device(
          now,
          state: AiroDeviceRegistrationState.resetRequired,
        ),
      );

      expect(unregistered.codes, [AiroPresenceCode.unregisteredDevice]);
      expect(mismatched.codes, [AiroPresenceCode.accountMismatch]);
      expect(revoked.codes, [AiroPresenceCode.revokedDevice]);
      expect(reset.codes, [AiroPresenceCode.resetRequired]);
    });

    test('rejects unsafe stable identifiers', () {
      expect(
        AiroDeviceStableValue.validate('receiver-192.168.1.10'),
        AiroDeviceStableValueRejectionCode.localIpValue,
      );
    });
  });

  group('AiroPresenceStore implementations', () {
    test('fake store records and expires leases deterministically', () async {
      final store = AiroFakePresenceStore(
        policy: policy,
        devices: [_device(now)],
      );

      final accepted = await store.recordHeartbeat(
        heartbeat: _heartbeat(now),
        now: now,
      );
      final active = await store.activeLeases(now: now);
      final expired = await store.expireLease(
        leaseId: AiroDeviceStableValue.stable('lease-1'),
        now: now.add(const Duration(minutes: 1)),
      );

      expect(accepted.accepted, isTrue);
      expect(active, hasLength(1));
      expect(expired?.status, AiroPresenceStatus.offline);
      expect(
        await store.activeLeases(now: now.add(const Duration(minutes: 1))),
        isEmpty,
      );
    });

    test('no-op store never connects to storage', () async {
      const store = AiroNoOpPresenceStore();

      final decision = await store.recordHeartbeat(
        heartbeat: _heartbeat(now),
        now: now,
      );

      expect(decision.action, AiroPresenceDecisionAction.noOp);
      expect(decision.codes, [AiroPresenceCode.storeUnavailable]);
      expect(await store.activeLeases(now: now), isEmpty);
    });
  });
}

AiroPresenceHeartbeat _heartbeat(
  DateTime now, {
  String accountId = 'account-1',
  int sequence = 1,
  DateTime? observedAt,
  DateTime? expiresAt,
  Duration heartbeatInterval = const Duration(seconds: 30),
  AiroPresenceVisibility visibility = AiroPresenceVisibility.trustedDevices,
}) {
  final timestamp = observedAt ?? now;
  return AiroPresenceHeartbeat(
    leaseId: AiroDeviceStableValue.stable('lease-1'),
    accountId: AiroDeviceStableValue.stable(accountId),
    deviceId: AiroDeviceStableValue.stable('device-tv-1'),
    registrationId: AiroDeviceStableValue.stable('registration-1'),
    status: AiroPresenceStatus.available,
    lifecycle: AiroNodeLifecycleState.available,
    visibility: visibility,
    visibleCapabilities: const {
      AiroNodeCapability.playback,
      AiroNodeCapability.remoteControl,
    },
    sequence: sequence,
    observedAt: timestamp,
    expiresAt: expiresAt ?? timestamp.add(const Duration(minutes: 2)),
    heartbeatInterval: heartbeatInterval,
  );
}

AiroPresenceLease _lease(
  DateTime now, {
  int sequence = 1,
  DateTime? lastHeartbeatAt,
  DateTime? expiresAt,
}) {
  return AiroPresenceLease(
    leaseId: AiroDeviceStableValue.stable('lease-1'),
    accountId: AiroDeviceStableValue.stable('account-1'),
    deviceId: AiroDeviceStableValue.stable('device-tv-1'),
    registrationId: AiroDeviceStableValue.stable('registration-1'),
    status: AiroPresenceStatus.available,
    lifecycle: AiroNodeLifecycleState.available,
    visibility: AiroPresenceVisibility.trustedDevices,
    visibleCapabilities: const {
      AiroNodeCapability.playback,
      AiroNodeCapability.remoteControl,
    },
    sequence: sequence,
    issuedAt: now,
    lastHeartbeatAt: lastHeartbeatAt ?? now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 2)),
    heartbeatInterval: const Duration(seconds: 30),
  );
}

AiroRegisteredDeviceRecord _device(
  DateTime now, {
  AiroDeviceRegistrationState state = AiroDeviceRegistrationState.active,
  DateTime? revokedAt,
}) {
  return AiroRegisteredDeviceRecord(
    registrationId: AiroDeviceStableValue.stable('registration-1'),
    accountId: AiroDeviceStableValue.stable('account-1'),
    deviceId: AiroDeviceStableValue.stable('device-tv-1'),
    nodeIdentity: const AiroNodeIdentity(
      nodeId: 'node-tv-1',
      role: AiroNodeRole.tvReceiver,
      productProfile: AiroNodeProductProfile.liteReceiver,
      platformCategory: AiroNodePlatformCategory.androidTv,
    ),
    keyDescriptor: AiroTrustedDeviceKeyDescriptor(
      keyId: 'key-1',
      algorithm: AiroTrustedDeviceKeyAlgorithm.ed25519,
      publicKeyFingerprint: 'SHA256:public-fingerprint-1',
      createdAt: now,
      notBefore: now,
      expiresAt: now.add(const Duration(days: 90)),
    ),
    scopes: const {AiroPairingScope.playbackControl},
    registeredAt: now,
    state: state,
    revokedAt: revokedAt,
  );
}
