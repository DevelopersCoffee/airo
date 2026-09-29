import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
// ignore: unused_import, depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';

/// BeatsAudioHandler - Enables background playback and media controls
/// Uses audio_service package to handle platform-specific media sessions
class BeatsAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  /// Queue of media items
  final List<MediaItem> _queue = [];
  int _currentIndex = -1;

  BeatsAudioHandler() : _player = AudioPlayer() {
    _init();
  }

  /// Initialize listeners
  void _init() {
    // Broadcast player state changes
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Handle processing state changes (completed, buffering, etc.)
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Update position stream
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });
  }

  /// Broadcast current playback state to the system
  void _broadcastState() {
    final playing = _player.playing;
    final currentState = playbackState.value.processingState;
    final mappedState = _mapProcessingState(_player.processingState);
    final targetState = (currentState == AudioProcessingState.error && !playing)
        ? AudioProcessingState.error
        : mappedState;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: targetState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;

    _currentIndex = index;
    final item = _queue[index];
    mediaItem.add(item);

    if (item.extras?['url'] != null) {
      try {
        await _player.setUrl(item.extras!['url'] as String);
        await _player.play();
      } catch (e) {
        print('[BeatsAudioHandler] Error playing item at index $index: $e');
        _notifyError(e);
      }
    }
  }

  /// Add a single item and play it
  @override
  Future<void> playMediaItem(MediaItem item) async {
    _queue.clear();
    _queue.add(item);
    _currentIndex = 0;
    queue.add(_queue);
    mediaItem.add(item);

    if (item.extras?['url'] != null) {
      try {
        await _player.setUrl(item.extras!['url'] as String);
        await _player.play();
      } catch (e) {
        print('[BeatsAudioHandler] Error playing item: $e');
        _notifyError(e);
      }
    }
  }

  /// Add items to queue
  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    _queue.addAll(items);
    queue.add(_queue);
  }

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Get current position stream
  Stream<Duration> get positionStream => _player.positionStream;

  /// Get buffered position stream
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// Error stream for recovery
  Stream<Object> get errorStream => _player.playbackEventStream
      .where((event) => event.processingState == ProcessingState.idle)
      .map((event) => 'Playback stopped unexpectedly');

  /// Notify error through playback state
  void _notifyError(Object error) {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: error.toString(),
      ),
    );
  }

  /// List of favorite media items for Android Auto
  final List<MediaItem> _favoriteItems = [];

  /// List of recent media items for Android Auto (capped at 10)
  final List<MediaItem> _recentItems = [];

  /// Active sleep timer instance
  int _sleepTimerMinutes = 0;

  /// Update favorites list and notify Android Auto
  void setFavorites(List<MediaItem> items) {
    _favoriteItems.clear();
    _favoriteItems.addAll(items.map((item) => _optimizeMediaItemForAuto(item, isGrid: true)));
  }

  /// Add item to recent items list and notify Android Auto
  void addRecent(MediaItem item) {
    _recentItems.removeWhere((existing) => existing.id == item.id);
    _recentItems.insert(0, _optimizeMediaItemForAuto(item, isGrid: false));
    if (_recentItems.length > 10) {
      _recentItems.removeLast();
    }
  }

  /// Optimize media item URI and attach Android Auto Driver Distraction hints
  MediaItem _optimizeMediaItemForAuto(MediaItem item, {required bool isGrid}) {
    final originalUri = item.artUri;
    final optimizedArtUri = originalUri?.replace(
      queryParameters: {
        ...originalUri.queryParameters,
        'w': '320',
        'h': '320',
        'fit': 'crop',
      },
    );

    return item.copyWith(
      artUri: optimizedArtUri,
      extras: {
        ...?item.extras,
        'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
        'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': isGrid ? 2 : 1,
        'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
      },
    );
  }

  /// Android Auto Root & Hierarchy Provider
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    switch (parentMediaId) {
      case 'root':
      case 'root_id':
      case 'recent':
        return [
          const MediaItem(
            id: 'favorites',
            title: 'Favorites',
            playable: false,
            extras: {
              'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
              'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
            },
          ),
          const MediaItem(
            id: 'recents',
            title: 'Recent Stations',
            playable: false,
            extras: {
              'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
              'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
            },
          ),
          const MediaItem(
            id: 'all_tracks',
            title: 'All Channels',
            playable: false,
          ),
        ];
      case 'favorites':
        return _favoriteItems;
      case 'recents':
        return _recentItems;
      case 'all_tracks':
        return _queue.map((item) => _optimizeMediaItemForAuto(item, isGrid: false)).toList();
      default:
        return [];
    }
  }

  /// Google Assistant & Voice Command query handler
  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) {
      if (_queue.isNotEmpty) await play();
      return;
    }

    final match = _queue.firstWhere(
      (item) {
        final titleMatch = item.title.toLowerCase().contains(cleanQuery);
        final artistMatch = item.artist?.toLowerCase().contains(cleanQuery) ?? false;
        final genreMatch = (item.genre?.toLowerCase() ?? '').contains(cleanQuery);
        return titleMatch || artistMatch || genreMatch;
      },
      orElse: () => const MediaItem(id: '', title: ''),
    );

    if (match.id.isNotEmpty) {
      final index = _queue.indexOf(match);
      await skipToQueueItem(index);
    } else {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: 'No stream matching "$query" found on Aika Stream',
        ),
      );
    }
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final index = _queue.indexWhere((item) => item.id == mediaId);
    if (index != -1) {
      await skipToQueueItem(index);
    } else {
      await playFromSearch(mediaId, extras);
    }
  }

  /// Sleep Timer with smooth 30-second linear volume fade-out
  Future<void> setSleepTimer(int minutes) async {
    _sleepTimerMinutes = minutes;
    if (minutes <= 0) return;

    final initialVolume = _player.volume;
    final totalDuration = Duration(minutes: minutes);
    final fadeStartDuration = totalDuration - const Duration(seconds: 30);

    // Dynamic metadata update
    if (currentMediaItem != null) {
      mediaItem.add(
        currentMediaItem!.copyWith(
          displaySubtitle: '${currentMediaItem!.artist ?? ''} • Sleep in $minutes min',
        ),
      );
    }

    // Schedule fade-out 30s before expiry
    Timer(fadeStartDuration > Duration.zero ? fadeStartDuration : Duration.zero, () async {
      if (_sleepTimerMinutes != minutes) return; // Cancelled/overridden

      const steps = 30;
      for (var i = steps; i >= 0; i--) {
        if (_sleepTimerMinutes != minutes) break;
        final ratio = i / steps;
        await _player.setVolume(initialVolume * ratio);
        await Future.delayed(const Duration(seconds: 1));
      }

      await stop();
      await _player.setVolume(initialVolume); // Restore volume for next session
    });
  }

  /// Retry current track
  Future<bool> retryCurrentTrack() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return false;

    final item = _queue[_currentIndex];
    if (item.extras?['url'] == null) return false;

    try {
      await _player.setUrl(item.extras!['url'] as String);
      await _player.play();
      return true;
    } catch (e) {
      print('[BeatsAudioHandler] Retry failed: $e');
      return false;
    }
  }

  /// Get current media item
  MediaItem? get currentMediaItem {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
  }
}
