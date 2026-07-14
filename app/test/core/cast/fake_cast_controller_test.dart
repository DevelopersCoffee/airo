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

    test(
      'reports permission required when discovery permission is denied',
      () async {
        final controller = FakeAiroCastController(
          devices: const [tv],
          denyPermission: true,
        );

        await controller.startDiscovery();

        expect(
          controller.currentDiscoveryState.phase,
          AiroCastDiscoveryPhase.permissionRequired,
        );
        expect(controller.currentDiscoveryState.devices, isEmpty);
      },
    );

    test('reports failed discovery when configured to fail', () async {
      final controller = FakeAiroCastController(
        devices: const [tv],
        failDiscovery: true,
      );

      await controller.startDiscovery();

      expect(
        controller.currentDiscoveryState,
        AiroCastDiscoveryState.failed('Cast discovery failed'),
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

    test(
      'failed replacement connection clears previous active device',
      () async {
        const bedroom = AiroCastDevice(id: 'tv-2', name: 'Bedroom TV');
        final controller = FakeAiroCastController(devices: const [tv, bedroom]);

        await controller.connect(tv);
        await controller.load(media);
        controller.failConnection = true;
        await controller.connect(bedroom);
        await controller.load(media);

        expect(
          controller.currentSessionState.phase,
          AiroCastSessionPhase.failed,
        );
        expect(
          controller.currentSessionState.error,
          const AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'Choose a Cast device before loading media.',
          ),
        );
        expect(
          controller.recordedActions
              .where((action) => action == 'load:https://example.com/live.m3u8')
              .length,
          1,
        );
      },
    );

    test('reports failed connection when configured to fail', () async {
      final controller = FakeAiroCastController(
        devices: const [tv],
        failConnection: true,
      );

      await controller.connect(tv);

      expect(controller.currentSessionState.phase, AiroCastSessionPhase.failed);
      expect(
        controller.currentSessionState.error,
        const AiroCastError(
          code: AiroCastErrorCode.connectionTimeout,
          message: 'Unable to connect to Cast receiver.',
        ),
      );
    });

    test('reports failed media load when configured to fail', () async {
      final controller = FakeAiroCastController(
        devices: const [tv],
        failMediaLoad: true,
      );

      await controller.connect(tv);
      await controller.load(media);

      expect(controller.currentSessionState.phase, AiroCastSessionPhase.failed);
      expect(
        controller.currentSessionState.error?.code,
        AiroCastErrorCode.mediaLoadFailed,
      );
      expect(controller.currentSessionState.device, tv);
      expect(controller.currentSessionState.media, media);
    });

    test(
      'load without a connected device reports receiver unavailable',
      () async {
        final controller = FakeAiroCastController(devices: const [tv]);

        await controller.load(media);

        expect(
          controller.currentSessionState.phase,
          AiroCastSessionPhase.failed,
        );
        expect(
          controller.currentSessionState.error,
          const AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'Choose a Cast device before loading media.',
          ),
        );
        expect(
          controller.recordedActions,
          isNot(contains('load:${media.url}')),
        );
      },
    );

    test('clamps volume while preserving playback phase', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.connect(tv);
      await controller.load(media);
      await controller.setVolume(1.5);

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.playing,
      );
      expect(controller.currentSessionState.volume, 1.0);

      await controller.pause();
      await controller.setVolume(-0.5);

      expect(controller.currentSessionState.phase, AiroCastSessionPhase.paused);
      expect(controller.currentSessionState.volume, 0.0);
    });

    test('volume changes preserve loading phase', () async {
      final controller = FakeAiroCastController(
        devices: const [tv],
        completeLoads: false,
      );

      await controller.connect(tv);
      await controller.load(media);
      await controller.setVolume(0.25);

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.loadingMedia,
      );
      expect(controller.currentSessionState.media, media);
      expect(controller.currentSessionState.volume, 0.25);
    });

    test('pause play and stop update active session state', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.connect(tv);
      await controller.load(media);
      await controller.pause();

      expect(controller.currentSessionState.phase, AiroCastSessionPhase.paused);
      expect(controller.currentSessionState.device, tv);
      expect(controller.currentSessionState.media, media);

      await controller.play();

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.playing,
      );
      expect(controller.currentSessionState.device, tv);
      expect(controller.currentSessionState.media, media);

      await controller.stop();

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.stopped,
      );
      expect(controller.currentSessionState.device, tv);
      expect(controller.currentSessionState.media, media);

      await controller.load(media);

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.playing,
      );
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
