import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/music_service.dart';
import '../../domain/services/just_audio_music_service.dart';

/// Music service provider - uses JustAudio for real playback
final musicServiceProvider = Provider<MusicService>((ref) {
  return JustAudioMusicService();
});

/// Music player state provider
final musicPlayerStateProvider = StreamProvider<MusicPlayerState>((ref) async* {
  final musicService = ref.watch(musicServiceProvider);
  await musicService.initialize();

  yield* musicService.getStateStream();
});

/// Current track provider
final currentTrackProvider = StreamProvider<MusicTrack?>((ref) async* {
  final state = ref.watch(musicPlayerStateProvider);

  yield* state.when(
    data: (playerState) async* {
      yield playerState.currentTrack;
    },
    loading: () async* {
      yield null;
    },
    error: (_, __) async* {
      yield null;
    },
  );
});

/// Is playing provider
final isPlayingProvider = StreamProvider<bool>((ref) async* {
  final state = ref.watch(musicPlayerStateProvider);

  yield* state.when(
    data: (playerState) async* {
      yield playerState.isPlaying;
    },
    loading: () async* {
      yield false;
    },
    error: (_, __) async* {
      yield false;
    },
  );
});

/// Music position provider
final musicPositionProvider = StreamProvider<Duration>((ref) async* {
  final state = ref.watch(musicPlayerStateProvider);

  yield* state.when(
    data: (playerState) async* {
      yield playerState.position;
    },
    loading: () async* {
      yield Duration.zero;
    },
    error: (_, __) async* {
      yield Duration.zero;
    },
  );
});

/// Music duration provider
final musicDurationProvider = StreamProvider<Duration>((ref) async* {
  final state = ref.watch(musicPlayerStateProvider);

  yield* state.when(
    data: (playerState) async* {
      yield playerState.duration;
    },
    loading: () async* {
      yield Duration.zero;
    },
    error: (_, __) async* {
      yield Duration.zero;
    },
  );
});

/// Queue provider
final queueProvider = StreamProvider<List<MusicTrack>>((ref) async* {
  final state = ref.watch(musicPlayerStateProvider);

  yield* state.when(
    data: (playerState) async* {
      yield playerState.queue;
    },
    loading: () async* {
      yield [];
    },
    error: (_, __) async* {
      yield [];
    },
  );
});

/// Music controller provider
final musicControllerProvider = Provider<MusicController>((ref) {
  final musicService = ref.watch(musicServiceProvider);
  return MusicController(musicService);
});

/// Music controller for managing playback
class MusicController {
  final MusicService _musicService;

  MusicController(this._musicService);

  Future<void> playTrack(MusicTrack track) => _musicService.playTrack(track);

  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) =>
      _musicService.playQueue(tracks, startIndex: startIndex);

  Future<void> pause() => _musicService.pause();

  Future<void> resume() => _musicService.resume();

  Future<void> stop() => _musicService.stop();

  Future<void> next() => _musicService.next();

  Future<void> previous() => _musicService.previous();

  Future<void> seek(Duration position) => _musicService.seek(position);

  Future<void> setVolume(double volume) => _musicService.setVolume(volume);
}
