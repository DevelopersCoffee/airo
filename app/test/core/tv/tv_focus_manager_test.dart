import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/tv/tv_focus_manager.dart';

void main() {
  group('FocusMemoryEntry', () {
    test('should create with required screenId', () {
      final entry = FocusMemoryEntry(screenId: 'test_screen');
      expect(entry.screenId, equals('test_screen'));
      expect(entry.itemId, isNull);
      expect(entry.index, isNull);
      expect(entry.timestamp, isNotNull);
    });

    test('should create with optional fields', () {
      final entry = FocusMemoryEntry(
        screenId: 'test_screen',
        itemId: 'item_123',
        index: 5,
      );
      expect(entry.screenId, equals('test_screen'));
      expect(entry.itemId, equals('item_123'));
      expect(entry.index, equals(5));
    });

    test('should use provided timestamp', () {
      final customTime = DateTime(2024, 1, 1, 12, 0);
      final entry = FocusMemoryEntry(screenId: 'test', timestamp: customTime);
      expect(entry.timestamp, equals(customTime));
    });
  });

  group('TvFocusManager', () {
    late TvFocusManager manager;

    setUp(() {
      manager = TvFocusManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('should start with null current section', () {
      expect(manager.currentSectionId, isNull);
    });

    test('should start with null current item', () {
      expect(manager.currentItemId, isNull);
    });

    test('should register and unregister sections', () {
      final focusNode = FocusNode();
      manager.registerSection('section1', focusNode);
      manager.unregisterSection('section1');
      focusNode.dispose();
    });

    test('should save and retrieve focus state', () {
      manager.saveFocusState(screenId: 'screen1', itemId: 'item_abc', index: 3);

      final state = manager.getFocusState('screen1');
      expect(state, isNotNull);
      expect(state!.screenId, equals('screen1'));
      expect(state.itemId, equals('item_abc'));
      expect(state.index, equals(3));
    });

    test('should return null for unknown screen', () {
      final state = manager.getFocusState('unknown_screen');
      expect(state, isNull);
    });

    test('should clear focus state', () {
      manager.saveFocusState(screenId: 'screen1', itemId: 'item1');
      expect(manager.getFocusState('screen1'), isNotNull);

      manager.clearFocusState('screen1');
      expect(manager.getFocusState('screen1'), isNull);
    });

    test('should update focus and notify listeners', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.updateFocus(sectionId: 'section1', itemId: 'item1');

      expect(manager.currentSectionId, equals('section1'));
      expect(manager.currentItemId, equals('item1'));
      expect(notifyCount, equals(1));
    });

    test('should not notify when focus unchanged', () {
      manager.updateFocus(sectionId: 'section1', itemId: 'item1');

      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      // Same values - should not notify
      manager.updateFocus(sectionId: 'section1', itemId: 'item1');
      expect(notifyCount, equals(0));
    });

    test('should overwrite existing focus state', () {
      manager.saveFocusState(screenId: 'screen1', itemId: 'old_item');
      manager.saveFocusState(screenId: 'screen1', itemId: 'new_item');

      final state = manager.getFocusState('screen1');
      expect(state!.itemId, equals('new_item'));
    });
  });

  group('TvFocusConstants', () {
    test('should have correct focus border width', () {
      expect(TvFocusConstants.focusBorderWidth, equals(3.0));
    });

    test('should have correct focus border radius', () {
      expect(TvFocusConstants.focusBorderRadius, equals(8.0));
    });

    test('should have correct animation duration', () {
      expect(
        TvFocusConstants.focusAnimationDuration,
        equals(const Duration(milliseconds: 200)),
      );
    });

    test('should have correct focus scale factor', () {
      expect(TvFocusConstants.focusScaleFactor, equals(1.05));
    });

    test('should have correct glow spread', () {
      expect(TvFocusConstants.focusGlowSpread, equals(4.0));
    });
  });

  group('TvFocusWrapConfig', () {
    test('should create with default values (horizontal wrap only)', () {
      const config = TvFocusWrapConfig();
      expect(config.wrapHorizontal, isTrue);
      expect(config.wrapVertical, isFalse);
    });

    test('defaultTv config should wrap horizontally only', () {
      expect(TvFocusWrapConfig.defaultTv.wrapHorizontal, isTrue);
      expect(TvFocusWrapConfig.defaultTv.wrapVertical, isFalse);
    });

    test('fullWrap config should wrap in all directions', () {
      expect(TvFocusWrapConfig.fullWrap.wrapHorizontal, isTrue);
      expect(TvFocusWrapConfig.fullWrap.wrapVertical, isTrue);
    });

    test('noWrap config should not wrap in any direction', () {
      expect(TvFocusWrapConfig.noWrap.wrapHorizontal, isFalse);
      expect(TvFocusWrapConfig.noWrap.wrapVertical, isFalse);
    });

    test('should allow custom configuration', () {
      const config = TvFocusWrapConfig(
        wrapHorizontal: false,
        wrapVertical: true,
      );
      expect(config.wrapHorizontal, isFalse);
      expect(config.wrapVertical, isTrue);
    });
  });

  group('TvNavigationHints', () {
    test('should have select hint', () {
      expect(TvNavigationHints.selectHint, equals('Press OK to select'));
    });

    test('should have navigation hint', () {
      expect(
        TvNavigationHints.navigationHint,
        equals('Use arrows to navigate'),
      );
    });

    test('should have combined hint', () {
      expect(
        TvNavigationHints.combinedHint,
        equals('Press OK to select • ← → ↑ ↓ to navigate'),
      );
    });

    test('should have back hint', () {
      expect(TvNavigationHints.backHint, equals('Press Back to return'));
    });

    test('should have media hint', () {
      expect(
        TvNavigationHints.mediaHint,
        equals('Press Play/Pause to control playback'),
      );
    });

    test('should have voice search hint for Fire TV', () {
      expect(
        TvNavigationHints.voiceSearchHint,
        equals('Press mic button for voice search'),
      );
    });
  });

  // Edge case tests for focus behavior
  group('Focus edge cases', () {
    late TvFocusManager manager;

    setUp(() {
      manager = TvFocusManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('should handle multiple rapid focus updates', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      // Simulate rapid focus changes
      for (int i = 0; i < 100; i++) {
        manager.updateFocus(sectionId: 'section_$i', itemId: 'item_$i');
      }

      expect(manager.currentSectionId, equals('section_99'));
      expect(manager.currentItemId, equals('item_99'));
      expect(notifyCount, equals(100));
    });

    test('should handle focus restoration after clearing', () {
      // Save focus state
      manager.saveFocusState(
        screenId: 'channel_grid',
        itemId: 'channel_42',
        index: 42,
      );

      // Clear and verify
      manager.clearFocusState('channel_grid');
      expect(manager.getFocusState('channel_grid'), isNull);

      // Save again
      manager.saveFocusState(
        screenId: 'channel_grid',
        itemId: 'channel_0',
        index: 0,
      );

      final state = manager.getFocusState('channel_grid');
      expect(state, isNotNull);
      expect(state!.index, equals(0));
    });

    test('should handle empty section registration', () {
      // Should not throw
      final focusNode = FocusNode();
      manager.registerSection('', focusNode);
      manager.unregisterSection('');
      focusNode.dispose();
    });

    test('should handle null update values correctly', () {
      manager.updateFocus(sectionId: 'section1', itemId: 'item1');

      // Update with null sectionId - should keep current
      manager.updateFocus(itemId: 'item2');
      expect(manager.currentSectionId, equals('section1'));
      expect(manager.currentItemId, equals('item2'));

      // Update with null itemId - should keep current
      manager.updateFocus(sectionId: 'section2');
      expect(manager.currentSectionId, equals('section2'));
      expect(manager.currentItemId, equals('item2'));
    });
  });
}
