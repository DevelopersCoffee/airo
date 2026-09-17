import 'dart:async';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';

/// Controller managing pattern playback lifecycle (play/start, pause, resume, stop, live parameter updates).
class AiroHapticPlayer {
  /// Constructs an [AiroHapticPlayer].
  AiroHapticPlayer({
    required this.pattern,
    required Future<void> Function(AiroHapticPattern pattern, AiroHapticOptions? options) onPlayPattern,
    required Future<void> Function(String patternId) onStopPattern,
    Future<void> Function(String patternId, double intensity, double sharpness)? onUpdatePattern,
  })  : _onPlay = onPlayPattern,
        _onStop = onStopPattern,
        _onUpdate = onUpdatePattern;

  final AiroHapticPattern pattern;
  final Future<void> Function(AiroHapticPattern pattern, AiroHapticOptions? options) _onPlay;
  final Future<void> Function(String patternId) _onStop;
  final Future<void> Function(String patternId, double intensity, double sharpness)? _onUpdate;

  bool _isPlaying = false;
  bool _isPaused = false;
  double _currentIntensity = 1;
  double _currentSharpness = 0.5;
  Timer? _playbackTimer;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get currentIntensity => _currentIntensity;
  double get currentSharpness => _currentSharpness;

  /// Starts playback of the pattern.
  Future<void> start({AiroHapticOptions? options}) => play(options: options);

  /// Starts playback of the pattern.
  Future<void> play({AiroHapticOptions? options}) async {
    stop();
    _isPlaying = true;
    _isPaused = false;

    await _onPlay(pattern, options);

    if (!pattern.loop) {
      _playbackTimer = Timer(pattern.totalDuration, () {
        _isPlaying = false;
        _isPaused = false;
      });
    }
  }

  /// Dynamically updates live intensity and sharpness parameters during playback.
  Future<void> update({
    double? intensity,
    double? sharpness,
  }) async {
    if (intensity != null) _currentIntensity = intensity.clamp(0.0, 1.0);
    if (sharpness != null) _currentSharpness = sharpness.clamp(0.0, 1.0);

    if (_isPlaying && _onUpdate != null) {
      await _onUpdate(pattern.id, _currentIntensity, _currentSharpness);
    }
  }

  /// Pauses pattern playback.
  void pause() {
    if (_isPlaying && !_isPaused) {
      _isPaused = true;
      _playbackTimer?.cancel();
      _onStop(pattern.id);
    }
  }

  /// Resumes pattern playback if paused.
  Future<void> resume({AiroHapticOptions? options}) async {
    if (_isPaused) {
      _isPaused = false;
      await play(options: options);
    }
  }

  /// Stops pattern playback completely.
  void stop() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (_isPlaying || _isPaused) {
      _isPlaying = false;
      _isPaused = false;
      _onStop(pattern.id);
    }
  }

  void dispose() {
    stop();
  }
}
