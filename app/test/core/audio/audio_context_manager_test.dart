import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/audio/audio_context_manager.dart';

void main() {
  group('AudioFocusType', () {
    test('priority values are ordered correctly', () {
      expect(AudioFocusType.music.priority, 0);
      expect(AudioFocusType.sfx.priority, 1);
      expect(AudioFocusType.voiceOutput.priority, 2);
      expect(AudioFocusType.video.priority, 3);
      expect(AudioFocusType.voiceInput.priority, 4);
      expect(AudioFocusType.alert.priority, 5);
    });

    test('shouldDuckMusic returns correct values', () {
      expect(AudioFocusType.music.shouldDuckMusic, false);
      expect(AudioFocusType.sfx.shouldDuckMusic, true);
      expect(AudioFocusType.voiceOutput.shouldDuckMusic, true);
      expect(AudioFocusType.video.shouldDuckMusic, false);
      expect(AudioFocusType.voiceInput.shouldDuckMusic, false);
      expect(AudioFocusType.alert.shouldDuckMusic, false);
    });

    test('shouldPauseMusic returns correct values', () {
      expect(AudioFocusType.music.shouldPauseMusic, false);
      expect(AudioFocusType.sfx.shouldPauseMusic, false);
      expect(AudioFocusType.voiceOutput.shouldPauseMusic, false);
      expect(AudioFocusType.video.shouldPauseMusic, true);
      expect(AudioFocusType.voiceInput.shouldPauseMusic, true);
      expect(AudioFocusType.alert.shouldPauseMusic, true);
    });
  });

  group('AudioContextChange', () {
    test('creates with required fields', () {
      final change = AudioContextChange(
        isDucked: true,
        isPaused: false,
        volumeMultiplier: 0.3,
        timestamp: DateTime.now(),
      );

      expect(change.isDucked, true);
      expect(change.isPaused, false);
      expect(change.volumeMultiplier, 0.3);
      expect(change.currentFocus, isNull);
      expect(change.previousFocus, isNull);
    });

    test('creates with all fields', () {
      final change = AudioContextChange(
        previousFocus: AudioFocusType.music,
        currentFocus: AudioFocusType.sfx,
        isDucked: true,
        isPaused: false,
        volumeMultiplier: 0.3,
        timestamp: DateTime.now(),
      );

      expect(change.previousFocus, AudioFocusType.music);
      expect(change.currentFocus, AudioFocusType.sfx);
    });

    test('toString returns readable format', () {
      final change = AudioContextChange(
        currentFocus: AudioFocusType.sfx,
        isDucked: true,
        isPaused: false,
        volumeMultiplier: 0.3,
        timestamp: DateTime.now(),
      );

      expect(change.toString(), contains('AudioContextChange'));
      expect(change.toString(), contains('sfx'));
      expect(change.toString(), contains('ducked: true'));
    });
  });

  group('AudioContextManager', () {
    late AudioContextManager manager;

    setUp(() {
      // Create a fresh instance for testing
      manager = AudioContextManager();
      manager.clearAllFocuses();
    });

    test('initial state has no focus', () {
      expect(manager.currentFocus, isNull);
      expect(manager.isDucked, false);
      expect(manager.isPausedByContext, false);
      expect(manager.volumeMultiplier, 1.0);
    });

    test('requestFocus adds focus and returns true', () {
      final result = manager.requestFocus(AudioFocusType.music);

      expect(result, true);
      expect(manager.currentFocus, AudioFocusType.music);
      expect(manager.hasFocus(AudioFocusType.music), true);
    });

    test('releaseFocus removes focus', () {
      manager.requestFocus(AudioFocusType.music);
      manager.releaseFocus(AudioFocusType.music);

      expect(manager.currentFocus, isNull);
      expect(manager.hasFocus(AudioFocusType.music), false);
    });

    test('currentFocus returns highest priority focus', () {
      manager.requestFocus(AudioFocusType.music);
      manager.requestFocus(AudioFocusType.sfx);
      manager.requestFocus(AudioFocusType.voiceOutput);

      expect(manager.currentFocus, AudioFocusType.voiceOutput);
    });

    test('sfx focus ducks music', () {
      manager.requestFocus(AudioFocusType.music);
      manager.requestFocus(AudioFocusType.sfx);

      expect(manager.isDucked, true);
      expect(manager.isPausedByContext, false);
      expect(manager.volumeMultiplier, manager.duckingLevel);
    });

    test('video focus pauses music', () {
      manager.requestFocus(AudioFocusType.music);
      manager.requestFocus(AudioFocusType.video);

      expect(manager.isDucked, false);
      expect(manager.isPausedByContext, true);
    });

    test('releasing sfx focus removes ducking', () {
      manager.requestFocus(AudioFocusType.music);
      manager.requestFocus(AudioFocusType.sfx);
      manager.releaseFocus(AudioFocusType.sfx);

      expect(manager.isDucked, false);
      expect(manager.volumeMultiplier, 1.0);
    });

    test('setDuckingEnabled disables ducking', () {
      manager.setDuckingEnabled(false);
      manager.requestFocus(AudioFocusType.music);
      manager.requestFocus(AudioFocusType.sfx);

      expect(manager.isDucked, false);
    });
  });
}

