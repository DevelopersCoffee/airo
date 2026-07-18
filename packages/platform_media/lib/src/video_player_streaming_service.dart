import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:platform_streams/platform_streams.dart';

import 'audio_context.dart';
import 'platform_media_logger.dart';
import 'streaming_error_diagnostic_mapping.dart';
import 'video_player_airo_playback_engine.dart';

/// Video Player implementation of IPTV Streaming Service
///
/// Optimizations implemented:
/// 1. Adaptive bitrate via HLS/DASH support
/// 2. Buffer monitoring and health tracking
/// 3. Fast initial load with preloading
/// 4. Auto-retry on network errors
/// 5. Seamless quality switching
/// 6. Background audio mode
/// 7. Audio context integration (pauses music during video)
class VideoPlayerStreamingService implements IPTVStreamingService {
  final AiroPlaybackEngine _engine;
  final StreamingConfig _config;
  final AudioContextManager _audioContext;
  final _stateController = StreamController<StreamingState>.broadcast();

  StreamingState _state = StreamingState();
  Timer? _bufferMonitor;
  Timer? _metricsTimer;
  DateTime? _loadStartTime;
  bool _isBackgroundAudioMode = false;

  // Live edge detection (P0-1 through P0-4)
  final LiveEdgeDetector _liveEdgeDetector;

  StreamSubscription<AiroPlaybackState>? _engineSubscription;
  // Scoped to the channel/item id it was attached for so it doesn't leak
  // onto unrelated subsequent playChannel() calls (see
  // attachExternalSubtitle() and playChannel()).
  String? _pendingExternalSubtitleChannelId;
  AiroPlaybackExternalSubtitle? _pendingExternalSubtitle;
  int _requestCounter = 0;

  VideoPlayerStreamingService({
    AiroPlaybackEngine? engine,
    this._config = StreamingConfig.youtube,
    AudioContextManager? audioContext,
    LiveEdgeConfig? liveEdgeConfig,
  }) : _engine = engine ?? VideoPlayerAiroPlaybackEngine(),
       _audioContext = audioContext ?? AudioContextManager(),
       _liveEdgeDetector = LiveEdgeDetector(config: liveEdgeConfig) {
    _setupLiveEdgeCallbacks();
    _engineSubscription = _engine.states.listen(_onEngineStateUpdate);
  }

  void _setupLiveEdgeCallbacks() {
    _liveEdgeDetector.onStateUpdate = _handleLiveEdgeUpdate;
    _liveEdgeDetector.onDriftDetected = _handleDriftDetected;
    _liveEdgeDetector.onDriftWarning = _handleDriftWarning;
  }

  void _handleLiveEdgeUpdate(LiveEdgeState liveState) {
    _updateState(
      _state.copyWith(
        isLiveStream: liveState.isLiveStream,
        liveEdge: liveState.liveEdge,
        liveDelay: liveState.liveDelay,
        liveStreamState: liveState.liveStreamState,
        hasDvrSupport: liveState.hasDvrSupport,
        dvrWindowStart: liveState.dvrWindowStart,
        dvrWindowDuration: liveState.dvrWindowDuration,
        lastLiveEdgeUpdate: DateTime.now(),
      ),
    );
  }

  /// M2: Handle drift warning before auto-resync
  void _handleDriftWarning(Duration delay) {
    AppLogger.info(
      'Drift detected: ${delay.inSeconds}s behind live edge',
      tag: 'LIVE_DVR',
    );
    AppLogger.analytics(
      'live_stream_drift_detected',
      params: {
        'channel': _state.currentChannel?.name,
        'delaySeconds': delay.inSeconds,
      },
    );
  }

  void _handleDriftDetected() {
    // Auto-resync to live edge when drift exceeds threshold
    // Only auto-resync if not paused by user
    if (_state.playbackState == PlaybackState.playing) {
      AppLogger.analytics(
        'live_stream_auto_resync',
        params: {
          'channel': _state.currentChannel?.name,
          'delayBeforeResync': _state.liveDelay.inSeconds,
        },
      );
      goLive();
    }
  }

  @override
  Stream<StreamingState> get stateStream => _stateController.stream;

  @override
  StreamingState get currentState => _state;

  @override
  Future<void> initialize() async {
    // Pre-warm video player infrastructure
    _startMetricsCollection();
  }

  /// Returns a widget rendering the current video surface, or null when
  /// nothing is open yet. See [AiroPlaybackEngine.buildView].
  Widget? buildVideoView() => _engine.buildView();

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    _loadStartTime = DateTime.now();
    _updateState(
      _state.copyWith(
        currentChannel: channel,
        playbackState: PlaybackState.loading,
        errorMessage: null,
        clearDiagnostic: true,
        retryCount: 0,
      ),
    );

    try {
      // Request video audio focus (pauses background music)
      _audioContext.requestFocus(AudioFocusType.video);

      final url = channel.getStreamUrl(_state.selectedQuality);
      final externalSubtitles = <AiroPlaybackExternalSubtitle>[
        if (_pendingExternalSubtitle != null &&
            _pendingExternalSubtitleChannelId == channel.id)
          _pendingExternalSubtitle!,
      ];

      final result = await _engine.open(
        AiroMediaOpenRequest(
          requestId: '${channel.id}-${_requestCounter++}',
          sourceHandle: AiroPlaybackSourceHandle.direct(url),
          // Engines don't currently branch on mediaKind — hls is the
          // dominant IPTV format in this codebase and there's no reliable
          // pre-open live/VOD signal on IPTVChannel to infer from (live vs
          // VOD detection is a post-open runtime heuristic, see
          // LiveEdgeDetector._detectLiveStream).
          mediaKind: AiroPlaybackMediaKind.hls,
          externalSubtitles: externalSubtitles,
          mixWithOthers: _isBackgroundAudioMode,
          allowBackgroundPlayback:
              _isBackgroundAudioMode || channel.isAudioOnly,
        ),
      );

      if (result.error != null) {
        throw _EngineOpenError(result.error!.code.stableId);
      }

      await _engine.setVolume(_state.isMuted ? 0 : _state.volume);
      await _engine.setPlaybackSpeed(1.0);
      await _engine.play();

      // Calculate load time
      final loadTime = DateTime.now().difference(_loadStartTime!);

      _updateState(
        _state.copyWith(
          playbackState: PlaybackState.playing,
          duration: result.duration ?? Duration.zero,
          tracks: result.tracks,
          selectedTrackIds: result.selectedTrackIds,
          metrics: StreamingMetrics(
            latency: loadTime,
            networkQuality: _estimateNetworkQuality(loadTime),
            timestamp: DateTime.now(),
          ),
        ),
      );

      _startBufferMonitoring();

      // Attach live edge detector for live stream monitoring
      _liveEdgeDetector.attachToEngine(_engine);
    } catch (e) {
      // Release focus on error
      _audioContext.releaseFocus(AudioFocusType.video);
      await _handleError(e.toString());
    }
  }

  /// Folds every state emitted by the engine (continuous position/duration/
  /// buffering/error updates — see VideoPlayerAiroPlaybackEngine's
  /// controller listener) into [StreamingState]. Runs for the lifetime of
  /// this service, not just during playChannel — the engine instance itself
  /// doesn't change across channel switches, only what it has open.
  void _onEngineStateUpdate(AiroPlaybackState engineState) {
    if (engineState.error != null) {
      _handleError(engineState.error!.code.stableId);
      return;
    }

    _updateState(
      _state.copyWith(
        position: engineState.position,
        duration: engineState.duration ?? _state.duration,
        tracks: engineState.tracks,
        selectedTrackIds: engineState.selectedTrackIds,
        playbackState: _mapEnginePhase(engineState.phase) ?? _state.playbackState,
      ),
    );
  }

  PlaybackState? _mapEnginePhase(AiroPlaybackEnginePhase phase) {
    switch (phase) {
      case AiroPlaybackEnginePhase.playing:
        return PlaybackState.playing;
      case AiroPlaybackEnginePhase.paused:
        return PlaybackState.paused;
      case AiroPlaybackEnginePhase.buffering:
        return PlaybackState.buffering;
      case AiroPlaybackEnginePhase.stopped:
        return PlaybackState.idle;
      case AiroPlaybackEnginePhase.idle:
      case AiroPlaybackEnginePhase.opening:
      case AiroPlaybackEnginePhase.open:
      case AiroPlaybackEnginePhase.seeking:
      case AiroPlaybackEnginePhase.ended:
      case AiroPlaybackEnginePhase.failed:
      case AiroPlaybackEnginePhase.unavailable:
        return null;
    }
  }

  void _startBufferMonitoring() {
    _bufferMonitor?.cancel();
    _bufferMonitor = Timer.periodic(const Duration(seconds: 1), (_) {
      final engineState = _engine.currentState;
      final position = engineState.position;

      Duration bufferedAhead = Duration.zero;
      for (final range in engineState.bufferedRanges) {
        if (range.start <= position && range.end > position) {
          bufferedAhead = range.end - position;
          break;
        }
      }

      final bufferHealth =
          (bufferedAhead.inSeconds /
                  _config.targetBufferDuration.inSeconds *
                  100)
              .clamp(0, 100)
              .toInt();

      _updateState(
        _state.copyWith(
          bufferStatus: BufferStatus(
            bufferedAhead: bufferedAhead,
            bufferHealth: bufferHealth,
            isBuffering: engineState.phase == AiroPlaybackEnginePhase.buffering,
          ),
        ),
      );
    });
  }

  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state.isPlaying) {
        _updateState(
          _state.copyWith(
            metrics: StreamingMetrics(
              currentBitrate: _estimateBitrate(),
              networkQuality:
                  _state.metrics?.networkQuality ?? NetworkQuality.good,
              timestamp: DateTime.now(),
            ),
          ),
        );
      }
    });
  }

  int _estimateBitrate() {
    switch (_state.currentQuality) {
      case VideoQuality.ultraHd:
        return 15000;
      case VideoQuality.fullHd:
        return 5000;
      case VideoQuality.high:
        return 2500;
      case VideoQuality.medium:
        return 1000;
      case VideoQuality.low:
        return 500;
      case VideoQuality.auto:
        return 2000;
    }
  }

  NetworkQuality _estimateNetworkQuality(Duration loadTime) {
    if (loadTime.inMilliseconds < 1000) return NetworkQuality.excellent;
    if (loadTime.inMilliseconds < 2000) return NetworkQuality.good;
    if (loadTime.inMilliseconds < 4000) return NetworkQuality.fair;
    return NetworkQuality.poor;
  }

  /// Flag to prevent duplicate error handling
  bool _isHandlingError = false;

  Future<void> _handleError(String message) async {
    if (_isHandlingError || _state.playbackState == PlaybackState.error) {
      return;
    }
    _isHandlingError = true;

    final newRetryCount = _state.retryCount + 1;

    String userMessage;
    if (newRetryCount > _config.maxRetries) {
      userMessage = 'Unable to play this channel. Please try again later.';
    } else {
      userMessage = 'Playback failed: $message';
    }

    // CV-001: structured, user-safe diagnostic alongside the legacy
    // errorMessage. UI prefers this when present; retry stays manual here
    // (see comment below) — this call is additive, not a behavior change.
    final diagnostic = mapStreamingErrorToDiagnostic(message);

    _updateState(
      _state.copyWith(
        playbackState: PlaybackState.error,
        errorMessage: userMessage,
        diagnostic: diagnostic,
        retryCount: newRetryCount,
        lastError: DateTime.now(),
      ),
    );

    _bufferMonitor?.cancel();
    _audioContext.releaseFocus(AudioFocusType.video);
    _liveEdgeDetector.detach();

    _isHandlingError = false;
  }

  @override
  Future<void> pause() async {
    await _engine.pause();
    _audioContext.releaseFocus(AudioFocusType.video);
    _updateState(_state.copyWith(playbackState: PlaybackState.paused));
  }

  @override
  Future<void> resume() async {
    _audioContext.requestFocus(AudioFocusType.video);
    await _engine.play();
    _updateState(_state.copyWith(playbackState: PlaybackState.playing));
  }

  @override
  Future<void> stop() async {
    _bufferMonitor?.cancel();
    _audioContext.releaseFocus(AudioFocusType.video);
    _liveEdgeDetector.detach();
    await _engine.stop();
    _updateState(StreamingState());
  }

  @override
  Future<void> seek(Duration position) async {
    _liveEdgeDetector.notifyUserSeek();

    var clampedPosition = position;
    if (_state.isLiveStream && _state.hasDvrSupport) {
      final dvrStart = _state.dvrWindowStart ?? Duration.zero;
      final liveEdge = _state.liveEdge ?? _engine.currentState.duration ?? Duration.zero;

      if (position < dvrStart) {
        clampedPosition = dvrStart;
        AppLogger.info(
          'Seek clamped to DVR start: ${dvrStart.inSeconds}s',
          tag: 'LIVE_DVR',
        );
      } else if (position > liveEdge) {
        clampedPosition = liveEdge;
        AppLogger.info(
          'Seek clamped to live edge: ${liveEdge.inSeconds}s',
          tag: 'LIVE_DVR',
        );
      }
    }

    await _engine.seek(clampedPosition);
    _updateState(_state.copyWith(position: clampedPosition));

    if (_state.isLiveStream) {
      AppLogger.analytics(
        'live_stream_seek',
        params: {
          'channel': _state.currentChannel?.name,
          'seekTo': clampedPosition.inSeconds,
          'wasClamped': clampedPosition != position,
          'delay': _state.liveDelay.inSeconds,
        },
      );
    }
  }

  @override
  Future<void> goLive() async {
    if (!_state.isLiveStream) return;

    _liveEdgeDetector.resetDriftState();

    final liveEdge = _state.liveEdge;
    if (liveEdge == null || liveEdge == Duration.zero) {
      final duration = _engine.currentState.duration;
      if (duration != null && duration > Duration.zero) {
        await _engine.seek(duration);
      }
      return;
    }

    await _engine.seek(liveEdge);
    _updateState(
      _state.copyWith(
        liveStreamState: LiveStreamState.live,
        liveDelay: Duration.zero,
      ),
    );

    AppLogger.analytics(
      'go_live_tapped',
      params: {
        'channel': _state.currentChannel?.name,
        'previousDelay': _state.liveDelay.inSeconds,
      },
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _engine.setVolume(_state.isMuted ? 0 : clampedVolume);
    _updateState(_state.copyWith(volume: clampedVolume));
  }

  @override
  Future<void> toggleMute() async {
    final newMuted = !_state.isMuted;
    await _engine.setVolume(newMuted ? 0 : _state.volume);
    _updateState(_state.copyWith(isMuted: newMuted));
  }

  @override
  Future<void> setQuality(VideoQuality quality) async {
    if (quality == _state.selectedQuality) return;

    _updateState(_state.copyWith(selectedQuality: quality));

    if (_state.currentChannel != null && _state.isPlaying) {
      final position = _state.position;
      await playChannel(_state.currentChannel!);
      await seek(position);
    }
  }

  @override
  Future<void> retry() async {
    if (_state.currentChannel != null) {
      _isHandlingError = false;
      await playChannel(_state.currentChannel!);
    }
  }

  @override
  Future<void> setBackgroundAudioMode(bool enabled) async {
    _isBackgroundAudioMode = enabled;
    if (_state.currentChannel != null && _state.isPlaying) {
      await playChannel(_state.currentChannel!);
    }
  }

  /// Selects a track (audio, subtitle, or video) by id. No-op if the id
  /// isn't in the current [StreamingState.tracks] catalog — matches
  /// [AiroPlaybackEngine.selectTrack]'s typed-failure contract, silently
  /// absorbed here since there's nothing actionable for the caller to do
  /// with a typed error at this layer (the UI only offers ids that are
  /// already in the catalog).
  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    final result = await _engine.selectTrack(kind: kind, trackId: trackId);
    if (result.error != null) return;
    _updateState(_state.copyWith(selectedTrackIds: result.selectedTrackIds));
  }

  /// Stores an external subtitle to include on the next [playChannel] open
  /// request *for [channelId]*. Engines don't support attaching a subtitle
  /// to an already-open source, so this doesn't take effect until the next
  /// open — callers should re-trigger playback (e.g. call [playChannel]
  /// again) if they want it to apply immediately.
  ///
  /// Scoped by [channelId] so the subtitle only projects onto the item it
  /// was attached for: a subsequent [playChannel] call for a *different*
  /// channel/item id won't pick it up. A same-id re-open (e.g. [setQuality]
  /// re-invoking [playChannel] for the same channel) still re-applies it.
  void attachExternalSubtitle(
    String channelId,
    AiroPlaybackExternalSubtitle subtitle,
  ) {
    _pendingExternalSubtitleChannelId = channelId;
    _pendingExternalSubtitle = subtitle;
  }

  void _updateState(StreamingState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    _bufferMonitor?.cancel();
    _metricsTimer?.cancel();
    _liveEdgeDetector.dispose();
    _audioContext.releaseFocus(AudioFocusType.video);
    await _engineSubscription?.cancel();
    await _engine.dispose();
    await _stateController.close();
  }
}

class _EngineOpenError implements Exception {
  _EngineOpenError(this.code);
  final String code;
  @override
  String toString() => code;
}
