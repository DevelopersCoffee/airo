import 'dart:async';

import '../models/cast_models.dart';
import 'airo_cast_controller.dart';

class FakeAiroCastController implements AiroCastController {
  FakeAiroCastController({
    this.devices = const [],
    this.failDiscovery = false,
    this.denyPermission = false,
    this.failConnection = false,
    this.failMediaLoad = false,
    this.completeLoads = true,
  });

  final List<AiroCastDevice> devices;
  bool failDiscovery;
  bool denyPermission;
  bool failConnection;
  bool failMediaLoad;
  bool completeLoads;

  final List<String> recordedActions = [];

  final _discoveryController =
      StreamController<AiroCastDiscoveryState>.broadcast();
  final _sessionController =
      StreamController<AiroCastSessionSnapshot>.broadcast();

  AiroCastDiscoveryState _discoveryState = const AiroCastDiscoveryState.idle();
  AiroCastSessionSnapshot _sessionState = const AiroCastSessionSnapshot.idle();
  AiroCastDevice? _connectedDevice;

  @override
  Stream<AiroCastDiscoveryState> get discoveryStateStream =>
      _discoveryController.stream;

  @override
  Stream<AiroCastSessionSnapshot> get sessionStateStream =>
      _sessionController.stream;

  @override
  AiroCastDiscoveryState get currentDiscoveryState => _discoveryState;

  @override
  AiroCastSessionSnapshot get currentSessionState => _sessionState;

  @override
  Future<void> initialize() async {
    recordedActions.add('initialize');
  }

  @override
  Future<void> startDiscovery() async {
    recordedActions.add('startDiscovery');
    if (denyPermission) {
      _setDiscovery(const AiroCastDiscoveryState.permissionRequired());
      return;
    }
    _setDiscovery(AiroCastDiscoveryState.discovering());
    if (failDiscovery) {
      _setDiscovery(AiroCastDiscoveryState.failed('Cast discovery failed'));
      return;
    }
    if (devices.isEmpty) {
      _setDiscovery(const AiroCastDiscoveryState.noDevices());
      return;
    }
    _setDiscovery(AiroCastDiscoveryState.found(devices));
  }

  @override
  Future<void> stopDiscovery() async {
    recordedActions.add('stopDiscovery');
    _setDiscovery(const AiroCastDiscoveryState.idle());
  }

  @override
  Future<void> connect(AiroCastDevice device) async {
    final previousDevice = _connectedDevice;
    if (previousDevice == device && _sessionState.isConnected) {
      return;
    }
    if (previousDevice != null) {
      if (previousDevice != device) {
        recordedActions.add('disconnect:${previousDevice.id}');
      }
      _connectedDevice = null;
    }
    recordedActions.add('connect:${device.id}');
    _setSession(AiroCastSessionSnapshot.connecting(device));
    if (failConnection) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.connectionTimeout,
            message: 'Unable to connect to Cast receiver.',
          ),
        ),
      );
      return;
    }
    _connectedDevice = device;
    _setSession(AiroCastSessionSnapshot.connected(device));
  }

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    final device = _connectedDevice;
    if (device == null) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'Choose a Cast device before loading media.',
          ),
        ),
      );
      return;
    }
    recordedActions.add('load:${request.url}');
    _setSession(
      AiroCastSessionSnapshot.loadingMedia(device: device, media: request),
    );
    if (!completeLoads) {
      return;
    }
    if (failMediaLoad) {
      _setSession(
        AiroCastSessionSnapshot.failed(
          const AiroCastError(
            code: AiroCastErrorCode.mediaLoadFailed,
            message: 'The receiver could not load this channel.',
          ),
          device: device,
          media: request,
        ),
      );
      return;
    }
    _setSession(
      AiroCastSessionSnapshot.playing(device: device, media: request),
    );
  }

  @override
  Future<void> play() async {
    recordedActions.add('play');
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    if (device != null && media != null) {
      _setSession(
        AiroCastSessionSnapshot.playing(
          device: device,
          media: media,
          volume: snapshot.volume,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    recordedActions.add('pause');
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    if (device != null && media != null) {
      _setSession(
        AiroCastSessionSnapshot.paused(
          device: device,
          media: media,
          volume: snapshot.volume,
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    recordedActions.add('stop');
    final snapshot = _sessionState;
    _setSession(
      AiroCastSessionSnapshot.stopped(
        device: _connectedDevice ?? snapshot.device,
        media: snapshot.media,
        volume: snapshot.volume,
      ),
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    recordedActions.add('setVolume:$volume');
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    if (device != null && media != null) {
      _setSession(switch (snapshot.phase) {
        AiroCastSessionPhase.loadingMedia =>
          AiroCastSessionSnapshot.loadingMedia(
            device: device,
            media: media,
            volume: clampedVolume,
          ),
        AiroCastSessionPhase.paused => AiroCastSessionSnapshot.paused(
          device: device,
          media: media,
          volume: clampedVolume,
        ),
        _ => AiroCastSessionSnapshot.playing(
          device: device,
          media: media,
          volume: clampedVolume,
        ),
      });
    }
  }

  @override
  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device != null) {
      recordedActions.add('disconnect:${device.id}');
    }
    _connectedDevice = null;
    _setSession(const AiroCastSessionSnapshot.idle());
  }

  void emitReceiverDisconnected() {
    final device = _connectedDevice;
    if (device == null) return;
    _connectedDevice = null;
    _setSession(AiroCastSessionSnapshot.disconnected(device));
  }

  @override
  Future<void> dispose() async {
    recordedActions.add('dispose');
    await _discoveryController.close();
    await _sessionController.close();
  }

  void _setDiscovery(AiroCastDiscoveryState state) {
    _discoveryState = state;
    _discoveryController.add(state);
  }

  void _setSession(AiroCastSessionSnapshot state) {
    _sessionState = state;
    _sessionController.add(state);
  }
}
