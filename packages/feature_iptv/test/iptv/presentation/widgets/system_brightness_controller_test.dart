import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/player_brightness_controller.dart';

void main() {
  group('FakePlayerBrightnessController', () {
    test('starts at the configured initial brightness', () async {
      final controller = FakePlayerBrightnessController(initial: 0.7);
      expect(await controller.currentBrightness(), 0.7);
    });

    test('setBrightness updates the current value', () async {
      final controller = FakePlayerBrightnessController(initial: 0.5);
      await controller.setBrightness(0.9);
      expect(await controller.currentBrightness(), 0.9);
      expect(controller.setBrightnessCalls, [0.9]);
    });

    test('resetBrightness restores the initial value', () async {
      final controller = FakePlayerBrightnessController(initial: 0.4);
      await controller.setBrightness(0.1);
      await controller.resetBrightness();
      expect(await controller.currentBrightness(), 0.4);
      expect(controller.resetCalls, 1);
    });
  });
}
