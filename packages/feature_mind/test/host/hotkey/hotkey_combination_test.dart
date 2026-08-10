import 'package:feature_mind/src/host/hotkey/hotkey_combination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HotkeyCombination', () {
    test('quickCapture is Meta+Shift+Space', () {
      const combo = HotkeyCombination.quickCapture;
      expect(combo.modifiers, {HotkeyModifier.meta, HotkeyModifier.shift});
      expect(combo.key, 'Space');
    });

    test('equality is by modifiers and key regardless of set order', () {
      const a = HotkeyCombination(
        modifiers: {HotkeyModifier.meta, HotkeyModifier.shift},
        key: 'Space',
      );
      const b = HotkeyCombination(
        modifiers: {HotkeyModifier.shift, HotkeyModifier.meta},
        key: 'Space',
      );
      const c = HotkeyCombination(
        modifiers: {HotkeyModifier.meta},
        key: 'K',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString is stable regardless of modifier insertion order', () {
      const a = HotkeyCombination(
        modifiers: {HotkeyModifier.shift, HotkeyModifier.meta},
        key: 'Space',
      );
      const b = HotkeyCombination(
        modifiers: {HotkeyModifier.meta, HotkeyModifier.shift},
        key: 'Space',
      );
      expect(a.toString(), b.toString());
    });
  });
}
