import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/beats_models.dart';
import '../../domain/repositories/beats_repository.dart';
import '../../data/repositories/mock_beats_repository.dart';
import '../../domain/services/music_service.dart';
import '../../domain/services/beats_audio_handler.dart';
import 'beats_audio_provider.dart';
import 'music_provider.dart';

/// Provider for BeatsRepository
final beatsRepositoryProvider = Provider<BeatsRepository>((ref) {
  return MockBeatsRepository();
});

/// Provider for Beats search state
final beatsSearchStateProvider =
    StateNotifierProvider<BeatsSearchNotifier, BeatsSearchUiState>((ref) {
      final repository = ref.watch(beatsRepositoryProvider);
      return BeatsSearchNotifier(repository);
    });

/// Provider for recent tracks
final beatsRecentTracksProvider = FutureProvider<List<BeatsTrack>>((ref) async {
  final repository = ref.watch(beatsRepositoryProvider);
  return repository.getRecentTracks();
});

/// Provider for BeatsController with background audio support
final beatsControllerProvider = Provider<BeatsController>((ref) {
  final repository = ref.watch(beatsRepositoryProvider);
  final musicController = ref.watch(musicControllerProvider);

  // Try to get audio handler for background playback support
  BeatsAudioHandler? audioHandler;
  try {
    audioHandler = ref.watch(beatsAudioHandlerProvider);
  } catch (_) {
    // Audio service not initialized yet - will use regular music controller
  }

  return BeatsController(
    repository,
    musicController,
    audioHandler: audioHandler,
  );
});

/// Notifier for Beats search state
class BeatsSearchNotifier extends StateNotifier<BeatsSearchUiState> {
  final BeatsRepository _repository;
  Timer? _debounceTimer;

  BeatsSearchNotifier(this._repository) : super(const BeatsSearchUiState());

  void search(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      state = const BeatsSearchUiState();
      return;
    }

    state = state.copyWith(state: BeatsSearchState.searching, query: query);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    // Check if it's a URL
    if (BeatsUrlPatterns.isSupported(query)) {
      state = state.copyWith(state: BeatsSearchState.resolving);
      final result = await _repository.resolveUrl(query);
      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          state: BeatsSearchState.success,
          results: [result.data!],
        );
      } else {
        state = state.copyWith(
          state: BeatsSearchState.error,
          errorMessage: result.error ?? 'Failed to resolve URL',
        );
      }
    } else {
      // Regular search
      final result = await _repository.searchTracks(query);
      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          state: BeatsSearchState.success,
          results: result.data!.tracks,
        );
      } else {
        state = state.copyWith(
          state: BeatsSearchState.error,
          errorMessage: result.error ?? 'Search failed',
        );
      }
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const BeatsSearchUiState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Controller for Beats playback with background audio support
class BeatsController {
  final BeatsRepository _repository;
  final MusicController _musicController;
  final BeatsAudioHandler? _audioHandler;

  BeatsController(
    this._repository,
    this._musicController, {
    BeatsAudioHandler? audioHandler,
  }) : _audioHandler = audioHandler;

  /// Check if background audio is available
  bool get hasBackgroundAudio => _audioHandler != null;

  Future<bool> playTrack(BeatsTrack track) async {
    final sessionResult = await _repository.createStreamSession(track.id);
    if (sessionResult.isFailure) return false;

    final session = sessionResult.data!;

    // Use audio handler for background playback if available
    if (_audioHandler != null) {
      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        artUri: track.thumbnailUrl != null
            ? Uri.parse(track.thumbnailUrl!)
            : null,
        duration: track.duration,
        extras: {'url': session.hlsManifestUrl},
      );
      await _audioHandler.playMediaItem(mediaItem);
      return true;
    }

    // Fallback to regular music controller
    final musicTrack = MusicTrack(
      id: track.id,
      title: track.title,
      artist: track.artist,
      albumArt: track.thumbnailUrl,
      duration: track.duration,
      streamUrl: session.hlsManifestUrl,
    );

    await _musicController.playTrack(musicTrack);
    return true;
  }

  Future<bool> addToQueue(BeatsTrack track) async {
    final sessionResult = await _repository.createStreamSession(track.id);
    if (sessionResult.isFailure) return false;

    final session = sessionResult.data!;

    // Use audio handler for background playback if available
    if (_audioHandler != null) {
      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        artUri: track.thumbnailUrl != null
            ? Uri.parse(track.thumbnailUrl!)
            : null,
        duration: track.duration,
        extras: {'url': session.hlsManifestUrl},
      );
      await _audioHandler.addQueueItems([mediaItem]);
      return true;
    }

    // Fallback to regular music controller
    final musicTrack = MusicTrack(
      id: track.id,
      title: track.title,
      artist: track.artist,
      albumArt: track.thumbnailUrl,
      duration: track.duration,
      streamUrl: session.hlsManifestUrl,
    );

    await _musicController.playTrack(musicTrack);
    return true;
  }
}
