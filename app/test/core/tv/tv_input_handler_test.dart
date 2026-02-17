import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/tv/tv_input_handler.dart';

void main() {
  group('TvInputKey', () {
    test('should have all expected navigation keys', () {
      expect(TvInputKey.values, contains(TvInputKey.up));
      expect(TvInputKey.values, contains(TvInputKey.down));
      expect(TvInputKey.values, contains(TvInputKey.left));
      expect(TvInputKey.values, contains(TvInputKey.right));
      expect(TvInputKey.values, contains(TvInputKey.select));
      expect(TvInputKey.values, contains(TvInputKey.back));
    });

    test('should have all expected media keys', () {
      expect(TvInputKey.values, contains(TvInputKey.playPause));
      expect(TvInputKey.values, contains(TvInputKey.fastForward));
      expect(TvInputKey.values, contains(TvInputKey.rewind));
      expect(TvInputKey.values, contains(TvInputKey.menu));
    });

    test('should have correct number of values', () {
      // up, down, left, right, select, back, playPause, fastForward, rewind, menu
      // + Fire TV keys: voiceSearch, channelUp, channelDown, home
      expect(TvInputKey.values.length, equals(14));
    });

    test('should have Fire TV specific keys', () {
      expect(TvInputKey.values, contains(TvInputKey.voiceSearch));
      expect(TvInputKey.values, contains(TvInputKey.channelUp));
      expect(TvInputKey.values, contains(TvInputKey.channelDown));
      expect(TvInputKey.values, contains(TvInputKey.home));
    });
  });

  group('TvInputResult', () {
    test('should have handled and notHandled values', () {
      expect(TvInputResult.values, contains(TvInputResult.handled));
      expect(TvInputResult.values, contains(TvInputResult.notHandled));
    });
  });

  group('TvInputHandler.mapLogicalKeyToTvInput', () {
    test('should map arrow keys to navigation', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.arrowUp),
        equals(TvInputKey.up),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.arrowDown),
        equals(TvInputKey.down),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.arrowLeft),
        equals(TvInputKey.left),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.arrowRight),
        equals(TvInputKey.right),
      );
    });

    test('should map select/enter to select', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.select),
        equals(TvInputKey.select),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.enter),
        equals(TvInputKey.select),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.numpadEnter),
        equals(TvInputKey.select),
      );
    });

    test('should map escape/goBack to back', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.escape),
        equals(TvInputKey.back),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.goBack),
        equals(TvInputKey.back),
      );
    });

    test('should map media keys correctly', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(
          LogicalKeyboardKey.mediaPlayPause,
        ),
        equals(TvInputKey.playPause),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(
          LogicalKeyboardKey.mediaFastForward,
        ),
        equals(TvInputKey.fastForward),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.mediaRewind),
        equals(TvInputKey.rewind),
      );
    });

    test('should return null for unmapped keys', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.keyA),
        isNull,
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.keyZ),
        isNull,
      );
    });

    test('should map space to playPause', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.space),
        equals(TvInputKey.playPause),
      );
    });
  });

  group('TvInputHandler.isTvNavigationKey', () {
    test('should return true for TV keys', () {
      expect(
        TvInputHandler.isTvNavigationKey(LogicalKeyboardKey.arrowUp),
        isTrue,
      );
      expect(
        TvInputHandler.isTvNavigationKey(LogicalKeyboardKey.select),
        isTrue,
      );
      expect(
        TvInputHandler.isTvNavigationKey(LogicalKeyboardKey.mediaPlayPause),
        isTrue,
      );
    });

    test('should return false for non-TV keys', () {
      expect(
        TvInputHandler.isTvNavigationKey(LogicalKeyboardKey.keyA),
        isFalse,
      );
      expect(
        TvInputHandler.isTvNavigationKey(LogicalKeyboardKey.keyZ),
        isFalse,
      );
    });
  });

  group('Fire TV key mappings', () {
    test('should map channel up/down keys', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.channelUp),
        equals(TvInputKey.channelUp),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.channelDown),
        equals(TvInputKey.channelDown),
      );
    });

    test('should map pageUp/pageDown to channelUp/channelDown', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.pageUp),
        equals(TvInputKey.channelUp),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.pageDown),
        equals(TvInputKey.channelDown),
      );
    });

    test('should map voice/search keys to voiceSearch', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.browserSearch),
        equals(TvInputKey.voiceSearch),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(
          LogicalKeyboardKey.launchAssistant,
        ),
        equals(TvInputKey.voiceSearch),
      );
    });

    test('should map home keys', () {
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.browserHome),
        equals(TvInputKey.home),
      );
      expect(
        TvInputHandler.mapLogicalKeyToTvInput(LogicalKeyboardKey.home),
        equals(TvInputKey.home),
      );
    });
  });

  group('TvInputKeyExtension', () {
    test('isChannelKey returns true for channel keys', () {
      expect(TvInputKey.channelUp.isChannelKey, isTrue);
      expect(TvInputKey.channelDown.isChannelKey, isTrue);
      expect(TvInputKey.up.isChannelKey, isFalse);
      expect(TvInputKey.select.isChannelKey, isFalse);
    });

    test('isFireTvKey returns true for Fire TV specific keys', () {
      expect(TvInputKey.voiceSearch.isFireTvKey, isTrue);
      expect(TvInputKey.channelUp.isFireTvKey, isTrue);
      expect(TvInputKey.channelDown.isFireTvKey, isTrue);
      expect(TvInputKey.up.isFireTvKey, isFalse);
      expect(TvInputKey.select.isFireTvKey, isFalse);
      expect(TvInputKey.playPause.isFireTvKey, isFalse);
    });

    test('isNavigationKey returns true for D-pad navigation keys', () {
      expect(TvInputKey.up.isNavigationKey, isTrue);
      expect(TvInputKey.down.isNavigationKey, isTrue);
      expect(TvInputKey.left.isNavigationKey, isTrue);
      expect(TvInputKey.right.isNavigationKey, isTrue);
      expect(TvInputKey.select.isNavigationKey, isFalse);
      expect(TvInputKey.channelUp.isNavigationKey, isFalse);
    });

    test('isMediaKey returns true for media control keys', () {
      expect(TvInputKey.playPause.isMediaKey, isTrue);
      expect(TvInputKey.fastForward.isMediaKey, isTrue);
      expect(TvInputKey.rewind.isMediaKey, isTrue);
      expect(TvInputKey.up.isMediaKey, isFalse);
      expect(TvInputKey.channelUp.isMediaKey, isFalse);
    });
  });
}
