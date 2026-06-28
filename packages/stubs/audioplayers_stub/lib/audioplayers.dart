/// Stub implementation of audioplayers for TV builds
library;

import 'dart:async';

/// Player state
enum PlayerState { stopped, playing, paused, completed, disposed }

/// Release mode
enum ReleaseMode { release, loop, stop }

/// Audio source
abstract class Source {}

/// URL source
class UrlSource implements Source {
  UrlSource(this.url);
  final String url;
}

/// Asset source
class AssetSource implements Source {
  AssetSource(this.path);
  final String path;
}

/// Device file source
class DeviceFileSource implements Source {
  DeviceFileSource(this.path);
  final String path;
}

/// Stub AudioPlayer for dictionary pronunciation
class AudioPlayer {
  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  PlayerState _state = PlayerState.stopped;

  /// Stream of player state changes
  Stream<PlayerState> get onPlayerStateChanged => _stateController.stream;

  /// Stream of position changes
  Stream<Duration> get onPositionChanged => _positionController.stream;

  /// Stream of duration changes
  Stream<Duration> get onDurationChanged => _durationController.stream;

  /// Current state
  PlayerState get state => _state;

  /// Play from source
  Future<void> play(Source source) async {
    _state = PlayerState.playing;
    _stateController.add(_state);
    // Simulate playback completion after short delay
    await Future.delayed(const Duration(milliseconds: 500));
    _state = PlayerState.completed;
    _stateController.add(_state);
  }

  /// Pause playback
  Future<void> pause() async {
    _state = PlayerState.paused;
    _stateController.add(_state);
  }

  /// Stop playback
  Future<void> stop() async {
    _state = PlayerState.stopped;
    _stateController.add(_state);
  }

  /// Resume playback
  Future<void> resume() async {
    _state = PlayerState.playing;
    _stateController.add(_state);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {}

  /// Set playback rate
  Future<void> setPlaybackRate(double playbackRate) async {}

  /// Set release mode
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  /// Dispose
  Future<void> dispose() async {
    _state = PlayerState.disposed;
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
