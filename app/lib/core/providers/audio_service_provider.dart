import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/global_audio_service.dart';

/// Global audio service provider
final audioServiceProvider = Provider<GlobalAudioService>((ref) {
  return GlobalAudioService();
});

/// Audio service initialization provider
final audioServiceInitProvider = FutureProvider<void>((ref) async {
  final audioService = ref.watch(audioServiceProvider);
  await audioService.initialize();
});

/// Music playing state provider
final musicPlayingProvider = StreamProvider<bool>((ref) async* {
  final audioService = ref.watch(audioServiceProvider);
  await audioService.initialize();

  yield audioService.isPlaying;

  // Listen to player state changes
  await for (final state in audioService.getMusicStateStream()) {
    yield audioService.isPlaying;
  }
});

/// Music position provider
final musicPositionProvider = StreamProvider<Duration>((ref) async* {
  final audioService = ref.watch(audioServiceProvider);
  await audioService.initialize();

  yield Duration.zero;

  // Listen to position changes
  await for (final position in audioService.getMusicPositionStream()) {
    yield position;
  }
});

/// Audio ducking state provider
final audioDuckingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Background audio allowed provider
final backgroundAudioProvider = StateProvider<bool>((ref) {
  return true;
});
