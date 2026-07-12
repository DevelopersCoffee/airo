import 'package:flutter_test/flutter_test.dart';

import 'package:platform_player/platform_player.dart';

void main() {
  test('fake cast controller exposes discovered devices', () async {
    const tv = AiroCastDevice(id: 'tv-1', name: 'Living Room');
    final controller = FakeAiroCastController(devices: const [tv]);

    await controller.startDiscovery();

    expect(
      controller.currentDiscoveryState.phase,
      AiroCastDiscoveryPhase.found,
    );
    expect(controller.currentDiscoveryState.devices, const [tv]);
    await controller.dispose();
  });
}
