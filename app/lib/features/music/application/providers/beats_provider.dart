import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/beats_models.dart';
import '../../domain/repositories/beats_repository.dart';
import '../../data/repositories/mock_beats_repository.dart';
import '../../domain/services/music_service.dart';
import 'music_provider.dart';

/// Beats repository provider
/// Switch to real implementation when Lavalink backend is ready
final beatsRepositoryProvider = Provider<BeatsRepository>((ref) {
  return MockBeatsRepository();
});

/// Beats search state provider
final beatsSearchStateProvider =
    StateNotifierProvider<BeatsSearchNotifier, BeatsSearchUiState>((ref) {
      final repository = ref.watch(beatsRepositoryProvider);
      return BeatsSearchNotifier(repository);
    });

/// Beats search notifier for managing search state
class BeatsSearchNotifier extends StateNotifier<BeatsSearchUiState> {
  final BeatsRepository _repository;
  Timer? _debounceTimer;

  BeatsSearchNotifier(this._repository) : super(const BeatsSearchUiState());

  /// Search for tracks with debouncing
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

  /// Perform the actual search
  Future<void> _performSearch(String query) async {
    // Check if it's a URL
    if (_repository.isValidSourceUrl(query)) {
      await resolveUrl(query);
      return;
    }

    final result = await _repository.searchTracks(query);

    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        state: BeatsSearchState.success,
        results: result.data!.tracks,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        state: BeatsSearchState.error,
        errorMessage: result.error ?? 'Search failed',
      );
    }
  }

  /// Resolve a URL directly
  Future<void> resolveUrl(String url) async {
    state = state.copyWith(state: BeatsSearchState.resolving, query: url);

    final result = await _repository.resolveUrl(url);

    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        state: BeatsSearchState.success,
        results: [result.data!],
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        state: BeatsSearchState.error,
        errorMessage: result.error ?? 'Could not resolve URL',
      );
    }
  }

  /// Clear search results
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

/// Recent tracks provider
final beatsRecentTracksProvider = FutureProvider<List<BeatsTrack>>((ref) async {
  final repository = ref.watch(beatsRepositoryProvider);
  return repository.getRecentTracks();
});

/// Beats controller for playback actions
final beatsControllerProvider = Provider<BeatsController>((ref) {
  final repository = ref.watch(beatsRepositoryProvider);
  final musicController = ref.watch(musicControllerProvider);
  return BeatsController(repository, musicController);
});

/// Controller for Beats playback actions
class BeatsController {
  final BeatsRepository _repository;
  final MusicController _musicController;

  BeatsController(this._repository, this._musicController);

  /// Play a Beats track
  /// Creates a stream session and plays via MusicService
  Future<bool> playTrack(BeatsTrack track) async {
    try {
      // Create stream session
      final sessionResult = await _repository.createStreamSession(track.id);

      if (!sessionResult.isSuccess || sessionResult.data == null) {
        print(
          '[BEATS] Failed to create stream session: ${sessionResult.error}',
        );
        return false;
      }

      final session = sessionResult.data!;

      // Convert to MusicTrack and play
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
    } catch (e) {
      print('[BEATS] Error playing track: $e');
      return false;
    }
  }

  /// Add track to queue
  Future<bool> addToQueue(BeatsTrack track) async {
    // TODO: Implement queue management
    // For now, just play the track
    return playTrack(track);
  }

  /// Check if a URL is valid for Beats
  bool isValidUrl(String url) => _repository.isValidSourceUrl(url);
}
