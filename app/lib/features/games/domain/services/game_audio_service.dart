import '../../../../core/audio/audio_context_manager.dart';

/// Game audio service interface
/// Provides audio control for games with ducking support
abstract interface class GameAudioService {
  /// Request audio ducking for specified duration
  /// Lowers background music volume during SFX playback
  Future<void> requestDucking(Duration duration);

  /// Play sound effect by ID
  /// Automatically ducks music if configured
  Future<void> playSfx(String id);

  /// Stop all sound effects
  Future<void> stopSfxAll();

  /// Called when game loses audio focus (e.g., phone call)
  Future<void> onFocusLost();

  /// Called when game regains audio focus
  Future<void> onFocusGain();

  /// Set SFX volume (0.0 to 1.0)
  Future<void> setSfxVolume(double volume);

  /// Enable/disable SFX
  Future<void> setSfxEnabled(bool enabled);

  /// Dispose resources
  Future<void> dispose();
}

/// Fake game audio service for development
/// Integrates with AudioContextManager for proper audio focus handling
class FakeGameAudioService implements GameAudioService {
  final AudioContextManager _audioContext;
  bool _sfxEnabled = true;
  double _sfxVolume = 1.0;
  bool _hasFocus = true;

  FakeGameAudioService({AudioContextManager? audioContext})
    : _audioContext = audioContext ?? AudioContextManager();

  @override
  Future<void> requestDucking(Duration duration) async {
    // Use AudioContextManager for ducking instead of GlobalAudioService
    await _audioContext.duckForDuration(duration);
  }

  @override
  Future<void> playSfx(String id) async {
    if (!_sfxEnabled) return;
    // Request SFX audio focus (ducks music automatically)
    _audioContext.requestFocus(AudioFocusType.sfx);
    // Simulate SFX playback (2 second duration)
    print('[GameAudio] Playing SFX: $id at volume $_sfxVolume');
    await Future.delayed(const Duration(seconds: 2));
    // Release focus after SFX completes
    _audioContext.releaseFocus(AudioFocusType.sfx);
  }

  @override
  Future<void> stopSfxAll() async {
    // Release any SFX focus
    _audioContext.releaseFocus(AudioFocusType.sfx);
  }

  @override
  Future<void> onFocusLost() async {
    _hasFocus = false;
    // Release all game audio focus
    _audioContext.releaseFocus(AudioFocusType.sfx);
  }

  @override
  Future<void> onFocusGain() async {
    _hasFocus = true;
    // Focus is regained, game can play audio again
  }

  @override
  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    // Release any held focus
    _audioContext.releaseFocus(AudioFocusType.sfx);
  }
}
