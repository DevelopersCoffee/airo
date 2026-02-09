import 'dart:async';
import '../../../../core/audio/audio_context_manager.dart';
import 'beats_audio_handler.dart';

/// Integrates BeatsAudioHandler with AudioContextManager
/// Handles automatic ducking and pausing based on audio context
class BeatsContextIntegration {
  final BeatsAudioHandler _audioHandler;
  final AudioContextManager _contextManager;

  StreamSubscription<AudioContextChange>? _contextSubscription;
  bool _wasPausedByContext = false;
  double _originalVolume = 1.0;

  BeatsContextIntegration({
    required BeatsAudioHandler audioHandler,
    required AudioContextManager contextManager,
  })  : _audioHandler = audioHandler,
        _contextManager = contextManager {
    _init();
  }

  /// Initialize context listening
  void _init() {
    // Request music focus when playing
    _contextManager.requestFocus(AudioFocusType.music);

    // Listen to context changes
    _contextSubscription = _contextManager.contextChanges.listen(_onContextChange);
  }

  /// Handle audio context changes
  void _onContextChange(AudioContextChange change) {
    print('[BeatsContext] Context change: $change');

    if (change.isPaused && !_wasPausedByContext) {
      // Need to pause music
      _pauseForContext();
    } else if (!change.isPaused && _wasPausedByContext) {
      // Can resume music
      _resumeFromContext();
    } else if (change.isDucked) {
      // Apply ducking
      _applyDucking(change.volumeMultiplier);
    } else if (!change.isDucked && _originalVolume != 1.0) {
      // Remove ducking
      _removeDucking();
    }
  }

  /// Pause music due to context (video, voice input, etc.)
  Future<void> _pauseForContext() async {
    _wasPausedByContext = true;
    await _audioHandler.pause();
    print('[BeatsContext] Paused music for context');
  }

  /// Resume music after context released
  Future<void> _resumeFromContext() async {
    if (!_wasPausedByContext) return;
    _wasPausedByContext = false;
    await _audioHandler.play();
    print('[BeatsContext] Resumed music after context');
  }

  /// Apply volume ducking
  Future<void> _applyDucking(double volumeMultiplier) async {
    _originalVolume = 1.0;
    await _audioHandler.setVolume(volumeMultiplier);
    print('[BeatsContext] Applied ducking: $volumeMultiplier');
  }

  /// Remove volume ducking
  Future<void> _removeDucking() async {
    await _audioHandler.setVolume(_originalVolume);
    _originalVolume = 1.0;
    print('[BeatsContext] Removed ducking, restored volume');
  }

  /// Request ducking for a specific duration (for SFX, etc.)
  Future<void> duckForDuration(Duration duration) async {
    await _contextManager.duckForDuration(duration);
  }

  /// Notify that music playback started
  void onPlaybackStarted() {
    if (!_contextManager.hasFocus(AudioFocusType.music)) {
      _contextManager.requestFocus(AudioFocusType.music);
    }
  }

  /// Notify that music playback stopped
  void onPlaybackStopped() {
    _contextManager.releaseFocus(AudioFocusType.music);
  }

  /// Whether music is currently paused by context
  bool get isPausedByContext => _wasPausedByContext;

  /// Dispose resources
  void dispose() {
    _contextSubscription?.cancel();
    _contextManager.releaseFocus(AudioFocusType.music);
  }
}

