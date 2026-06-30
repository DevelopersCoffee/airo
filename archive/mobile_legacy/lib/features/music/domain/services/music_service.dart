import 'package:equatable/equatable.dart';

/// Music track model
class MusicTrack extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? albumArt;
  final Duration duration;
  final String? streamUrl;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.duration,
    this.streamUrl,
  });

  @override
  List<Object?> get props => [id, title, artist, albumArt, duration, streamUrl];
}

/// Music player state
class MusicPlayerState extends Equatable {
  final MusicTrack? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<MusicTrack> queue;
  final int currentIndex;

  const MusicPlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
  });

  @override
  List<Object?> get props => [
    currentTrack,
    isPlaying,
    position,
    duration,
    queue,
    currentIndex,
  ];
}

/// Music service interface
abstract interface class MusicService {
  /// Initialize service
  Future<void> initialize();

  /// Play a track
  Future<void> playTrack(MusicTrack track);

  /// Play queue of tracks
  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0});

  /// Pause playback
  Future<void> pause();

  /// Resume playback
  Future<void> resume();

  /// Stop playback
  Future<void> stop();

  /// Next track
  Future<void> next();

  /// Previous track
  Future<void> previous();

  /// Seek to position
  Future<void> seek(Duration position);

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume);

  /// Get player state stream
  Stream<MusicPlayerState> getStateStream();

  /// Dispose resources
  Future<void> dispose();
}

/// Fake music service for development
class FakeMusicService implements MusicService {
  MusicPlayerState _state = const MusicPlayerState();

  @override
  Future<void> initialize() async {
    // No-op for fake service
  }

  @override
  Future<void> playTrack(MusicTrack track) async {
    _state = MusicPlayerState(
      currentTrack: track,
      isPlaying: true,
      duration: track.duration,
      queue: [track],
      currentIndex: 0,
    );
    print('[MUSIC] Playing: ${track.title}');
  }

  @override
  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _state = MusicPlayerState(
      currentTrack: tracks[startIndex],
      isPlaying: true,
      duration: tracks[startIndex].duration,
      queue: tracks,
      currentIndex: startIndex,
    );
    print('[MUSIC] Playing queue with ${tracks.length} tracks');
  }

  @override
  Future<void> pause() async {
    _state = _state.copyWith(isPlaying: false);
    print('[MUSIC] Paused');
  }

  @override
  Future<void> resume() async {
    _state = _state.copyWith(isPlaying: true);
    print('[MUSIC] Resumed');
  }

  @override
  Future<void> stop() async {
    _state = const MusicPlayerState();
    print('[MUSIC] Stopped');
  }

  @override
  Future<void> next() async {
    if (_state.currentIndex < _state.queue.length - 1) {
      final nextTrack = _state.queue[_state.currentIndex + 1];
      _state = _state.copyWith(
        currentTrack: nextTrack,
        currentIndex: _state.currentIndex + 1,
      );
      print('[MUSIC] Next: ${nextTrack.title}');
    }
  }

  @override
  Future<void> previous() async {
    if (_state.currentIndex > 0) {
      final prevTrack = _state.queue[_state.currentIndex - 1];
      _state = _state.copyWith(
        currentTrack: prevTrack,
        currentIndex: _state.currentIndex - 1,
      );
      print('[MUSIC] Previous: ${prevTrack.title}');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _state = _state.copyWith(position: position);
    print('[MUSIC] Seek to ${position.inSeconds}s');
  }

  @override
  Future<void> setVolume(double volume) async {
    print('[MUSIC] Volume: ${(volume * 100).toStringAsFixed(0)}%');
  }

  @override
  Stream<MusicPlayerState> getStateStream() async* {
    yield _state;
  }

  @override
  Future<void> dispose() async {
    print('[MUSIC] Disposed');
  }
}

extension MusicPlayerStateCopyWith on MusicPlayerState {
  MusicPlayerState copyWith({
    MusicTrack? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<MusicTrack>? queue,
    int? currentIndex,
  }) {
    return MusicPlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
