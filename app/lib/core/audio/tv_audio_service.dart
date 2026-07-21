import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_media/platform_media.dart';

/// TV Audio Handler for background playback on Android TV/Fire TV
///
/// This handler manages media session for IPTV video playback, enabling:
/// - Background audio playback when TV home button is pressed
/// - Notification controls (play/pause, stop)
/// - Audio focus management for phone calls/alarms
/// - Media session integration with Android TV
///
/// It connects to playback in two directions (#980):
/// - **Reporting:** it implements [StreamingMediaSessionDelegate], so
///   `VideoPlayerStreamingService` tells it what the player did
///   (`onChannelStarted`/`onPlaybackPaused`/`onPlaybackResumed`/
///   `onPlaybackStopped`). These paths only update media-session state —
///   they never fire user-intent callbacks.
/// - **Control:** the `audio_service` overrides ([play]/[pause]/[stop])
///   fire [onUserPlayRequested]/[onUserPauseRequested]/
///   [onUserStopRequested] so notification buttons round-trip back into the
///   streaming service. Transition guards (e.g. [pause] while already
///   paused is a no-op) keep the two directions from recursing.
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
class TvAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements StreamingMediaSessionDelegate {
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

  /// User-intent callbacks, wired by the app shell to the streaming service
  /// so notification / lock-screen buttons actually control playback.
  /// Fired only from the `audio_service` control overrides on genuine
  /// state transitions — never from the [StreamingMediaSessionDelegate]
  /// reporting path, which is what keeps the two directions loop-free.
  VoidCallback? onUserPlayRequested;
  VoidCallback? onUserPauseRequested;
  VoidCallback? onUserStopRequested;

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
    // Guard: resuming an already-playing session is a no-op. Without this,
    // the reporting path (delegate.onPlaybackResumed -> play()) and the
    // control path (notification play -> onUserPlayRequested ->
    // service.resume() -> delegate) would keep re-triggering each other.
    if (_isPlaying) return;
    _applyPlayState();
    onUserPlayRequested?.call();
  }

  @override
  Future<void> pause() async {
    // Guard: see play().
    if (!_isPlaying) return;
    _applyPauseState();
    onUserPauseRequested?.call();
  }

  @override
  Future<void> stop() async {
    // Guard: stopping an already-idle session is a no-op (see play()).
    if (!_isPlaying && _currentStreamUrl == null) return;
    await _applyStopState();
    onUserStopRequested?.call();
  }

  // -----------------------------------------------------------------------
  // StreamingMediaSessionDelegate — reporting path.
  //
  // These are called by VideoPlayerStreamingService when *it* transitions.
  // They update media-session state only and deliberately do NOT fire the
  // onUser* callbacks: the player is the source of truth here, calling back
  // into it would be redundant (and, without the guards above, recursive).
  // -----------------------------------------------------------------------

  @override
  Future<void> onChannelStarted({
    required String channelName,
    required String streamUrl,
  }) => playChannel(channelName, streamUrl);

  @override
  Future<void> onPlaybackPaused() async => _applyPauseState();

  @override
  Future<void> onPlaybackResumed() async => _applyPlayState();

  @override
  Future<void> onPlaybackStopped() => _applyStopState();

  void _applyPlayState() {
    _isPlaying = true;
    _updatePlaybackState(playing: true);
  }

  void _applyPauseState() {
    _isPlaying = false;
    _updatePlaybackState(playing: false);
  }

  Future<void> _applyStopState() async {
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
      // Keep the foreground service (and its notification) alive on pause —
      // live-TV users pause for long stretches and must keep lock-screen
      // controls. androidNotificationOngoing stays false: audio_service
      // asserts it can't be true while stopForegroundOnPause is false.
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
      // fastForwardInterval/rewindInterval keep audio_service's defaults
      // (must be > Duration.zero per its asserts); the intervals are
      // inert because live TV exposes no fast-forward/rewind controls.
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
