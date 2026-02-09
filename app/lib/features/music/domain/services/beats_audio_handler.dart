import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// BeatsAudioHandler - Enables background playback and media controls
/// Uses audio_service package to handle platform-specific media sessions
class BeatsAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  /// Queue of media items
  final List<MediaItem> _queue = [];
  int _currentIndex = -1;

  BeatsAudioHandler() : _player = AudioPlayer() {
    _init();
  }

  /// Initialize listeners
  void _init() {
    // Broadcast player state changes
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Handle processing state changes (completed, buffering, etc.)
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Update position stream
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  /// Broadcast current playback state to the system
  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    
    _currentIndex = index;
    final item = _queue[index];
    mediaItem.add(item);
    
    if (item.extras?['url'] != null) {
      await _player.setUrl(item.extras!['url'] as String);
      await _player.play();
    }
  }

  /// Add a single item and play it
  Future<void> playMediaItem(MediaItem item) async {
    _queue.clear();
    _queue.add(item);
    _currentIndex = 0;
    queue.add(_queue);
    mediaItem.add(item);

    if (item.extras?['url'] != null) {
      await _player.setUrl(item.extras!['url'] as String);
      await _player.play();
    }
  }

  /// Add items to queue
  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    _queue.addAll(items);
    queue.add(_queue);
  }

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Get current position stream
  Stream<Duration> get positionStream => _player.positionStream;

  /// Get buffered position stream
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
  }
}

