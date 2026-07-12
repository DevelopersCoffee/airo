import 'dart:async';

import '../models/cast_models.dart';
import 'airo_cast_controller.dart';

class UnavailableAiroCastController implements AiroCastController {
  final _discoveryController =
      StreamController<AiroCastDiscoveryState>.broadcast();
  final _sessionController =
      StreamController<AiroCastSessionSnapshot>.broadcast();

  AiroCastDiscoveryState _discoveryState = const AiroCastDiscoveryState.idle();
  AiroCastSessionSnapshot _sessionState = const AiroCastSessionSnapshot.idle();

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
    _setSession(
      const AiroCastSessionSnapshot.failed(
        AiroCastError(
          code: AiroCastErrorCode.platformUnavailable,
          message: 'Cast is unavailable until the app provides a controller.',
        ),
      ),
    );
  }

  @override
  Future<void> startDiscovery() async {
    _setDiscovery(
      AiroCastDiscoveryState.failed(
        'Cast discovery is unavailable until the app provides a controller.',
      ),
    );
  }

  @override
  Future<void> stopDiscovery() async {
    _setDiscovery(const AiroCastDiscoveryState.idle());
  }

  @override
  Future<void> connect(AiroCastDevice device) async {
    _setSession(currentSessionState);
  }

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    _setSession(currentSessionState);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    _setSession(const AiroCastSessionSnapshot.stopped());
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> disconnect() async {
    _setSession(const AiroCastSessionSnapshot.idle());
  }

  @override
  Future<void> dispose() async {
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
