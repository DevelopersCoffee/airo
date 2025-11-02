import 'package:just_audio/just_audio.dart';
import 'music_service.dart';

/// JustAudio implementation of MusicService
class JustAudioMusicService implements MusicService {
  late final AudioPlayer _audioPlayer;
  List<MusicTrack> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;

  JustAudioMusicService() {
    _audioPlayer = AudioPlayer();
  }

  @override
  Future<void> initialize() async {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
    });

    // Auto-play next track when current finishes
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        next();
      }
    });
  }

  @override
  Future<void> playTrack(MusicTrack track) async {
    try {
      _queue = [track];
      _currentIndex = 0;
      if (track.streamUrl != null) {
        await _audioPlayer.setUrl(track.streamUrl!);
        await _audioPlayer.play();
        _isPlaying = true;
      } else {
        throw Exception('Track has no stream URL');
      }
    } catch (e) {
      print('[MUSIC] Error playing track: $e');
      rethrow;
    }
  }

  @override
  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    try {
      _queue = tracks;
      _currentIndex = startIndex.clamp(0, tracks.length - 1);

      final track = tracks[_currentIndex];
      if (track.streamUrl != null) {
        await _audioPlayer.setUrl(track.streamUrl!);
        await _audioPlayer.play();
        _isPlaying = true;
      } else {
        throw Exception('Track has no stream URL');
      }
    } catch (e) {
      print('[MUSIC] Error playing queue: $e');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
    } catch (e) {
      print('[MUSIC] Error pausing: $e');
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _audioPlayer.play();
      _isPlaying = true;
    } catch (e) {
      print('[MUSIC] Error resuming: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentIndex = -1;
      _queue = [];
    } catch (e) {
      print('[MUSIC] Error stopping: $e');
    }
  }

  @override
  Future<void> next() async {
    if (_currentIndex < _queue.length - 1) {
      await playQueue(_queue, startIndex: _currentIndex + 1);
    }
  }

  @override
  Future<void> previous() async {
    if (_currentIndex > 0) {
      await playQueue(_queue, startIndex: _currentIndex - 1);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      print('[MUSIC] Error seeking: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      print('[MUSIC] Error setting volume: $e');
    }
  }

  @override
  Stream<MusicPlayerState> getStateStream() async* {
    yield* _audioPlayer.playerStateStream
        .asyncMap((_) => _buildPlayerState())
        .distinct();
  }

  Future<MusicPlayerState> _buildPlayerState() async {
    final currentTrack = _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;

    return MusicPlayerState(
      currentTrack: currentTrack,
      isPlaying: _isPlaying,
      position: _audioPlayer.position,
      duration: _audioPlayer.duration ?? Duration.zero,
      queue: _queue,
      currentIndex: _currentIndex,
    );
  }

  @override
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
