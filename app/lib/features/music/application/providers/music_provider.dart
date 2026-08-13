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
