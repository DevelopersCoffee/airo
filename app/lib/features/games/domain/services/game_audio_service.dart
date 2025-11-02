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
class FakeGameAudioService implements GameAudioService {
  bool _sfxEnabled = true;
  double _sfxVolume = 1.0;
  bool _hasFocus = true;

  @override
  Future<void> requestDucking(Duration duration) async {
    // Simulate ducking
    // In real implementation, would call GlobalAudioService.duckMusic()
  }

  @override
  Future<void> playSfx(String id) async {
    if (!_sfxEnabled) return;
    // Simulate SFX playback
    // In real implementation, would call GlobalAudioService.playSfx()
  }

  @override
  Future<void> stopSfxAll() async {
    // Simulate stopping all SFX
  }

  @override
  Future<void> onFocusLost() async {
    _hasFocus = false;
    // Pause game audio
  }

  @override
  Future<void> onFocusGain() async {
    _hasFocus = true;
    // Resume game audio
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
    // Clean up resources
  }
}

