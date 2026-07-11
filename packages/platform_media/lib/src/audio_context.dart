import 'dart:async';

enum AudioFocusType { music, sfx, voiceOutput, voiceInput, video, alert }

extension AudioFocusPriority on AudioFocusType {
  int get priority {
    switch (this) {
      case AudioFocusType.music:
        return 0;
      case AudioFocusType.sfx:
        return 1;
      case AudioFocusType.voiceOutput:
        return 2;
      case AudioFocusType.video:
        return 3;
      case AudioFocusType.voiceInput:
        return 4;
      case AudioFocusType.alert:
        return 5;
    }
  }

  bool get shouldDuckMusic =>
      this == AudioFocusType.sfx || this == AudioFocusType.voiceOutput;

  bool get shouldPauseMusic =>
      this == AudioFocusType.video ||
      this == AudioFocusType.voiceInput ||
      this == AudioFocusType.alert;
}

class AudioContextChange {
  final AudioFocusType? previousFocus;
  final AudioFocusType? currentFocus;
  final bool isDucked;
  final bool isPaused;
  final double volumeMultiplier;
  final DateTime timestamp;

  const AudioContextChange({
    this.previousFocus,
    this.currentFocus,
    required this.isDucked,
    required this.isPaused,
    required this.volumeMultiplier,
    required this.timestamp,
  });
}

class AudioContextManager {
  final Set<AudioFocusType> _activeFocuses = {};
  final _contextController = StreamController<AudioContextChange>.broadcast();

  Stream<AudioContextChange> get contextChanges => _contextController.stream;

  AudioFocusType? get currentFocus {
    if (_activeFocuses.isEmpty) return null;
    return _activeFocuses.reduce((a, b) => a.priority > b.priority ? a : b);
  }

  bool requestFocus(AudioFocusType type) {
    final previousFocus = currentFocus;
    _activeFocuses.add(type);
    _emit(previousFocus);
    return true;
  }

  void releaseFocus(AudioFocusType type) {
    final previousFocus = currentFocus;
    _activeFocuses.remove(type);
    _emit(previousFocus);
  }

  void _emit(AudioFocusType? previousFocus) {
    final shouldPause = _activeFocuses.any((focus) => focus.shouldPauseMusic);
    final shouldDuck =
        !shouldPause && _activeFocuses.any((focus) => focus.shouldDuckMusic);
    _contextController.add(
      AudioContextChange(
        previousFocus: previousFocus,
        currentFocus: currentFocus,
        isDucked: shouldDuck,
        isPaused: shouldPause,
        volumeMultiplier: shouldDuck ? 0.3 : 1.0,
        timestamp: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _contextController.close();
  }
}

class AppLogger {
  static void info(String message, {String? tag}) {
    // ignore: avoid_print
    print(tag == null ? message : '[$tag] $message');
  }

  static void analytics(String event, {Map<String, dynamic>? params}) {}
}
