/// Stub implementation of audio_service for TV builds
library;

import 'dart:async';
import 'package:rxdart/rxdart.dart';

/// Audio Service for background playback
class AudioService {
  static Future<T> init<T extends BaseAudioHandler>({
    required T Function() builder,
    AudioServiceConfig config = const AudioServiceConfig(),
  }) async => builder();
}

/// Audio Service configuration
class AudioServiceConfig {
  const AudioServiceConfig({
    this.androidNotificationChannelId = 'com.example.audio',
    this.androidNotificationChannelName = 'Audio',
    this.androidNotificationChannelDescription,
    this.androidNotificationIcon,
    this.androidNotificationOngoing = false,
    this.androidStopForegroundOnPause = true,
    this.androidShowNotificationBadge = false,
    this.preloadArtwork = false,
    this.androidBrowsableRootExtras,
    this.fastForwardInterval = const Duration(seconds: 10),
    this.rewindInterval = const Duration(seconds: 10),
  });
  final String androidNotificationChannelId;
  final String androidNotificationChannelName;
  final String? androidNotificationChannelDescription;
  final String? androidNotificationIcon;
  final bool androidNotificationOngoing;
  final bool androidStopForegroundOnPause;
  final bool androidShowNotificationBadge;
  final bool preloadArtwork;
  final Map<String, dynamic>? androidBrowsableRootExtras;
  final Duration fastForwardInterval;
  final Duration rewindInterval;
}

/// Media item
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    this.album,
    this.artist,
    this.artUri,
    this.duration,
    this.extras,
  });
  final String id;
  final String title;
  final String? album;
  final String? artist;
  final Uri? artUri;
  final Duration? duration;
  final Map<String, dynamic>? extras;
}

/// Media control button
enum MediaControl {
  play._('play'),
  pause._('pause'),
  stop._('stop'),
  skipToNext._('skipToNext'),
  skipToPrevious._('skipToPrevious'),
  rewind._('rewind'),
  fastForward._('fastForward');

  const MediaControl._(this._name);
  final String _name;
}

/// Media action
enum MediaAction {
  play._('play'),
  pause._('pause'),
  stop._('stop'),
  seek._('seek'),
  seekForward._('seekForward'),
  seekBackward._('seekBackward'),
  skipToNext._('skipToNext'),
  skipToPrevious._('skipToPrevious');

  const MediaAction._(this._name);
  final String _name;
}

/// Audio processing state
enum AudioProcessingState { idle, loading, buffering, ready, completed, error }

/// Playback state
class PlaybackState {
  const PlaybackState({
    this.processingState = AudioProcessingState.idle,
    this.playing = false,
    this.controls = const [],
    this.systemActions = const {},
    this.updatePosition = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.speed = 1.0,
    this.androidCompactActionIndices,
    this.errorMessage,
    this.queueIndex,
  });
  final AudioProcessingState processingState;
  final bool playing;
  final List<MediaControl> controls;
  final Set<MediaAction> systemActions;
  final Duration updatePosition;
  final Duration bufferedPosition;
  final double speed;
  final List<int>? androidCompactActionIndices;
  final String? errorMessage;
  final int? queueIndex;

  PlaybackState copyWith({
    AudioProcessingState? processingState,
    bool? playing,
    List<MediaControl>? controls,
    Set<MediaAction>? systemActions,
    Duration? updatePosition,
    Duration? bufferedPosition,
    double? speed,
    List<int>? androidCompactActionIndices,
    String? errorMessage,
    int? queueIndex,
  }) => PlaybackState(
    processingState: processingState ?? this.processingState,
    playing: playing ?? this.playing,
    controls: controls ?? this.controls,
    systemActions: systemActions ?? this.systemActions,
    updatePosition: updatePosition ?? this.updatePosition,
    bufferedPosition: bufferedPosition ?? this.bufferedPosition,
    speed: speed ?? this.speed,
    androidCompactActionIndices:
        androidCompactActionIndices ?? this.androidCompactActionIndices,
    errorMessage: errorMessage ?? this.errorMessage,
    queueIndex: queueIndex ?? this.queueIndex,
  );
}

/// Base audio handler
abstract class BaseAudioHandler {
  final BehaviorSubject<PlaybackState> playbackState = BehaviorSubject.seeded(
    const PlaybackState(),
  );
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(null);
  final BehaviorSubject<List<MediaItem>> queue = BehaviorSubject.seeded([]);

  Future<void> play() async {}
  Future<void> pause() async {}
  Future<void> stop() async {}
  Future<void> seek(Duration position) async {}
  Future<void> skipToNext() async {}
  Future<void> skipToPrevious() async {}
}

/// Seek handler mixin
mixin SeekHandler on BaseAudioHandler {
  @override
  Future<void> seek(Duration position) async {}
}
