import 'dart:async';
import 'package:video_player/video_player.dart';
import '../models/streaming_state.dart';

/// Live Edge Detection Service (P0-1, P0-2, P0-3)
///
/// Monitors video player to detect:
/// - Whether stream is live vs VOD
/// - Current live edge position
/// - Delay from live edge
/// - DVR window boundaries
/// - Drift for auto-resync
class LiveEdgeDetector {
  final LiveEdgeConfig _config;
  Timer? _updateTimer;
  VideoPlayerController? _controller;

  // Callbacks
  void Function(LiveEdgeState)? onStateUpdate;
  void Function()? onDriftDetected;

  // Internal tracking
  DateTime? _lastUserSeek;
  Duration _lastKnownPosition = Duration.zero;

  LiveEdgeDetector({LiveEdgeConfig? config})
    : _config = config ?? LiveEdgeConfig.defaultConfig;

  /// Attach to a video player controller
  void attach(VideoPlayerController controller) {
    _controller = controller;
    _startMonitoring();
  }

  /// Detach from current controller
  void detach() {
    _stopMonitoring();
    _controller = null;
  }

  void _startMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_config.updateInterval, (_) {
      _updateLiveEdgeState();
    });
  }

  void _stopMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Calculate current live edge state
  void _updateLiveEdgeState() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final value = _controller!.value;
    final position = value.position;
    final duration = value.duration;

    // Detect if this is a live stream (P0-1)
    final isLive = _detectLiveStream(duration, position);

    if (!isLive) {
      // VOD content - no live edge tracking needed
      onStateUpdate?.call(LiveEdgeState.vod());
      return;
    }

    // Calculate live edge (P0-2)
    final liveEdge = _calculateLiveEdge(duration, value.buffered);

    // Calculate delay from live (P0-3)
    final delay = liveEdge - position;

    // Determine live stream state (P0-4)
    final liveState = _determineLiveState(delay, value.isPlaying);

    // Check for drift (auto-resync trigger)
    _checkForDrift(delay);

    // Detect DVR window
    final dvrWindow = _detectDvrWindow(value.buffered, position);

    _lastKnownPosition = position;

    onStateUpdate?.call(
      LiveEdgeState(
        isLiveStream: true,
        liveEdge: liveEdge,
        liveDelay: delay,
        liveStreamState: liveState,
        hasDvrSupport: dvrWindow.hasDvr,
        dvrWindowStart: dvrWindow.start,
        dvrWindowDuration: dvrWindow.duration,
      ),
    );
  }

  /// Detect if stream is live vs VOD (P0-1)
  ///
  /// Heuristics:
  /// 1. Duration is zero or very large (indicates live)
  /// 2. Duration keeps increasing (live EVENT playlist)
  /// 3. Stream URL patterns (optional enhancement)
  bool _detectLiveStream(Duration duration, Duration position) {
    // Zero duration often indicates live stream
    if (duration == Duration.zero) return true;

    // Very large duration (>24 hours) likely indicates live
    if (duration.inHours > 24) return true;

    // Duration close to position with small buffer suggests live
    // (VOD would have full duration known upfront)
    if (duration.inSeconds > 0 &&
        (duration - position).inSeconds < 60 &&
        duration.inMinutes < 10) {
      return true;
    }

    // Default to VOD for known durations
    return false;
  }

  /// Calculate live edge position (P0-2)
  Duration _calculateLiveEdge(Duration duration, List<DurationRange> buffered) {
    // For live streams, live edge is typically the end of buffered range
    // or the reported duration (whichever is greater)
    Duration maxBuffered = Duration.zero;
    for (final range in buffered) {
      if (range.end > maxBuffered) {
        maxBuffered = range.end;
      }
    }

    // Use the greater of duration or max buffered position
    return duration > maxBuffered ? duration : maxBuffered;
  }

  /// Determine the current live stream state (P0-4)
  LiveStreamState _determineLiveState(Duration delay, bool isPlaying) {
    if (!isPlaying) return LiveStreamState.paused;

    if (delay.inSeconds <= _config.liveEdgeThreshold.inSeconds) {
      return LiveStreamState.live;
    }

    return LiveStreamState.behindLive;
  }

  /// Check for drift and trigger auto-resync callback
  void _checkForDrift(Duration delay) {
    // Only check if no recent user seek
    if (_lastUserSeek != null) {
      final timeSinceSeek = DateTime.now().difference(_lastUserSeek!);
      if (timeSinceSeek < const Duration(seconds: 10)) return;
    }

    if (delay > _config.autoResyncThreshold) {
      onDriftDetected?.call();
    }
  }

  /// Detect DVR window boundaries
  _DvrWindow _detectDvrWindow(List<DurationRange> buffered, Duration position) {
    if (buffered.isEmpty) {
      return _DvrWindow(hasDvr: false);
    }

    // Find the buffered range containing current position
    Duration? start;
    Duration? end;

    for (final range in buffered) {
      if (start == null || range.start < start) start = range.start;
      if (end == null || range.end > end) end = range.end;
    }

    if (start != null && end != null) {
      final duration = end - start;
      // DVR is supported if we have more than 30s of buffered range
      return _DvrWindow(
        hasDvr: duration.inSeconds > 30,
        start: start,
        duration: duration,
      );
    }

    return _DvrWindow(hasDvr: false);
  }

  /// Notify that user performed a manual seek
  void notifyUserSeek() {
    _lastUserSeek = DateTime.now();
  }

  /// Dispose resources
  void dispose() {
    _stopMonitoring();
    _controller = null;
    onStateUpdate = null;
    onDriftDetected = null;
  }
}

/// Result of live edge detection
class LiveEdgeState {
  final bool isLiveStream;
  final Duration liveEdge;
  final Duration liveDelay;
  final LiveStreamState liveStreamState;
  final bool hasDvrSupport;
  final Duration? dvrWindowStart;
  final Duration? dvrWindowDuration;

  const LiveEdgeState({
    required this.isLiveStream,
    this.liveEdge = Duration.zero,
    this.liveDelay = Duration.zero,
    this.liveStreamState = LiveStreamState.unknown,
    this.hasDvrSupport = false,
    this.dvrWindowStart,
    this.dvrWindowDuration,
  });

  /// Factory for VOD content (not live)
  factory LiveEdgeState.vod() => const LiveEdgeState(isLiveStream: false);
}

/// Internal DVR window detection result
class _DvrWindow {
  final bool hasDvr;
  final Duration? start;
  final Duration? duration;

  const _DvrWindow({required this.hasDvr, this.start, this.duration});
}
