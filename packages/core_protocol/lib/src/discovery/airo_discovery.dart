import 'dart:async';

/// Protocol / technology used for discovering local edge devices.
enum AiroDiscoveryProtocol {
  mdns,
  ble,
  sdp,
}

/// Represents a discovered edge node on the local network or BLE range.
class AiroDiscoveredDevice {
  final String deviceId;
  final String name;
  final String host;
  final int port;
  final Set<AiroDiscoveryProtocol> protocols;
  final Map<String, String> metadata;
  final DateTime discoveredAt;

  AiroDiscoveredDevice({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
    required this.protocols,
    this.metadata = const {},
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now().toUtc();

  /// Stable diagnostic representation.
  Map<String, dynamic> toDiagnosticMap() {
    return {
      'deviceId': deviceId,
      'name': name,
      'host': host,
      'port': port,
      'protocols': protocols.map((p) => p.name).toList(),
      'metadata': metadata,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }
}

/// Abstract contract for local device discovery across Wi-Fi (mDNS) and Bluetooth (BLE).
abstract class AiroDeviceDiscoveryEngine {
  /// Stream of discovered devices in real-time.
  Stream<AiroDiscoveredDevice> get discoveredDevices;

  /// Starts discovery scanning.
  Future<void> startDiscovery();

  /// Stops discovery scanning.
  Future<void> stopDiscovery();

  /// Clears discovered device state.
  void clear();
}

/// Simulated / fake discovery engine for unit tests and local development.
class AiroFakeDiscoveryEngine implements AiroDeviceDiscoveryEngine {
  final StreamController<AiroDiscoveredDevice> _controller =
      StreamController<AiroDiscoveredDevice>.broadcast();
  final List<AiroDiscoveredDevice> _discovered = [];
  bool _isScanning = false;

  bool get isScanning => _isScanning;
  List<AiroDiscoveredDevice> get discoveredList => List.unmodifiable(_discovered);

  @override
  Stream<AiroDiscoveredDevice> get discoveredDevices => _controller.stream;

  @override
  Future<void> startDiscovery() async {
    _isScanning = true;
  }

  @override
  Future<void> stopDiscovery() async {
    _isScanning = false;
  }

  /// Emits a simulated device discovery event.
  void emitDiscovered(AiroDiscoveredDevice device) {
    if (!_discovered.any((d) => d.deviceId == device.deviceId)) {
      _discovered.add(device);
    }
    _controller.add(device);
  }

  @override
  void clear() {
    _discovered.clear();
  }

  /// Closes the discovery stream.
  Future<void> close() async {
    await _controller.close();
  }
}
