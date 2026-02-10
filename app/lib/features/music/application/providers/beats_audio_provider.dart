import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_context_provider.dart';
import '../../domain/services/beats_audio_handler.dart';
import '../../domain/services/beats_context_integration.dart';

/// Singleton instance of BeatsAudioHandler
BeatsAudioHandler? _audioHandler;

/// Initialize the audio service - call this once at app startup
Future<BeatsAudioHandler> initAudioService() async {
  if (_audioHandler != null) return _audioHandler!;

  _audioHandler = await AudioService.init(
    builder: () => BeatsAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.airo.app.audio',
      androidNotificationChannelName: 'Airo Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );

  return _audioHandler!;
}

/// Provider for BeatsAudioHandler
/// This requires initAudioService() to be called before use
final beatsAudioHandlerProvider = Provider<BeatsAudioHandler>((ref) {
  if (_audioHandler == null) {
    throw StateError(
      'Audio service not initialized. Call initAudioService() in main.dart before runApp().',
    );
  }
  return _audioHandler!;
});

/// Provider for current media item
final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  return handler.mediaItem;
});

/// Provider for playback state
final beatsPlaybackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  return handler.playbackState;
});

/// Provider for checking if currently playing
final isBeatsPlayingProvider = Provider<bool>((ref) {
  final playbackState = ref.watch(beatsPlaybackStateProvider);
  return playbackState.when(
    data: (state) => state.playing,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Provider for current position
final beatsPositionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  return handler.positionStream;
});

/// Provider for buffered position
final beatsBufferedPositionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  return handler.bufferedPositionStream;
});

/// Provider for queue
final beatsQueueProvider = StreamProvider<List<MediaItem>>((ref) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  return handler.queue;
});

/// Beats audio controller for easy playback management
class BeatsAudioController {
  final BeatsAudioHandler _handler;

  BeatsAudioController(this._handler);

  /// Play a track
  Future<void> playTrack({
    required String id,
    required String title,
    required String artist,
    String? albumArt,
    Duration? duration,
    required String streamUrl,
  }) async {
    final mediaItem = MediaItem(
      id: id,
      title: title,
      artist: artist,
      artUri: albumArt != null ? Uri.parse(albumArt) : null,
      duration: duration,
      extras: {'url': streamUrl},
    );
    await _handler.playMediaItem(mediaItem);
  }

  /// Pause playback
  Future<void> pause() => _handler.pause();

  /// Resume playback
  Future<void> play() => _handler.play();

  /// Stop playback
  Future<void> stop() => _handler.stop();

  /// Skip to next track
  Future<void> next() => _handler.skipToNext();

  /// Skip to previous track
  Future<void> previous() => _handler.skipToPrevious();

  /// Seek to position
  Future<void> seek(Duration position) => _handler.seek(position);

  /// Set volume
  Future<void> setVolume(double volume) => _handler.setVolume(volume);
}

/// Provider for BeatsAudioController
final beatsAudioControllerProvider = Provider<BeatsAudioController>((ref) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  return BeatsAudioController(handler);
});

/// Provider for BeatsContextIntegration
/// Connects Beats playback with audio context for ducking/pause
final beatsContextIntegrationProvider = Provider<BeatsContextIntegration>((
  ref,
) {
  final handler = ref.watch(beatsAudioHandlerProvider);
  final contextManager = ref.watch(audioContextManagerProvider);

  final integration = BeatsContextIntegration(
    audioHandler: handler,
    contextManager: contextManager,
  );

  ref.onDispose(() => integration.dispose());
  return integration;
});

/// Provider for whether music is paused by context
final isMusicPausedByContextProvider = Provider<bool>((ref) {
  final integration = ref.watch(beatsContextIntegrationProvider);
  return integration.isPausedByContext;
});
