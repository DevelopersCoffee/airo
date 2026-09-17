import 'dart:async';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';

/// Controller managing pattern playback lifecycle (play, pause, stop, loop).
class AiroHapticPlayer {
  AiroHapticPlayer({
    required this.pattern,
    required Future<void> Function(AiroHapticPattern pattern, AiroHapticOptions? options) onPlayPattern,
    required Future<void> Function(String patternId) onStopPattern,
  })  : _onPlay = onPlayPattern,
        _onStop = onStopPattern;

  final AiroHapticPattern pattern;
  final Future<void> Function(AiroHapticPattern pattern, AiroHapticOptions? options) _onPlay;
  final Future<void> Function(String patternId) _onStop;

  bool _isPlaying = false;
  bool _isPaused = false;
  Timer? _playbackTimer;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;

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
