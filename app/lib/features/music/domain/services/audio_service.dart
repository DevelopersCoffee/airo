import '../models/music_models.dart';

/// Audio queue service interface
abstract interface class AudioQueueService {
  /// Set queue items
  Future<void> setQueue(List<AudioItem> items, {int startIndex = 0});

  /// Add item to queue
  Future<void> addItem(AudioItem item);

  /// Add items to queue
  Future<void> addItems(List<AudioItem> items);

  /// Remove item from queue
  Future<void> removeItem(int index);

  /// Clear queue
  Future<void> clear();

  /// Get current queue
  Future<List<AudioItem>> getQueue();

  /// Get current index
  Future<int> getCurrentIndex();
}

/// Audio player service interface
abstract interface class AudioPlayerService {
  /// Play current item
  Future<void> play();

  /// Pause playback
  Future<void> pause();

  /// Stop playback
  Future<void> stop();

  /// Seek to position
  Future<void> seek(Duration position);

  /// Play next item
  Future<void> next();

  /// Play previous item
  Future<void> previous();

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume);

  /// Mute/unmute
  Future<void> setMuted(bool muted);

  /// Get current status
  Future<AudioPlayerStatus> getStatus();

  /// Stream status updates
  Stream<AudioPlayerStatus> statusStream();

  /// Dispose resources
  Future<void> dispose();
}

/// Fake audio player service for development
class FakeAudioPlayerService implements AudioPlayerService {
  AudioPlayerStatus _status = const AudioPlayerStatus(
    state: AudioPlayerState.idle,
  );

  @override
  Future<void> play() async {
    _status = _status.copyWith(state: AudioPlayerState.playing);
  }

  @override
  Future<void> pause() async {
    _status = _status.copyWith(state: AudioPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    _status = _status.copyWith(state: AudioPlayerState.stopped);
  }

  @override
  Future<void> seek(Duration position) async {
    _status = _status.copyWith(currentPosition: position);
  }

  @override
  Future<void> next() async {
    // TODO: Implement
  }

  @override
  Future<void> previous() async {
    // TODO: Implement
  }

  @override
  Future<void> setVolume(double volume) async {
    _status = _status.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> setMuted(bool muted) async {
    _status = _status.copyWith(isMuted: muted);
  }

  @override
  Future<AudioPlayerStatus> getStatus() async {
    return _status;
  }

  @override
  Stream<AudioPlayerStatus> statusStream() async* {
    yield _status;
  }

  @override
  Future<void> dispose() async {
    // TODO: Implement
  }

  AudioPlayerStatus copyWith({
    AudioPlayerState? state,
    AudioItem? currentItem,
    Duration? currentPosition,
    Duration? duration,
    double? volume,
    bool? isMuted,
    String? error,
  }) {
    return AudioPlayerStatus(
      state: state ?? _status.state,
      currentItem: currentItem ?? _status.currentItem,
      currentPosition: currentPosition ?? _status.currentPosition,
      duration: duration ?? _status.duration,
      volume: volume ?? _status.volume,
      isMuted: isMuted ?? _status.isMuted,
      error: error ?? _status.error,
    );
  }
}

extension on AudioPlayerStatus {
  AudioPlayerStatus copyWith({
    AudioPlayerState? state,
    AudioItem? currentItem,
    Duration? currentPosition,
    Duration? duration,
    double? volume,
    bool? isMuted,
    String? error,
  }) {
    return AudioPlayerStatus(
      state: state ?? this.state,
      currentItem: currentItem ?? this.currentItem,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      error: error ?? this.error,
    );
  }
}

