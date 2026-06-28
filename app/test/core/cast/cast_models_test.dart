import 'package:airo_app/core/cast/cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroCastDevice', () {
    test('uses id equality so duplicate discovery entries collapse', () {
      const first = AiroCastDevice(
        id: 'living-room',
        name: 'Sony Bravia',
        modelName: 'BRAVIA 4K',
      );
      const duplicate = AiroCastDevice(
        id: 'living-room',
        name: 'Sony Bravia',
        modelName: 'BRAVIA 4K',
      );

      expect(first, duplicate);
      final discoveredDevices = <AiroCastDevice>{}
        ..add(first)
        ..add(duplicate);
      expect(discoveredDevices.length, 1);
    });
  });

  group('AiroCastDiscoveryState', () {
    test('found state contains devices and uses found phase', () {
      const device = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

      final state = AiroCastDiscoveryState.found([device]);

      expect(state.phase, AiroCastDiscoveryPhase.found);
      expect(state.devices, [device]);
      expect(state.error, isNull);
    });

    test('discovering state defensively copies discovered devices', () {
      const device = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
      final devices = [device];

      final state = AiroCastDiscoveryState.discovering(devices: devices);
      devices.clear();

      expect(state.phase, AiroCastDiscoveryPhase.discovering);
      expect(state.devices, [device]);
      expect(() => state.devices.add(device), throwsUnsupportedError);
    });

    test('failed state keeps a user-facing error message', () {
      final state = AiroCastDiscoveryState.failed('Local network unavailable');

      expect(state.phase, AiroCastDiscoveryPhase.failed);
      expect(state.error, 'Local network unavailable');
      expect(state.devices, isEmpty);
    });
  });

  group('AiroCastSessionSnapshot', () {
    test('playing snapshot exposes active device and media', () {
      const device = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
      final request = AiroCastMediaRequest(
        url: Uri.parse('https://example.com/live.m3u8'),
        contentType: 'application/x-mpegURL',
        title: 'P4U Music',
        streamKind: AiroCastMediaStreamKind.live,
      );

      final snapshot = AiroCastSessionSnapshot.playing(
        device: device,
        media: request,
      );

      expect(snapshot.phase, AiroCastSessionPhase.playing);
      expect(snapshot.device, device);
      expect(snapshot.media, request);
    });
  });
}
