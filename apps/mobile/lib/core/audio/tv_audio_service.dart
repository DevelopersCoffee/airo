import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TV Audio Handler for background playback on Android TV/Fire TV
///
/// This handler manages media session for IPTV video playback, enabling:
/// - Background audio playback when TV home button is pressed
/// - Notification controls (play/pause, stop)
/// - Audio focus management for phone calls/alarms
/// - Media session integration with Android TV
///
/// Usage:
/// ```dart
/// // Initialize once at app startup
/// final handler = await initTvAudioService();
///
/// // Play channel
/// await handler.playChannel(channelName, streamUrl);
///
/// // Handle controls
/// await handler.pause();
/// await handler.play();
/// await handler.stop();
/// ```
class TvAudioHandler extends BaseAudioHandler with SeekHandler {
  /// Current channel name
  String? _currentChannelName;

  /// Current stream URL
  String? _currentStreamUrl;

  /// Current position (for live streams, this is Duration.zero)
  Duration _position = Duration.zero;

  /// Whether currently playing
  bool _isPlaying = false;

  /// Audio focus callback
  VoidCallback? onAudioFocusLost;

  /// Audio focus regained callback
  VoidCallback? onAudioFocusGained;

  TvAudioHandler() {
    _init();
  }

  void _init() {
    // Set initial playback state
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  /// Play a channel with the given name and stream URL
  Future<void> playChannel(String channelName, String streamUrl) async {
    _currentChannelName = channelName;
    _currentStreamUrl = streamUrl;
    _isPlaying = true;

    // Update media item for notification
    mediaItem.add(
      MediaItem(
        id: streamUrl.hashCode.toString(),
        title: channelName,
        artist: 'Live TV',
        album: 'IPTV',
        duration: Duration.zero, // Live stream has no duration
        artUri: null,
        extras: {'url': streamUrl, 'isLive': true},
      ),
    );

    // Update playback state
    _updatePlaybackState(playing: true);
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _updatePlaybackState(playing: true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _updatePlaybackState(playing: false);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentChannelName = null;
    _currentStreamUrl = null;

    // Clear media item
    mediaItem.add(null);

    // Update playback state
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.play],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _updatePlaybackState(playing: _isPlaying);
  }

  void _updatePlaybackState({required bool playing}) {
    playbackState.add(
      PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: _position,
        speed: 1.0,
      ),
    );
  }

  /// Handle audio focus loss (e.g., phone call, alarm)
  void handleAudioFocusLoss() {
    if (_isPlaying) {
      pause();
      onAudioFocusLost?.call();
    }
  }

  /// Handle audio focus gain (e.g., phone call ended)
  void handleAudioFocusGain() {
    onAudioFocusGained?.call();
  }

  /// Current channel name
  String? get currentChannelName => _currentChannelName;

  /// Current stream URL
  String? get currentStreamUrl => _currentStreamUrl;

  /// Whether currently playing
  bool get isPlaying => _isPlaying;

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}

// ============================================================
// Initialization and Providers
// ============================================================

/// Singleton instance of TvAudioHandler
TvAudioHandler? _tvAudioHandler;

/// Initialize the TV audio service - call this once at app startup on TV platforms
///
/// This initializes the foreground service for background playback.
/// Should be called before runApp() on Android TV/Fire TV.
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize TV audio service on TV platforms
///   if (isTvPlatform) {
///     await initTvAudioService();
///   }
///
///   runApp(MyApp());
/// }
/// ```
Future<TvAudioHandler> initTvAudioService() async {
  if (_tvAudioHandler != null) return _tvAudioHandler!;

  _tvAudioHandler = await AudioService.init(
    builder: () => TvAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.airo.app.tv.audio',
      androidNotificationChannelName: 'Airo TV',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false, // Keep notification on pause for TV
      androidNotificationIcon: 'mipmap/ic_launcher',
      // No fast forward/rewind for live TV
      fastForwardInterval: Duration.zero,
      rewindInterval: Duration.zero,
    ),
  );

  return _tvAudioHandler!;
}

/// Check if TV audio service is initialized
bool get isTvAudioServiceInitialized => _tvAudioHandler != null;

/// Provider for TvAudioHandler
/// This requires initTvAudioService() to be called before use on TV platforms
final tvAudioHandlerProvider = Provider<TvAudioHandler?>((ref) {
  return _tvAudioHandler;
});

/// Provider for TV playback state
final tvPlaybackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(tvAudioHandlerProvider);
  if (handler == null) {
    return Stream.value(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
  }
  return handler.playbackState;
});

/// Provider for TV current media item (channel)
final tvCurrentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(tvAudioHandlerProvider);
  if (handler == null) {
    return Stream.value(null);
  }
  return handler.mediaItem;
});

/// Provider for checking if TV is currently playing
final isTvPlayingProvider = Provider<bool>((ref) {
  final playbackState = ref.watch(tvPlaybackStateProvider);
  return playbackState.when(
    data: (state) => state.playing,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Controller for TV audio playback
class TvAudioController {
  final TvAudioHandler _handler;

  TvAudioController(this._handler);

  /// Play a channel
  Future<void> playChannel({
    required String channelName,
    required String streamUrl,
  }) async {
    await _handler.playChannel(channelName, streamUrl);
  }

  /// Pause playback
  Future<void> pause() => _handler.pause();

  /// Resume playback
  Future<void> play() => _handler.play();

  /// Stop playback
  Future<void> stop() => _handler.stop();

  /// Current channel name
  String? get currentChannelName => _handler.currentChannelName;

  /// Whether currently playing
  bool get isPlaying => _handler.isPlaying;

  /// Set audio focus lost callback
  set onAudioFocusLost(VoidCallback? callback) {
    _handler.onAudioFocusLost = callback;
  }

  /// Set audio focus gained callback
  set onAudioFocusGained(VoidCallback? callback) {
    _handler.onAudioFocusGained = callback;
  }
}

/// Provider for TvAudioController (only available when TV audio service is initialized)
final tvAudioControllerProvider = Provider<TvAudioController?>((ref) {
  final handler = ref.watch(tvAudioHandlerProvider);
  if (handler == null) return null;
  return TvAudioController(handler);
});
