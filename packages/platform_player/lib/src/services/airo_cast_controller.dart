import 'dart:async';

import '../models/cast_models.dart';

abstract interface class AiroCastController {
  Stream<AiroCastDiscoveryState> get discoveryStateStream;
  Stream<AiroCastSessionSnapshot> get sessionStateStream;

  AiroCastDiscoveryState get currentDiscoveryState;
  AiroCastSessionSnapshot get currentSessionState;

  Future<void> initialize();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(AiroCastDevice device);
  Future<void> load(AiroCastMediaRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> disconnect();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class UnavailableAiroCastController implements AiroCastController {
  final _discoveryController =
      StreamController<AiroCastDiscoveryState>.broadcast();
  final _sessionController =
      StreamController<AiroCastSessionSnapshot>.broadcast();

  AiroCastDiscoveryState _discoveryState = AiroCastDiscoveryState.failed(
    'Cast is unavailable in this build.',
  );
  AiroCastSessionSnapshot _sessionState = const AiroCastSessionSnapshot.failed(
    AiroCastError(
      code: AiroCastErrorCode.platformUnavailable,
      message: 'Cast is unavailable in this build.',
    ),
  );

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
  Future<void> initialize() async => _emitUnavailable();

  @override
  Future<void> startDiscovery() async => _emitUnavailable();

  @override
  Future<void> stopDiscovery() async {
    _discoveryState = const AiroCastDiscoveryState.idle();
    _discoveryController.add(_discoveryState);
  }

  @override
  Future<void> connect(AiroCastDevice device) async => _emitUnavailable();

  @override
  Future<void> load(AiroCastMediaRequest request) async => _emitUnavailable();

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> disconnect() async {
    _sessionState = const AiroCastSessionSnapshot.idle();
    _sessionController.add(_sessionState);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _discoveryController.close();
    await _sessionController.close();
  }

  void _emitUnavailable() {
    const error = AiroCastError(
      code: AiroCastErrorCode.platformUnavailable,
      message: 'Cast is unavailable in this build.',
    );
    _discoveryState = AiroCastDiscoveryState.failed(error.message);
    _sessionState = const AiroCastSessionSnapshot.failed(error);
    _discoveryController.add(_discoveryState);
    _sessionController.add(_sessionState);
  }
}

class FakeAiroCastController implements AiroCastController {
  FakeAiroCastController({
    this.devices = const [],
    this.failConnection = false,
  });

  final List<AiroCastDevice> devices;
  final bool failConnection;
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
    _discoveryState = devices.isEmpty
        ? const AiroCastDiscoveryState.noDevices()
        : AiroCastDiscoveryState.found(devices);
    _discoveryController.add(_discoveryState);
  }

  @override
  Future<void> stopDiscovery() async {
    recordedActions.add('stopDiscovery');
    _discoveryState = const AiroCastDiscoveryState.idle();
    _discoveryController.add(_discoveryState);
  }

  @override
  Future<void> connect(AiroCastDevice device) async {
    recordedActions.add('connect:${device.id}');
    if (failConnection) {
      _sessionState = const AiroCastSessionSnapshot.failed(
        AiroCastError(
          code: AiroCastErrorCode.connectionTimeout,
          message: 'Connection timed out.',
        ),
      );
    } else {
      _connectedDevice = device;
      _sessionState = AiroCastSessionSnapshot.connected(device);
    }
    _sessionController.add(_sessionState);
  }

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    recordedActions.add('load:${request.url}');
    final device = _connectedDevice;
    if (device == null) {
      _sessionState = const AiroCastSessionSnapshot.failed(
        AiroCastError(
          code: AiroCastErrorCode.receiverUnavailable,
          message: 'No active Cast receiver.',
        ),
      );
    } else {
      _sessionState = AiroCastSessionSnapshot.playing(
        device: device,
        media: request,
      );
    }
    _sessionController.add(_sessionState);
  }

  @override
  Future<void> play() async {
    recordedActions.add('play');
  }

  @override
  Future<void> pause() async {
    recordedActions.add('pause');
  }

  @override
  Future<void> stop() async {
    recordedActions.add('stop');
    _sessionState = const AiroCastSessionSnapshot.stopped();
    _sessionController.add(_sessionState);
  }

  @override
  Future<void> disconnect() async {
    recordedActions.add('disconnect');
    _connectedDevice = null;
    _sessionState = const AiroCastSessionSnapshot.idle();
    _sessionController.add(_sessionState);
  }

  @override
  Future<void> setVolume(double volume) async {
    recordedActions.add('volume:$volume');
  }

  @override
  Future<void> dispose() async {
    await _discoveryController.close();
    await _sessionController.close();
  }
}
