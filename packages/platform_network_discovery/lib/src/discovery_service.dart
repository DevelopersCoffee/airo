import 'dart:async';

import 'package:equatable/equatable.dart';

import 'local_discovery_models.dart';

enum DiscoveryMechanism { mdnsDnsSd, ssdpUpnp, googleCast, airPlay }

enum DiscoveryMechanismState {
  idle,
  searching,
  available,
  blocked,
  unavailable,
  failed,
  stopped,
}

enum DiscoveryServiceState { idle, searching, active, partial, failed, stopped }

class DiscoveryRoute extends Equatable {
  DiscoveryRoute({
    required this.mechanism,
    required this.serviceReference,
    required this.discoveredAt,
    required this.expiresAt,
    Set<String> capabilities = const {},
  }) : capabilities = Set.unmodifiable(capabilities) {
    final privacy = AiroDiscoveryPrivacyFilter.standard.validate({
      'serviceReference': serviceReference,
      for (final capability in capabilities)
        'capability:$capability': capability,
    });
    if (!privacy.accepted || serviceReference.trim().isEmpty) {
      throw ArgumentError.value(
        serviceReference,
        'serviceReference',
        'must be opaque and privacy-safe',
      );
    }
  }

  final DiscoveryMechanism mechanism;
  final String serviceReference;
  final DateTime discoveredAt;
  final DateTime expiresAt;
  final Set<String> capabilities;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  @override
  List<Object?> get props => [
    mechanism,
    serviceReference,
    discoveredAt,
    expiresAt,
    capabilities,
  ];
}

class DiscoveryAdapterDevice extends Equatable {
  DiscoveryAdapterDevice({
    required this.logicalDeviceId,
    required this.displayName,
    required this.deviceType,
    required this.route,
  }) {
    final privacy = AiroDiscoveryPrivacyFilter.standard.validate({
      'logicalDeviceId': logicalDeviceId,
      'displayName': displayName,
      'deviceType': deviceType,
    });
    if (!privacy.accepted ||
        logicalDeviceId.trim().isEmpty ||
        displayName.trim().isEmpty ||
        deviceType.trim().isEmpty) {
      throw ArgumentError('Discovery device fields must be privacy-safe');
    }
  }

  final String logicalDeviceId;
  final String displayName;
  final String deviceType;
  final DiscoveryRoute route;

  @override
  List<Object?> get props => [logicalDeviceId, displayName, deviceType, route];
}

class DiscoveryAdapterSnapshot extends Equatable {
  DiscoveryAdapterSnapshot({
    required this.mechanism,
    required this.state,
    required Iterable<DiscoveryAdapterDevice> devices,
    required this.capturedAt,
    this.failureCode,
  }) : devices = List.unmodifiable(devices);

  final DiscoveryMechanism mechanism;
  final DiscoveryMechanismState state;
  final List<DiscoveryAdapterDevice> devices;
  final DateTime capturedAt;

  /// Stable, redacted code only. Adapter exception text and network details
  /// must never cross this boundary.
  final String? failureCode;

  @override
  List<Object?> get props => [
    mechanism,
    state,
    devices,
    capturedAt,
    failureCode,
  ];
}

abstract interface class DiscoveryMechanismAdapter {
  DiscoveryMechanism get mechanism;

  Stream<DiscoveryAdapterSnapshot> get snapshots;

  Future<void> start();

  Future<void> stop();
}

class DiscoveredDevice extends Equatable {
  DiscoveredDevice({
    required this.logicalDeviceId,
    required this.displayName,
    required this.deviceType,
    required Iterable<DiscoveryRoute> routes,
  }) : routes = List.unmodifiable(routes);

  final String logicalDeviceId;
  final String displayName;
  final String deviceType;
  final List<DiscoveryRoute> routes;

  bool supports(DiscoveryMechanism mechanism) =>
      routes.any((route) => route.mechanism == mechanism);

  @override
  List<Object?> get props => [logicalDeviceId, displayName, deviceType, routes];
}

class DiscoveryServiceSnapshot extends Equatable {
  DiscoveryServiceSnapshot({
    required this.state,
    required Iterable<DiscoveredDevice> devices,
    required Map<DiscoveryMechanism, DiscoveryMechanismState> mechanismStates,
    required this.capturedAt,
  }) : devices = List.unmodifiable(devices),
       mechanismStates = Map.unmodifiable(mechanismStates);

  final DiscoveryServiceState state;
  final List<DiscoveredDevice> devices;
  final Map<DiscoveryMechanism, DiscoveryMechanismState> mechanismStates;
  final DateTime capturedAt;

  @override
  List<Object?> get props => [state, devices, mechanismStates, capturedAt];
}

abstract interface class DiscoveryService {
  Stream<DiscoveryServiceSnapshot> get snapshots;

  DiscoveryServiceSnapshot snapshotAt(DateTime now);

  Future<void> start();

  Future<void> stop();
}

class UnifiedDiscoveryService implements DiscoveryService {
  UnifiedDiscoveryService({
    required Iterable<DiscoveryMechanismAdapter> adapters,
    DateTime Function()? clock,
  }) : _adapters = List.unmodifiable(adapters),
       _clock = clock ?? DateTime.now {
    final mechanisms = _adapters.map((adapter) => adapter.mechanism).toList();
    if (mechanisms.toSet().length != mechanisms.length) {
      throw ArgumentError(
        'Only one adapter per discovery mechanism is allowed',
      );
    }
  }

  final List<DiscoveryMechanismAdapter> _adapters;
  final DateTime Function() _clock;
  final StreamController<DiscoveryServiceSnapshot> _controller =
      StreamController<DiscoveryServiceSnapshot>.broadcast();
  final Map<DiscoveryMechanism, DiscoveryAdapterSnapshot> _latest = {};
  final List<StreamSubscription<DiscoveryAdapterSnapshot>> _subscriptions = [];
  bool _started = false;

  @override
  Stream<DiscoveryServiceSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    for (final adapter in _adapters) {
      _latest[adapter.mechanism] = DiscoveryAdapterSnapshot(
        mechanism: adapter.mechanism,
        state: DiscoveryMechanismState.searching,
        devices: const [],
        capturedAt: _clock().toUtc(),
      );
      _subscriptions.add(
        adapter.snapshots.listen(
          (snapshot) {
            if (!_started || snapshot.mechanism != adapter.mechanism) return;
            _latest[adapter.mechanism] = snapshot;
            _emit();
          },
          onError: (_, _) {
            _recordFailure(adapter.mechanism, 'adapter_stream_failed');
          },
        ),
      );
    }
    _emit();
    await Future.wait(_adapters.map(_startAdapter));
  }

  Future<void> _startAdapter(DiscoveryMechanismAdapter adapter) async {
    try {
      await adapter.start();
    } catch (_) {
      _recordFailure(adapter.mechanism, 'adapter_start_failed');
    }
  }

  void _recordFailure(DiscoveryMechanism mechanism, String code) {
    _latest[mechanism] = DiscoveryAdapterSnapshot(
      mechanism: mechanism,
      state: DiscoveryMechanismState.failed,
      devices: const [],
      capturedAt: _clock().toUtc(),
      failureCode: code,
    );
    _emit();
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await Future.wait(
      _adapters.map((adapter) async {
        try {
          await adapter.stop();
        } catch (_) {
          // Continue stopping all mechanisms.
        }
      }),
    );
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final mechanism in _latest.keys.toList()) {
      final prior = _latest[mechanism]!;
      _latest[mechanism] = DiscoveryAdapterSnapshot(
        mechanism: mechanism,
        state: DiscoveryMechanismState.stopped,
        devices: const [],
        capturedAt: _clock().toUtc(),
        failureCode: prior.failureCode,
      );
    }
    _emit();
  }

  @override
  DiscoveryServiceSnapshot snapshotAt(DateTime now) {
    final current = now.toUtc();
    final devicesById = <String, List<DiscoveryAdapterDevice>>{};
    for (final snapshot in _latest.values) {
      for (final device in snapshot.devices) {
        if (device.route.isExpiredAt(current)) continue;
        devicesById.putIfAbsent(device.logicalDeviceId, () => []).add(device);
      }
    }
    final devices = <DiscoveredDevice>[];
    for (final entry in devicesById.entries) {
      final candidates = entry.value
        ..sort((left, right) {
          final mechanism = left.route.mechanism.index.compareTo(
            right.route.mechanism.index,
          );
          if (mechanism != 0) return mechanism;
          return left.route.serviceReference.compareTo(
            right.route.serviceReference,
          );
        });
      final routes = candidates.map((candidate) => candidate.route).toList();
      devices.add(
        DiscoveredDevice(
          logicalDeviceId: entry.key,
          displayName: candidates.first.displayName,
          deviceType: candidates.first.deviceType,
          routes: routes,
        ),
      );
    }
    devices.sort((left, right) {
      final name = left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
      if (name != 0) return name;
      return left.logicalDeviceId.compareTo(right.logicalDeviceId);
    });
    final states = {
      for (final entry in _latest.entries) entry.key: entry.value.state,
    };
    return DiscoveryServiceSnapshot(
      state: _serviceState(states.values, devices.isNotEmpty),
      devices: devices,
      mechanismStates: states,
      capturedAt: current,
    );
  }

  DiscoveryServiceState _serviceState(
    Iterable<DiscoveryMechanismState> states,
    bool hasDevices,
  ) {
    if (!_started) {
      return _latest.isEmpty
          ? DiscoveryServiceState.idle
          : DiscoveryServiceState.stopped;
    }
    final values = states.toList();
    final hasFailure = values.any(
      (state) =>
          state == DiscoveryMechanismState.blocked ||
          state == DiscoveryMechanismState.unavailable ||
          state == DiscoveryMechanismState.failed,
    );
    if (hasDevices) {
      return hasFailure
          ? DiscoveryServiceState.partial
          : DiscoveryServiceState.active;
    }
    if (values.any((state) => state == DiscoveryMechanismState.searching)) {
      return DiscoveryServiceState.searching;
    }
    return hasFailure
        ? DiscoveryServiceState.failed
        : DiscoveryServiceState.active;
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(snapshotAt(_clock()));
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
