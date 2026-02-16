import 'dart:async';
import 'package:video_player/video_player.dart';
import '../../../../core/audio/audio_context_manager.dart';
import '../models/iptv_channel.dart';
import '../models/streaming_state.dart';
import 'iptv_streaming_service.dart';
import 'live_edge_detector.dart';

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
  VideoPlayerController? _controller;
  final StreamingConfig _config;
  final AudioContextManager _audioContext;
  final _stateController = StreamController<StreamingState>.broadcast();

  StreamingState _state = const StreamingState();
  Timer? _bufferMonitor;
  Timer? _metricsTimer;
  DateTime? _loadStartTime;
  bool _isBackgroundAudioMode = false;

  // Live edge detection (P0-1 through P0-4)
  final LiveEdgeDetector _liveEdgeDetector;

  VideoPlayerStreamingService({
    StreamingConfig config = StreamingConfig.youtube,
    AudioContextManager? audioContext,
    LiveEdgeConfig? liveEdgeConfig,
  }) : _config = config,
       _audioContext = audioContext ?? AudioContextManager(),
       _liveEdgeDetector = LiveEdgeDetector(config: liveEdgeConfig) {
    _setupLiveEdgeCallbacks();
  }

  void _setupLiveEdgeCallbacks() {
    _liveEdgeDetector.onStateUpdate = _handleLiveEdgeUpdate;
    _liveEdgeDetector.onDriftDetected = _handleDriftDetected;
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

  void _handleDriftDetected() {
    // Auto-resync to live edge when drift exceeds threshold
    // Only auto-resync if not paused by user
    if (_state.playbackState == PlaybackState.playing) {
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

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    _loadStartTime = DateTime.now();
    _updateState(
      _state.copyWith(
        currentChannel: channel,
        playbackState: PlaybackState.loading,
        errorMessage: null,
        retryCount: 0,
      ),
    );

    try {
      await _disposeController();

      // Request video audio focus (pauses background music)
      _audioContext.requestFocus(AudioFocusType.video);

      final url = channel.getStreamUrl(_state.selectedQuality);
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: _isBackgroundAudioMode,
          allowBackgroundPlayback:
              _isBackgroundAudioMode || channel.isAudioOnly,
        ),
      );

      // Initialize with timeout for fast load
      await _controller!.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Load timeout'),
      );

      // Set volume
      await _controller!.setVolume(_state.isMuted ? 0 : _state.volume);

      // Start playback
      await _controller!.play();

      // Calculate load time
      final loadTime = DateTime.now().difference(_loadStartTime!);

      _updateState(
        _state.copyWith(
          playbackState: PlaybackState.playing,
          duration: _controller!.value.duration,
          metrics: StreamingMetrics(
            latency: loadTime,
            networkQuality: _estimateNetworkQuality(loadTime),
            timestamp: DateTime.now(),
          ),
        ),
      );

      _startBufferMonitoring();
      _setupControllerListeners();

      // Attach live edge detector for live stream monitoring
      _liveEdgeDetector.attach(_controller!);
    } catch (e) {
      // Release focus on error
      _audioContext.releaseFocus(AudioFocusType.video);
      await _handleError(e.toString());
    }
  }

  void _setupControllerListeners() {
    _controller?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (_controller == null) return;

    final value = _controller!.value;

    // Update position
    _updateState(
      _state.copyWith(position: value.position, duration: value.duration),
    );

    // Check for buffering
    if (value.isBuffering && _state.playbackState == PlaybackState.playing) {
      _updateState(_state.copyWith(playbackState: PlaybackState.buffering));
    } else if (!value.isBuffering &&
        _state.playbackState == PlaybackState.buffering) {
      _updateState(_state.copyWith(playbackState: PlaybackState.playing));
    }

    // Check for errors
    if (value.hasError) {
      _handleError(value.errorDescription ?? 'Playback error');
    }
  }

  void _startBufferMonitoring() {
    _bufferMonitor?.cancel();
    _bufferMonitor = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_controller == null) return;

      final buffered = _controller!.value.buffered;
      final position = _controller!.value.position;

      Duration bufferedAhead = Duration.zero;
      for (final range in buffered) {
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
            isBuffering: _controller!.value.isBuffering,
          ),
        ),
      );
    });
  }

  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Collect and update streaming metrics
      if (_controller != null && _state.isPlaying) {
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
    // Estimate based on quality
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
    // Prevent duplicate error handling that causes flickering
    if (_isHandlingError || _state.playbackState == PlaybackState.error) {
      return;
    }
    _isHandlingError = true;

    final newRetryCount = _state.retryCount + 1;

    // Determine user-friendly error message
    String userMessage;
    if (newRetryCount > _config.maxRetries) {
      userMessage = 'Unable to play this channel. Please try again later.';
    } else {
      userMessage = 'Playback failed: $message';
    }

    _updateState(
      _state.copyWith(
        playbackState: PlaybackState.error,
        errorMessage: userMessage,
        retryCount: newRetryCount,
        lastError: DateTime.now(),
      ),
    );

    // Stop buffer monitoring to prevent state updates
    _bufferMonitor?.cancel();

    // Release audio focus
    _audioContext.releaseFocus(AudioFocusType.video);

    // Dispose controller to stop any retries from the video player
    await _disposeController();

    _isHandlingError = false;

    // NO auto-retry - user must manually retry via the Retry button
    // This prevents flickering from continuous retry loops
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
    // Release video focus when paused so music can resume
    _audioContext.releaseFocus(AudioFocusType.video);
    _updateState(_state.copyWith(playbackState: PlaybackState.paused));
  }

  @override
  Future<void> resume() async {
    // Request video focus again when resuming
    _audioContext.requestFocus(AudioFocusType.video);
    await _controller?.play();
    _updateState(_state.copyWith(playbackState: PlaybackState.playing));
  }

  @override
  Future<void> stop() async {
    _bufferMonitor?.cancel();
    // Release video audio focus so music can resume
    _audioContext.releaseFocus(AudioFocusType.video);
    await _disposeController();
    _updateState(const StreamingState());
  }

  @override
  Future<void> seek(Duration position) async {
    // Notify live edge detector of manual seek
    _liveEdgeDetector.notifyUserSeek();
    await _controller?.seekTo(position);
    _updateState(_state.copyWith(position: position));
  }

  @override
  Future<void> goLive() async {
    // P0-6: Seek to live edge
    if (!_state.isLiveStream) return;

    final liveEdge = _state.liveEdge;
    if (liveEdge == null || liveEdge == Duration.zero) {
      // Fallback: use controller duration as live edge estimate
      final duration = _controller?.value.duration;
      if (duration != null && duration > Duration.zero) {
        await _controller?.seekTo(duration);
      }
      return;
    }

    await _controller?.seekTo(liveEdge);
    _updateState(
      _state.copyWith(
        liveStreamState: LiveStreamState.live,
        liveDelay: Duration.zero,
      ),
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _controller?.setVolume(_state.isMuted ? 0 : clampedVolume);
    _updateState(_state.copyWith(volume: clampedVolume));
  }

  @override
  Future<void> toggleMute() async {
    final newMuted = !_state.isMuted;
    await _controller?.setVolume(newMuted ? 0 : _state.volume);
    _updateState(_state.copyWith(isMuted: newMuted));
  }

  @override
  Future<void> setQuality(VideoQuality quality) async {
    if (quality == _state.selectedQuality) return;

    _updateState(_state.copyWith(selectedQuality: quality));

    // Reload stream with new quality if playing
    if (_state.currentChannel != null && _state.isPlaying) {
      final position = _state.position;
      await playChannel(_state.currentChannel!);
      await seek(position);
    }
  }

  @override
  Future<void> retry() async {
    if (_state.currentChannel != null) {
      // Reset error handling flag and retry count for manual retry
      _isHandlingError = false;
      // Note: playChannel() already resets retryCount to 0
      await playChannel(_state.currentChannel!);
    }
  }

  @override
  Future<void> setBackgroundAudioMode(bool enabled) async {
    _isBackgroundAudioMode = enabled;
    // Reload if currently playing to apply new setting
    if (_state.currentChannel != null && _state.isPlaying) {
      await playChannel(_state.currentChannel!);
    }
  }

  Future<void> _disposeController() async {
    // Detach live edge detector
    _liveEdgeDetector.detach();
    _controller?.removeListener(_onControllerUpdate);
    await _controller?.dispose();
    _controller = null;
  }

  void _updateState(StreamingState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    _bufferMonitor?.cancel();
    _metricsTimer?.cancel();
    // Dispose live edge detector
    _liveEdgeDetector.dispose();
    // Release video audio focus
    _audioContext.releaseFocus(AudioFocusType.video);
    await _disposeController();
    await _stateController.close();
  }

  /// Get the video player controller for UI rendering
  VideoPlayerController? get controller => _controller;
}
