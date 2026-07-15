import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_device_merge/core_device_merge.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_presence/core_presence.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);

  group('AiroDeviceMergePolicy', () {
    test('merges matching local and cloud records and prefers LAN', () {
      final result = AiroDeviceMergePolicy(
        requiredCapabilities: const {AiroNodeCapability.playback},
      ).merge(now: now, local: [_local(now)], cloud: [_cloud(now)]);

      expect(result.devices, hasLength(1));
      final device = result.devices.single;
      expect(device.stableDeviceId, 'device-tv-1');
      expect(device.nodeId, 'node-tv-1');
      expect(device.primarySource, AiroDeviceObservationSource.local);
      expect(device.reachability, AiroDeviceReachability.localAndCloud);
      expect(device.codes, [
        AiroDeviceMergeCode.duplicateMerged,
        AiroDeviceMergeCode.localPreferred,
      ]);
    });

    test('allows cloud-only fallback unless local-only mode is active', () {
      final cloudFallback = AiroDeviceMergePolicy().merge(
        now: now,
        cloud: [_cloud(now)],
      );
      final localOnly = AiroDeviceMergePolicy(
        localOnlyMode: true,
      ).merge(now: now, cloud: [_cloud(now)]);

      expect(cloudFallback.devices, hasLength(1));
      expect(
        cloudFallback.devices.single.reachability,
        AiroDeviceReachability.cloudOnly,
      );
      expect(cloudFallback.devices.single.codes, [
        AiroDeviceMergeCode.cloudPreferred,
      ]);
      expect(localOnly.devices, isEmpty);
      expect(localOnly.codes, [AiroDeviceMergeCode.localOnlyCloudHidden]);
    });

    test('suppresses revoked, reset, untrusted, and incompatible devices', () {
      final revoked = AiroDeviceMergePolicy().merge(
        now: now,
        cloud: [
          _cloud(
            now,
            record: _record(
              now,
              state: AiroDeviceRegistrationState.revoked,
              revokedAt: now,
            ),
          ),
        ],
      );
      final reset = AiroDeviceMergePolicy().merge(
        now: now,
        cloud: [
          _cloud(
            now,
            record: _record(
              now,
              state: AiroDeviceRegistrationState.resetRequired,
            ),
          ),
        ],
      );
      final untrusted = AiroDeviceMergePolicy().merge(
        now: now,
        local: [_local(now, trustState: AiroNodeTrustState.untrusted)],
      );
      final incompatible =
          AiroDeviceMergePolicy(
            requiredCapabilities: const {AiroNodeCapability.compactEpg},
          ).merge(
            now: now,
            local: [
              _local(now, capabilities: const {AiroNodeCapability.playback}),
            ],
          );

      expect(revoked.devices, isEmpty);
      expect(revoked.codes, [AiroDeviceMergeCode.revokedDevice]);
      expect(reset.devices, isEmpty);
      expect(reset.codes, [AiroDeviceMergeCode.resetRequired]);
      expect(untrusted.devices, isEmpty);
      expect(untrusted.codes, [AiroDeviceMergeCode.untrustedAdvertisement]);
      expect(incompatible.devices, isEmpty);
      expect(incompatible.codes, [
        AiroDeviceMergeCode.incompatibleAdvertisement,
      ]);
    });

    test(
      'surfaces stale, expired, update-required, and unavailable states',
      () {
        final stalePresence = AiroDeviceMergePolicy().merge(
          now: now,
          cloud: [
            _cloud(
              now,
              presence: _presence(
                now,
                expiresAt: now.subtract(const Duration(seconds: 1)),
              ),
            ),
          ],
        );
        final expiredLocal = AiroDeviceMergePolicy().merge(
          now: now,
          local: [
            _local(now, expiresAt: now.subtract(const Duration(seconds: 1))),
          ],
        );
        final updateRequired = AiroDeviceMergePolicy().merge(
          now: now,
          local: [
            _local(now, lifecycle: AiroNodeLifecycleState.updateRequired),
          ],
        );
        final sleeping = AiroDeviceMergePolicy().merge(
          now: now,
          local: [_local(now, lifecycle: AiroNodeLifecycleState.sleeping)],
        );

        expect(
          stalePresence.devices.single.reachability,
          AiroDeviceReachability.unavailable,
        );
        expect(stalePresence.codes, [
          AiroDeviceMergeCode.stalePresence,
          AiroDeviceMergeCode.cloudPreferred,
        ]);
        expect(
          expiredLocal.devices.single.reachability,
          AiroDeviceReachability.unavailable,
        );
        expect(expiredLocal.codes, [
          AiroDeviceMergeCode.expiredAdvertisement,
          AiroDeviceMergeCode.localPreferred,
        ]);
        expect(updateRequired.codes, [
          AiroDeviceMergeCode.updateRequired,
          AiroDeviceMergeCode.localPreferred,
        ]);
        expect(sleeping.codes, [
          AiroDeviceMergeCode.lifecycleUnavailable,
          AiroDeviceMergeCode.localPreferred,
        ]);
      },
    );

    test(
      'public summaries do not expose host, media, or credential details',
      () {
        final result = AiroDeviceMergePolicy().merge(
          now: now,
          local: [_local(now)],
          cloud: [_cloud(now)],
        );
        final rendered = result.devices.single.toPublicMap().toString();

        expect(rendered, contains('device-tv-1'));
        expect(rendered, contains('node-tv-1'));
        expect(rendered, isNot(contains('192.168')));
        expect(rendered, isNot(contains('playlist')));
        expect(rendered, isNot(contains('mediaUrl')));
        expect(rendered, isNot(contains('credential')));
        expect(result.devices.single.toString(), isNot(contains('192.168')));
      },
    );
  });

  group('AiroDeviceMergeSource implementations', () {
    test('fake source returns fixed local and cloud observations', () async {
      final source = AiroFakeDeviceMergeSource(
        local: [_local(now)],
        cloud: [_cloud(now)],
      );

      expect(await source.localDevices(now: now), hasLength(1));
      expect(await source.cloudDevices(now: now), hasLength(1));
    });

    test('no-op source has no provider side effects', () async {
      const source = AiroNoOpDeviceMergeSource();

      expect(await source.localDevices(now: now), isEmpty);
      expect(await source.cloudDevices(now: now), isEmpty);
    });
  });
}

AiroLocalDeviceObservation _local(
  DateTime now, {
  AiroNodeTrustState trustState = AiroNodeTrustState.trusted,
  AiroNodeLifecycleState lifecycle = AiroNodeLifecycleState.available,
  Set<AiroNodeCapability> capabilities = const {
    AiroNodeCapability.playback,
    AiroNodeCapability.remoteControl,
  },
  DateTime? expiresAt,
}) {
  return AiroLocalDeviceObservation(
    advertisement: AiroNodeCapabilityAdvertisement(
      identity: _identity(),
      lifecycle: lifecycle,
      trustState: trustState,
      capabilities: capabilities,
      issuedAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(seconds: 30)),
    ),
    observedAt: now,
  );
}

AiroCloudDeviceObservation _cloud(
  DateTime now, {
  AiroRegisteredDeviceRecord? record,
  AiroPresenceLease? presence,
}) {
  return AiroCloudDeviceObservation(
    record: record ?? _record(now),
    presence: presence ?? _presence(now),
  );
}

AiroRegisteredDeviceRecord _record(
  DateTime now, {
  AiroDeviceRegistrationState state = AiroDeviceRegistrationState.active,
  DateTime? revokedAt,
}) {
  return AiroRegisteredDeviceRecord(
    registrationId: AiroDeviceStableValue.stable('registration-1'),
    accountId: AiroDeviceStableValue.stable('account-1'),
    deviceId: AiroDeviceStableValue.stable('device-tv-1'),
    nodeIdentity: _identity(),
    trustLevel: AiroTrustedDeviceTrustLevel.trusted,
    scopes: const {AiroPairingScope.playbackControl},
    state: state,
    registeredAt: now,
    lastSeenAt: now,
    revokedAt: revokedAt,
  );
}

AiroPresenceLease _presence(DateTime now, {DateTime? expiresAt}) {
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
    sequence: 1,
    issuedAt: now,
    lastHeartbeatAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 2)),
    heartbeatInterval: const Duration(seconds: 30),
  );
}

AiroNodeIdentity _identity() {
  return const AiroNodeIdentity(
    nodeId: 'node-tv-1',
    role: AiroNodeRole.tvReceiver,
    productProfile: AiroNodeProductProfile.liteReceiver,
    platformCategory: AiroNodePlatformCategory.androidTv,
  );
}
