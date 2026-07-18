import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/player_gesture_overlay.dart';

void main() {
  group('playerGestureValueDelta', () {
    test('dragging up (negative dy) increases the value', () {
      expect(playerGestureValueDelta(dy: -100, viewportHeight: 400), 0.25);
    });

    test('dragging down (positive dy) decreases the value', () {
      expect(playerGestureValueDelta(dy: 100, viewportHeight: 400), -0.25);
    });

    test('a full-height drag maps to a 100% change', () {
      expect(playerGestureValueDelta(dy: -400, viewportHeight: 400), 1.0);
    });

    test('zero movement produces zero change', () {
      expect(playerGestureValueDelta(dy: 0, viewportHeight: 400), 0.0);
    });

    test('a non-positive viewport height never divides by zero', () {
      expect(playerGestureValueDelta(dy: -50, viewportHeight: 0), 0.0);
      expect(playerGestureValueDelta(dy: -50, viewportHeight: -10), 0.0);
    });
  });

  group('clampPlayerGestureValue', () {
    test('clamps below zero up to zero', () {
      expect(clampPlayerGestureValue(-0.3), 0.0);
    });

    test('clamps above one down to one', () {
      expect(clampPlayerGestureValue(1.4), 1.0);
    });

    test('leaves in-range values untouched', () {
      expect(clampPlayerGestureValue(0.42), 0.42);
    });
  });

  group('PlayerGestureZone.forDx', () {
    test('the left half of the viewport is the brightness zone', () {
      expect(
        PlayerGestureZone.forDx(dx: 50, viewportWidth: 300),
        PlayerGestureZone.brightness,
      );
    });

    test('the right half of the viewport is the volume zone', () {
      expect(
        PlayerGestureZone.forDx(dx: 250, viewportWidth: 300),
        PlayerGestureZone.volume,
      );
    });

    test('the exact midpoint counts as the volume (right) zone', () {
      expect(
        PlayerGestureZone.forDx(dx: 150, viewportWidth: 300),
        PlayerGestureZone.volume,
      );
    });
  });
}
