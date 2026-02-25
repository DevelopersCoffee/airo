/// Stub implementation of audio_service for TV builds
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

/// Audio Service for background playback
class AudioService {
  static Future<T> init<T extends BaseAudioHandler>({
    required T Function() builder,
    AudioServiceConfig config = const AudioServiceConfig(),
  }) async {
    return builder();
  }
}

/// Audio Service configuration
class AudioServiceConfig {
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
}

/// Media item
class MediaItem {
  final String id;
  final String title;
  final String? album;
  final String? artist;
  final Uri? artUri;
  final Duration? duration;
  final Map<String, dynamic>? extras;

  const MediaItem({
    required this.id,
    required this.title,
    this.album,
    this.artist,
    this.artUri,
    this.duration,
    this.extras,
  });
}

/// Media control button
class MediaControl {
  static const MediaControl play = MediaControl._('play');
  static const MediaControl pause = MediaControl._('pause');
  static const MediaControl stop = MediaControl._('stop');
  static const MediaControl skipToNext = MediaControl._('skipToNext');
  static const MediaControl skipToPrevious = MediaControl._('skipToPrevious');
  static const MediaControl rewind = MediaControl._('rewind');
  static const MediaControl fastForward = MediaControl._('fastForward');

  final String _name;
  const MediaControl._(this._name);
}

/// Media action
class MediaAction {
  static const MediaAction play = MediaAction._('play');
  static const MediaAction pause = MediaAction._('pause');
  static const MediaAction stop = MediaAction._('stop');
  static const MediaAction seek = MediaAction._('seek');
  static const MediaAction seekForward = MediaAction._('seekForward');
  static const MediaAction seekBackward = MediaAction._('seekBackward');
  static const MediaAction skipToNext = MediaAction._('skipToNext');
  static const MediaAction skipToPrevious = MediaAction._('skipToPrevious');

  final String _name;
  const MediaAction._(this._name);
}

/// Audio processing state
enum AudioProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

/// Playback state
class PlaybackState {
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
  }) {
    return PlaybackState(
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
}

/// Base audio handler
abstract class BaseAudioHandler {
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject.seeded(const PlaybackState());
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
