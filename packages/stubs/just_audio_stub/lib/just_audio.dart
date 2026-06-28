/// Stub implementation of just_audio for TV builds
library;

import 'dart:async';

/// Processing state
enum ProcessingState { idle, loading, buffering, ready, completed }

/// Loop mode
enum LoopMode { off, one, all }

/// Playback event
class PlaybackEvent {
  PlaybackEvent({
    this.processingState = ProcessingState.idle,
    this.duration,
    this.currentIndex,
  });
  final ProcessingState processingState;
  final Duration? duration;
  final int? currentIndex;
}

/// Player state
class PlayerState {
  PlayerState({
    this.processingState = ProcessingState.idle,
    this.playing = false,
  });
  final ProcessingState processingState;
  final bool playing;
}

/// Stub AudioPlayer
class AudioPlayer {
  final _playbackEventController = StreamController<PlaybackEvent>.broadcast();
  final _processingStateController =
      StreamController<ProcessingState>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();

  bool _playing = false;
  final ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;
  final Duration _bufferedPosition = Duration.zero;
  Duration? _duration;
  final double _speed = 1;

  /// Stream of playback events
  Stream<PlaybackEvent> get playbackEventStream =>
      _playbackEventController.stream;

  /// Stream of processing state changes
  Stream<ProcessingState> get processingStateStream =>
      _processingStateController.stream;

  /// Stream of playing state changes
  Stream<bool> get playingStream => _playingController.stream;

  /// Stream of position changes
  Stream<Duration> get positionStream => _positionController.stream;

  /// Stream of duration changes
  Stream<Duration?> get durationStream => _durationController.stream;

  /// Stream of buffered position changes
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  /// Whether currently playing
  bool get playing => _playing;

  /// Current position
  Duration get position => _position;

  /// Current duration
  Duration? get duration => _duration;

  /// Current processing state
  ProcessingState get processingState => _processingState;

  /// Current buffered position
  Duration get bufferedPosition => _bufferedPosition;

  /// Current playback speed
  double get speed => _speed;

  /// Set audio source
  Future<Duration?> setUrl(String url, {Map<String, String>? headers}) async =>
      null;

  /// Set audio source from asset
  Future<Duration?> setAsset(String asset) async => null;

  /// Set audio source from file
  Future<Duration?> setFilePath(String filePath) async => null;

  /// Play
  Future<void> play() async {
    _playing = true;
    _playingController.add(true);
  }

  /// Pause
  Future<void> pause() async {
    _playing = false;
    _playingController.add(false);
  }

  /// Stop
  Future<void> stop() async {
    _playing = false;
    _playingController.add(false);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(position);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {}

  /// Set speed
  Future<void> setSpeed(double speed) async {}

  /// Set loop mode
  Future<void> setLoopMode(LoopMode loopMode) async {}

  /// Dispose
  Future<void> dispose() async {
    await _playbackEventController.close();
    await _processingStateController.close();
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
