import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Global audio service - single instance for entire app
/// Manages music playback, audio focus, ducking, and background playback
class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();

  late AudioPlayer _musicPlayer;
  late AudioPlayer _sfxPlayer;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isDucked = false;
  double _normalVolume = 1.0;
  final double _duckedVolume = 0.3;

  // Audio focus management
  bool _hasAudioFocus = true;
  bool _allowBackgroundAudio = true;

  GlobalAudioService._internal();

  factory GlobalAudioService() {
    return _instance;
  }

  /// Initialize audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _musicPlayer = AudioPlayer();
    _sfxPlayer = AudioPlayer();

    // Configure audio session for background playback
    await _configureAudioSession();

    _isInitialized = true;
  }

  /// Configure audio session for background playback and ducking
  Future<void> _configureAudioSession() async {
    // WIP: Platform-specific audio session configuration
    // Android: Request media style notification, foreground service
    // iOS: Enable audio background mode, set AVAudioSession category
  }

  /// Play music
  Future<void> playMusic(String url, {String? title}) async {
    if (!_isInitialized) await initialize();

    try {
      await _musicPlayer.setUrl(url);
      await _musicPlayer.play();
      _isPlaying = true;
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  /// Pause music
  Future<void> pauseMusic() async {
    if (!_isInitialized) return;
    await _musicPlayer.pause();
    _isPlaying = false;
  }

  /// Resume music
  Future<void> resumeMusic() async {
    if (!_isInitialized) return;
    await _musicPlayer.play();
    _isPlaying = true;
  }

  /// Stop music
  Future<void> stopMusic() async {
    if (!_isInitialized) return;
    await _musicPlayer.stop();
    _isPlaying = false;
  }

  /// Next track
  Future<void> nextTrack() async {
    if (!_isInitialized) return;
    // WIP: Implement queue management
  }

  /// Play SFX with optional ducking
  Future<void> playSfx(String url, {Duration? duckDuration}) async {
    if (!_isInitialized) await initialize();

    try {
      // Duck music if requested
      if (duckDuration != null && _isPlaying) {
        await duckMusic(duckDuration);
      }

      await _sfxPlayer.setUrl(url);
      await _sfxPlayer.play();
    } catch (e) {
      print('Error playing SFX: $e');
    }
  }

  /// Duck music volume (lower for SFX)
  Future<void> duckMusic(Duration duration) async {
    if (!_isInitialized || _isDucked) return;

    _isDucked = true;
    await _musicPlayer.setVolume(_duckedVolume);

    // Restore volume after duration
    await Future.delayed(duration);
    if (_isDucked) {
      await _musicPlayer.setVolume(_normalVolume);
      _isDucked = false;
    }
  }

  /// Set music volume
  Future<void> setMusicVolume(double volume) async {
    if (!_isInitialized) return;
    _normalVolume = volume.clamp(0.0, 1.0);
    if (!_isDucked) {
      await _musicPlayer.setVolume(_normalVolume);
    }
  }

  /// Set SFX volume
  Future<void> setSfxVolume(double volume) async {
    if (!_isInitialized) return;
    await _sfxPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Get music player state stream
  Stream<PlayerState> getMusicStateStream() {
    if (!_isInitialized) return Stream.empty();
    return _musicPlayer.playerStateStream;
  }

  /// Get music position stream
  Stream<Duration> getMusicPositionStream() {
    if (!_isInitialized) return Stream.empty();
    return _musicPlayer.positionStream;
  }

  /// Handle audio focus loss (e.g., phone call)
  Future<void> onAudioFocusLoss() async {
    _hasAudioFocus = false;
    await pauseMusic();
  }

  /// Handle audio focus gain (e.g., call ended)
  Future<void> onAudioFocusGain() async {
    _hasAudioFocus = true;
    if (_allowBackgroundAudio) {
      await resumeMusic();
    }
  }

  /// Set background audio permission
  void setAllowBackgroundAudio(bool allow) {
    _allowBackgroundAudio = allow;
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
    _isInitialized = false;
  }

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isDucked => _isDucked;
  bool get hasAudioFocus => _hasAudioFocus;
  bool get allowBackgroundAudio => _allowBackgroundAudio;
  AudioPlayer get musicPlayer => _musicPlayer;
  AudioPlayer get sfxPlayer => _sfxPlayer;
}
