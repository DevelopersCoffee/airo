import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_network_discovery/platform_network_discovery.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 12);

  DiscoveryAdapterDevice device(
    DiscoveryMechanism mechanism, {
    String id = 'receiver-1',
    String name = 'Living Room TV',
    Duration ttl = const Duration(minutes: 1),
  }) {
    return DiscoveryAdapterDevice(
      logicalDeviceId: id,
      displayName: name,
      deviceType: 'receiver',
      route: DiscoveryRoute(
        mechanism: mechanism,
        serviceReference: '${mechanism.name}:opaque-$id',
        discoveredAt: now,
        expiresAt: now.add(ttl),
        capabilities: const {'playback', 'remote'},
      ),
    );
  }

  test('starts and stops every registered mechanism exactly once', () async {
    final adapters = [
      for (final mechanism in DiscoveryMechanism.values)
        _FakeAdapter(
          mechanism,
          snapshot: DiscoveryAdapterSnapshot(
            mechanism: mechanism,
            state: DiscoveryMechanismState.available,
            devices: const [],
            capturedAt: now,
          ),
        ),
    ];
    final service = UnifiedDiscoveryService(
      adapters: adapters,
      clock: () => now,
    );

    await service.start();
    await service.start();
    await service.stop();
    await service.stop();

    expect(adapters.every((adapter) => adapter.startCalls == 1), isTrue);
    expect(adapters.every((adapter) => adapter.stopCalls == 1), isTrue);
    await service.dispose();
  });

  test(
    'ignores adapter emissions after stop tears down subscriptions',
    () async {
      final adapter = _FakeAdapter(DiscoveryMechanism.mdnsDnsSd);
      final service = UnifiedDiscoveryService(
        adapters: [adapter],
        clock: () => now,
      );

      await service.start();
      await service.stop();
      adapter.emit(
        DiscoveryAdapterSnapshot(
          mechanism: DiscoveryMechanism.mdnsDnsSd,
          state: DiscoveryMechanismState.available,
          devices: [device(DiscoveryMechanism.mdnsDnsSd)],
          capturedAt: now,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.snapshotAt(now).state, DiscoveryServiceState.stopped);
      expect(service.snapshotAt(now).devices, isEmpty);
      await service.dispose();
    },
  );

  test('mDNS receiver survives blocked broadcast-style mechanism', () async {
    final mdns = _FakeAdapter(
      DiscoveryMechanism.mdnsDnsSd,
      snapshot: DiscoveryAdapterSnapshot(
        mechanism: DiscoveryMechanism.mdnsDnsSd,
        state: DiscoveryMechanismState.available,
        devices: [device(DiscoveryMechanism.mdnsDnsSd)],
        capturedAt: now,
      ),
    );
    final blocked = _FakeAdapter(
      DiscoveryMechanism.ssdpUpnp,
      snapshot: DiscoveryAdapterSnapshot(
        mechanism: DiscoveryMechanism.ssdpUpnp,
        state: DiscoveryMechanismState.blocked,
        devices: const [],
        capturedAt: now,
        failureCode: 'udp_broadcast_blocked',
      ),
    );
    final service = UnifiedDiscoveryService(
      adapters: [blocked, mdns],
      clock: () => now,
    );

    await service.start();
    await Future<void>.delayed(Duration.zero);
    final snapshot = service.snapshotAt(now);

    expect(snapshot.state, DiscoveryServiceState.partial);
    expect(snapshot.devices.single.logicalDeviceId, 'receiver-1');
    expect(
      snapshot.devices.single.supports(DiscoveryMechanism.mdnsDnsSd),
      isTrue,
    );
    expect(
      snapshot.mechanismStates[DiscoveryMechanism.ssdpUpnp],
      DiscoveryMechanismState.blocked,
    );
    await service.dispose();
  });

  test(
    'deduplicates logical receiver while retaining protocol routes',
    () async {
      final adapters = [
        _FakeAdapter(
          DiscoveryMechanism.googleCast,
          snapshot: DiscoveryAdapterSnapshot(
            mechanism: DiscoveryMechanism.googleCast,
            state: DiscoveryMechanismState.available,
            devices: [device(DiscoveryMechanism.googleCast)],
            capturedAt: now,
          ),
        ),
        _FakeAdapter(
          DiscoveryMechanism.mdnsDnsSd,
          snapshot: DiscoveryAdapterSnapshot(
            mechanism: DiscoveryMechanism.mdnsDnsSd,
            state: DiscoveryMechanismState.available,
            devices: [device(DiscoveryMechanism.mdnsDnsSd)],
            capturedAt: now,
          ),
        ),
      ];
      final service = UnifiedDiscoveryService(
        adapters: adapters,
        clock: () => now,
      );

      await service.start();
      await Future<void>.delayed(Duration.zero);
      final result = service.snapshotAt(now).devices.single;

      expect(result.routes, hasLength(2));
      expect(result.supports(DiscoveryMechanism.googleCast), isTrue);
      expect(result.supports(DiscoveryMechanism.mdnsDnsSd), isTrue);
      await service.dispose();
    },
  );

  test('expires stale routes and sorts devices deterministically', () async {
    final adapter = _FakeAdapter(
      DiscoveryMechanism.airPlay,
      snapshot: DiscoveryAdapterSnapshot(
        mechanism: DiscoveryMechanism.airPlay,
        state: DiscoveryMechanismState.available,
        devices: [
          device(DiscoveryMechanism.airPlay, id: 'z', name: 'Bedroom'),
          device(DiscoveryMechanism.airPlay, id: 'a', name: 'Bedroom'),
          device(
            DiscoveryMechanism.airPlay,
            id: 'expired',
            name: 'Attic',
            ttl: const Duration(seconds: -1),
          ),
        ],
        capturedAt: now,
      ),
    );
    final service = UnifiedDiscoveryService(
      adapters: [adapter],
      clock: () => now,
    );

    await service.start();
    await Future<void>.delayed(Duration.zero);

    expect(
      service.snapshotAt(now).devices.map((value) => value.logicalDeviceId),
      ['a', 'z'],
    );
    await service.dispose();
  });

  test('rejects raw network and credential material', () {
    expect(
      () => DiscoveryRoute(
        mechanism: DiscoveryMechanism.mdnsDnsSd,
        serviceReference: 'http://192.168.1.2:8009',
        discoveredAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      () => DiscoveryAdapterDevice(
        logicalDeviceId: 'receiver',
        displayName: 'Bearer secret-token',
        deviceType: 'receiver',
        route: device(DiscoveryMechanism.mdnsDnsSd).route,
      ),
      throwsArgumentError,
    );
  });

  test(
    'adapter start failure is redacted and does not stop fallback',
    () async {
      final failed = _FakeAdapter(
        DiscoveryMechanism.ssdpUpnp,
        throwOnStart: true,
      );
      final mdns = _FakeAdapter(
        DiscoveryMechanism.mdnsDnsSd,
        snapshot: DiscoveryAdapterSnapshot(
          mechanism: DiscoveryMechanism.mdnsDnsSd,
          state: DiscoveryMechanismState.available,
          devices: [device(DiscoveryMechanism.mdnsDnsSd)],
          capturedAt: now,
        ),
      );
      final service = UnifiedDiscoveryService(
        adapters: [failed, mdns],
        clock: () => now,
      );

      await service.start();
      await Future<void>.delayed(Duration.zero);

      expect(service.snapshotAt(now).devices, hasLength(1));
      expect(
        service.snapshotAt(now).mechanismStates[DiscoveryMechanism.ssdpUpnp],
        DiscoveryMechanismState.failed,
      );
      await service.dispose();
    },
  );
}

class _FakeAdapter implements DiscoveryMechanismAdapter {
  _FakeAdapter(this.mechanism, {this.snapshot, this.throwOnStart = false});

  @override
  final DiscoveryMechanism mechanism;
  final DiscoveryAdapterSnapshot? snapshot;
  final bool throwOnStart;
  final StreamController<DiscoveryAdapterSnapshot> _controller =
      StreamController<DiscoveryAdapterSnapshot>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<DiscoveryAdapterSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start() async {
    startCalls++;
    if (throwOnStart) throw StateError('private network details');
    final value = snapshot;
    if (value != null) _controller.add(value);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void emit(DiscoveryAdapterSnapshot value) {
    _controller.add(value);
  }
}
