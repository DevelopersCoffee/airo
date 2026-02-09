import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../../iptv/domain/models/streaming_state.dart';
import '../../../music/application/providers/music_provider.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/player_display_mode.dart';
import '../../domain/models/quality_settings.dart';
import '../../domain/models/unified_media_content.dart';
import '../../domain/models/unified_player_state.dart';
import 'media_hub_providers.dart';
import 'personalization_provider.dart';

/// Unified player state notifier
class UnifiedPlayerNotifier extends StateNotifier<UnifiedPlayerState> {
  final Ref _ref;
  StreamSubscription? _positionSubscription;
  Timer? _positionSaveTimer;

  UnifiedPlayerNotifier(this._ref) : super(const UnifiedPlayerState()) {
    _listenToStreams();
  }

  void _listenToStreams() {
    // Listen to IPTV streaming state
    _ref.listen<AsyncValue<StreamingState>>(streamingStateProvider, (prev, next) {
      next.whenData((streamingState) {
        if (state.currentContent?.isTV == true) {
          state = state.copyWith(
            playbackState: streamingState.playbackState,
            bufferStatus: streamingState.bufferStatus,
          );
        }
      });
    });
  }

  /// Play unified content
  Future<void> play(UnifiedMediaContent content) async {
    state = state.copyWith(
      currentContent: content,
      playbackState: PlaybackState.loading,
    );

    // Delegate to appropriate player service
    if (content.type == MediaMode.music) {
      // Resume from last position if available
      final personalization = _ref.read(personalizationProvider);
      final lastPosition = personalization.getLastPosition(content.id);
      // TODO: Play music track with lastPosition
      final musicService = _ref.read(musicServiceProvider);
      // musicService.playTrack(track, startPosition: lastPosition);
    } else {
      final iptvService = _ref.read(iptvStreamingServiceProvider);
      // TODO: Convert back to IPTVChannel and play
    }

    // Update personalization
    _ref.read(personalizationProvider.notifier).addToRecent(content);

    // Start position tracking
    _startPositionTracking(content.id);
  }

  /// Pause playback
  void pause() {
    state = state.copyWith(playbackState: PlaybackState.paused);
    // TODO: Pause actual players
  }

  /// Resume playback
  void resume() {
    state = state.copyWith(playbackState: PlaybackState.playing);
    // TODO: Resume actual players
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  /// Seek to position
  void seekTo(Duration position) {
    state = state.copyWith(position: position);
    // TODO: Seek actual players
  }

  /// Set volume
  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
    // TODO: Update actual player volume
  }

  /// Toggle mute
  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  /// Update quality settings
  void updateQualitySettings(QualitySettings settings) {
    state = state.copyWith(qualitySettings: settings);
    // TODO: Apply to actual players
  }

  /// Set display mode
  void setDisplayMode(PlayerDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
    _ref.read(playerDisplayModeProvider.notifier).state = mode;
  }

  /// Play next in queue
  void playNext() {
    if (!state.hasNext) return;
    final nextContent = state.queue[state.currentIndex + 1];
    play(nextContent);
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  /// Play previous in queue
  void playPrevious() {
    if (!state.hasPrevious) return;
    final prevContent = state.queue[state.currentIndex - 1];
    play(prevContent);
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  void _startPositionTracking(String contentId) {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.isPlaying && state.position.inSeconds > 0) {
        _ref.read(personalizationProvider.notifier).savePosition(
          contentId,
          state.position,
        );
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _positionSaveTimer?.cancel();
    super.dispose();
  }
}

/// Unified player provider
final unifiedPlayerProvider = StateNotifierProvider<UnifiedPlayerNotifier, UnifiedPlayerState>(
  (ref) => UnifiedPlayerNotifier(ref),
);

/// Derived: Currently playing content
final currentPlayingContentProvider = Provider<UnifiedMediaContent?>((ref) {
  return ref.watch(unifiedPlayerProvider).currentContent;
});

/// Derived: Is currently playing
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(unifiedPlayerProvider).isPlaying;
});

