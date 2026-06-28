import 'package:airo_app/core/cast/cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAiroCastController', () {
    const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
    final media = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/live.m3u8'),
      contentType: 'application/x-mpegURL',
      title: 'P4U Music',
      streamKind: AiroCastMediaStreamKind.live,
    );

    test('discovers configured fake devices', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.initialize();
      await controller.startDiscovery();

      expect(
        controller.currentDiscoveryState,
        AiroCastDiscoveryState.found(const [tv]),
      );
    });

    test('loads media after connecting to a device', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.initialize();
      await controller.connect(tv);
      await controller.load(media);

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.playing,
      );
      expect(controller.currentSessionState.device, tv);
      expect(controller.currentSessionState.media, media);
      expect(controller.recordedActions, [
        'initialize',
        'connect:tv-1',
        'load:https://example.com/live.m3u8',
      ]);
    });

    test('new connection replaces active session', () async {
      const bedroom = AiroCastDevice(id: 'tv-2', name: 'Bedroom TV');
      final controller = FakeAiroCastController(devices: const [tv, bedroom]);

      await controller.connect(tv);
      await controller.load(media);
      await controller.connect(bedroom);

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.connected,
      );
      expect(controller.currentSessionState.device, bedroom);
      expect(controller.recordedActions, contains('disconnect:tv-1'));
    });

    test('can emit receiver disconnected failure path', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.connect(tv);
      controller.emitReceiverDisconnected();

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.disconnected,
      );
      expect(controller.currentSessionState.device, tv);
    });
  });
}
