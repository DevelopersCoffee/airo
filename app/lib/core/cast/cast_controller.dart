import 'cast_models.dart';

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
  Future<void> setVolume(double volume);
  Future<void> disconnect();
  Future<void> dispose();
}
