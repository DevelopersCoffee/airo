import 'dart:async';

/// Types of audio focus that can be requested
enum AudioFocusType {
  /// Background music playback (lowest priority)
  music,

  /// Game sound effects
  sfx,

  /// AI/TTS voice output
  voiceOutput,

  /// User voice input (recording)
  voiceInput,

  /// Video playback (IPTV)
  video,

  /// Important alerts/notifications (highest priority)
  alert,
}

/// Priority levels for audio focus
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

  /// Whether this focus type should duck music (vs pause)
  bool get shouldDuckMusic {
    switch (this) {
      case AudioFocusType.sfx:
      case AudioFocusType.voiceOutput:
        return true;
      case AudioFocusType.video:
      case AudioFocusType.voiceInput:
      case AudioFocusType.alert:
        return false;
      case AudioFocusType.music:
        return false;
    }
  }

  /// Whether this focus type should pause music
  bool get shouldPauseMusic {
    switch (this) {
      case AudioFocusType.video:
      case AudioFocusType.voiceInput:
      case AudioFocusType.alert:
        return true;
      case AudioFocusType.music:
      case AudioFocusType.sfx:
      case AudioFocusType.voiceOutput:
        return false;
    }
  }
}

/// Audio context change event
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

  @override
  String toString() =>
      'AudioContextChange(focus: $currentFocus, ducked: $isDucked, paused: $isPaused, volume: $volumeMultiplier)';
}

/// Manages audio context across the app
/// Handles focus requests, ducking, and cross-feature coordination
class AudioContextManager {
  static final AudioContextManager _instance = AudioContextManager._internal();

  factory AudioContextManager() => _instance;

  AudioContextManager._internal();

  // Current state
  final Set<AudioFocusType> _activeFocuses = {};
  bool _isDucked = false;
  bool _isPausedByContext = false;
  double _duckingLevel = 0.3; // Default ducking volume
  bool _duckingEnabled = true;

  // Stream controller for context changes
  final _contextController = StreamController<AudioContextChange>.broadcast();

  /// Stream of audio context changes
  Stream<AudioContextChange> get contextChanges => _contextController.stream;

  /// Current highest priority focus
  AudioFocusType? get currentFocus {
    if (_activeFocuses.isEmpty) return null;
    return _activeFocuses.reduce((a, b) => a.priority > b.priority ? a : b);
  }

  /// Whether music is currently ducked
  bool get isDucked => _isDucked;

  /// Whether music is paused by context
  bool get isPausedByContext => _isPausedByContext;

  /// Current volume multiplier (1.0 = normal, 0.3 = ducked)
  double get volumeMultiplier => _isDucked ? _duckingLevel : 1.0;

  /// Current ducking level setting
  double get duckingLevel => _duckingLevel;

  /// Whether ducking is enabled
  bool get duckingEnabled => _duckingEnabled;

  /// Request audio focus
  /// Returns true if focus was granted
  bool requestFocus(AudioFocusType type) {
    final previousFocus = currentFocus;
    _activeFocuses.add(type);

    _updateAudioState(previousFocus);
    return true;
  }

  /// Release audio focus
  void releaseFocus(AudioFocusType type) {
    final previousFocus = currentFocus;
    _activeFocuses.remove(type);

    _updateAudioState(previousFocus);
  }

  /// Update audio state based on active focuses
  void _updateAudioState(AudioFocusType? previousFocus) {
    final newFocus = currentFocus;
    bool shouldDuck = false;
    bool shouldPause = false;

    // Check all active focuses for ducking/pause requirements
    for (final focus in _activeFocuses) {
      if (focus != AudioFocusType.music) {
        if (focus.shouldPauseMusic) {
          shouldPause = true;
          break; // Pause takes precedence
        }
        if (focus.shouldDuckMusic && _duckingEnabled) {
          shouldDuck = true;
        }
      }
    }

    // Update state
    final wasducked = _isDucked;
    final wasPaused = _isPausedByContext;

    _isDucked = shouldDuck && !shouldPause;
    _isPausedByContext = shouldPause;

    // Emit change if state changed
    if (wasducked != _isDucked ||
        wasPaused != _isPausedByContext ||
        previousFocus != newFocus) {
      _contextController.add(
        AudioContextChange(
          previousFocus: previousFocus,
          currentFocus: newFocus,
          isDucked: _isDucked,
          isPaused: _isPausedByContext,
          volumeMultiplier: volumeMultiplier,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Set ducking enabled/disabled
  void setDuckingEnabled(bool enabled) {
    if (_duckingEnabled == enabled) return;
    _duckingEnabled = enabled;

    // Re-evaluate state
    _updateAudioState(currentFocus);
  }

  /// Set ducking level (0.0 - 1.0)
  void setDuckingLevel(double level) {
    _duckingLevel = level.clamp(0.1, 0.5);

    // Emit change if currently ducked
    if (_isDucked) {
      _contextController.add(
        AudioContextChange(
          currentFocus: currentFocus,
          isDucked: _isDucked,
          isPaused: _isPausedByContext,
          volumeMultiplier: volumeMultiplier,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Request temporary ducking for a duration
  Future<void> duckForDuration(Duration duration) async {
    if (!_duckingEnabled) return;

    final wasDucked = _isDucked;
    _isDucked = true;

    _contextController.add(
      AudioContextChange(
        currentFocus: currentFocus,
        isDucked: true,
        isPaused: _isPausedByContext,
        volumeMultiplier: _duckingLevel,
        timestamp: DateTime.now(),
      ),
    );

    await Future.delayed(duration);

    // Only unduck if no other focus is requesting ducking
    if (!_activeFocuses.any(
      (f) => f.shouldDuckMusic && f != AudioFocusType.music,
    )) {
      _isDucked = wasDucked;
      _contextController.add(
        AudioContextChange(
          currentFocus: currentFocus,
          isDucked: _isDucked,
          isPaused: _isPausedByContext,
          volumeMultiplier: volumeMultiplier,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Check if a specific focus type is active
  bool hasFocus(AudioFocusType type) => _activeFocuses.contains(type);

  /// Get all active focus types
  Set<AudioFocusType> get activeFocuses => Set.unmodifiable(_activeFocuses);

  /// Clear all focuses (reset)
  void clearAllFocuses() {
    final previousFocus = currentFocus;
    _activeFocuses.clear();
    _isDucked = false;
    _isPausedByContext = false;

    _contextController.add(
      AudioContextChange(
        previousFocus: previousFocus,
        currentFocus: null,
        isDucked: false,
        isPaused: false,
        volumeMultiplier: 1.0,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _contextController.close();
  }
}
