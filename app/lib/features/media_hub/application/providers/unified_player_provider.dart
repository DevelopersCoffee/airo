import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../../iptv/domain/models/iptv_channel.dart';
import '../../../iptv/domain/models/streaming_state.dart';
import '../../../music/application/providers/music_provider.dart';
import '../../../music/domain/services/music_service.dart';
import '../../domain/models/media_category.dart';
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
    _ref.listen<AsyncValue<StreamingState>>(streamingStateProvider, (
      prev,
      next,
    ) {
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

    try {
      // Delegate to appropriate player service
      if (content.type == MediaMode.music) {
        await _playMusicContent(content);
      } else {
        await _playTVContent(content);
      }

      state = state.copyWith(playbackState: PlaybackState.playing);
    } catch (e) {
      state = state.copyWith(
        playbackState: PlaybackState.error,
        errorMessage: 'Failed to play: $e',
      );
      return;
    }

    // Update personalization
    _ref.read(personalizationProvider.notifier).addToRecent(content);

    // Start position tracking
    _startPositionTracking(content.id);
  }

  /// Play music content with resume support
  Future<void> _playMusicContent(UnifiedMediaContent content) async {
    final personalization = _ref.read(personalizationProvider);
    final lastPosition = personalization.getLastPosition(content.id);
    final musicService = _ref.read(musicServiceProvider);

    // Convert UnifiedMediaContent back to MusicTrack
    final track = MusicTrack(
      id: content.id.replaceFirst('music_', ''),
      title: content.title,
      artist: content.subtitle ?? 'Unknown Artist',
      albumArt: content.thumbnailUrl,
      duration: content.duration ?? Duration.zero,
      streamUrl: content.streamUrl,
    );

    // Play the track
    await musicService.playTrack(track);

    // Seek to last position if resumable
    if (lastPosition != null && lastPosition.inSeconds > 10) {
      await musicService.seek(lastPosition);
    }
  }

  /// Play TV content
  Future<void> _playTVContent(UnifiedMediaContent content) async {
    final iptvService = _ref.read(iptvStreamingServiceProvider);

    // Convert UnifiedMediaContent back to IPTVChannel
    final channel = IPTVChannel(
      id: content.id.replaceFirst('tv_', ''),
      name: content.title,
      streamUrl: content.streamUrl ?? '',
      logoUrl: content.thumbnailUrl,
      group: content.subtitle ?? 'Uncategorized',
      category: _mapCategoryToChannelCategory(content.category),
    );

    // Play the channel
    await iptvService.playChannel(channel);
  }

  /// Map MediaCategory back to ChannelCategory
  ChannelCategory _mapCategoryToChannelCategory(MediaCategory? category) {
    if (category == null) return ChannelCategory.all;

    switch (category.id) {
      case 'tv_news':
        return ChannelCategory.news;
      case 'tv_movies':
        return ChannelCategory.movies;
      case 'tv_kids':
        return ChannelCategory.kids;
      case 'tv_music':
        return ChannelCategory.music;
      case 'tv_regional':
        return ChannelCategory.regional;
      default:
        return ChannelCategory.all;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    state = state.copyWith(playbackState: PlaybackState.paused);

    // Pause the appropriate player
    if (state.currentContent?.isMusic == true) {
      await _ref.read(musicServiceProvider).pause();
    } else if (state.currentContent?.isTV == true) {
      await _ref.read(iptvStreamingServiceProvider).pause();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    state = state.copyWith(playbackState: PlaybackState.playing);

    // Resume the appropriate player
    if (state.currentContent?.isMusic == true) {
      await _ref.read(musicServiceProvider).resume();
    } else if (state.currentContent?.isTV == true) {
      await _ref.read(iptvStreamingServiceProvider).resume();
    }
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
  Future<void> seekTo(Duration position) async {
    state = state.copyWith(position: position);

    // Seek the appropriate player
    if (state.currentContent?.isMusic == true) {
      await _ref.read(musicServiceProvider).seek(position);
    } else if (state.currentContent?.isTV == true) {
      await _ref.read(iptvStreamingServiceProvider).seek(position);
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));

    // Update volume on the appropriate player
    if (state.currentContent?.isMusic == true) {
      await _ref.read(musicServiceProvider).setVolume(volume);
    } else if (state.currentContent?.isTV == true) {
      await _ref.read(iptvStreamingServiceProvider).setVolume(volume);
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    final newMuted = !state.isMuted;
    state = state.copyWith(isMuted: newMuted);

    // Toggle mute on TV player (music service doesn't have toggleMute)
    if (state.currentContent?.isTV == true) {
      await _ref.read(iptvStreamingServiceProvider).toggleMute();
    } else if (state.currentContent?.isMusic == true) {
      // For music, set volume to 0 or restore
      final volume = newMuted ? 0.0 : state.volume;
      await _ref.read(musicServiceProvider).setVolume(volume);
    }
  }

  /// Update quality settings
  Future<void> updateQualitySettings(QualitySettings settings) async {
    state = state.copyWith(qualitySettings: settings);

    // Apply quality to TV player
    if (state.currentContent?.isTV == true) {
      await _ref
          .read(iptvStreamingServiceProvider)
          .setQuality(settings.videoQuality);
    }
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

  /// Stop playback and clear content
  Future<void> stop() async {
    // Stop the appropriate player
    if (state.currentContent?.isMusic == true) {
      await _ref.read(musicServiceProvider).stop();
    } else if (state.currentContent?.isTV == true) {
      await _ref.read(iptvStreamingServiceProvider).stop();
    }

    // Cancel timers
    _positionSaveTimer?.cancel();
    _positionSubscription?.cancel();

    // Reset state
    state = const UnifiedPlayerState();
    _ref.read(playerDisplayModeProvider.notifier).state =
        PlayerDisplayMode.hidden;
  }

  void _startPositionTracking(String contentId) {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.isPlaying && state.position.inSeconds > 0) {
        _ref
            .read(personalizationProvider.notifier)
            .savePosition(contentId, state.position);
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
final unifiedPlayerProvider =
    StateNotifierProvider<UnifiedPlayerNotifier, UnifiedPlayerState>(
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
