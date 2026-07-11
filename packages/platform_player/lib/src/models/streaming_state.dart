import 'package:equatable/equatable.dart';
import 'iptv_channel.dart';

/// Network quality indicator
enum NetworkQuality {
  excellent(4, 'Excellent'),
  good(3, 'Good'),
  fair(2, 'Fair'),
  poor(1, 'Poor'),
  offline(0, 'Offline');

  const NetworkQuality(this.level, this.label);
  final int level;
  final String label;
}

/// Playback state
enum PlaybackState { idle, loading, buffering, playing, paused, error, ended }

/// Live stream state for DVR functionality (P0-4)
/// Tracks whether user is at live edge or behind
enum LiveStreamState {
  /// At or near live edge (delay <= threshold)
  live('LIVE'),

  /// Behind live edge (delay > threshold)
  behindLive('BEHIND_LIVE'),

  /// Stream is paused
  paused('PAUSED'),

  /// Playing within DVR window (not at live edge)
  dvrPlayback('DVR_PLAYBACK'),

  /// Stream type unknown or VOD content
  unknown('UNKNOWN');

  const LiveStreamState(this.label);
  final String label;
}

/// Configuration for live edge detection thresholds
class LiveEdgeConfig {
  /// Delay threshold to consider "at live edge" (default: 3 seconds)
  final Duration liveEdgeThreshold;

  /// Delay threshold for auto-resync (default: 30 seconds)
  final Duration autoResyncThreshold;

  /// Update interval for live edge detection (default: 1 second)
  final Duration updateInterval;

  const LiveEdgeConfig({
    this.liveEdgeThreshold = const Duration(seconds: 3),
    this.autoResyncThreshold = const Duration(seconds: 30),
    this.updateInterval = const Duration(seconds: 1),
  });

  static const defaultConfig = LiveEdgeConfig();
}

/// Buffer status for streaming
class BufferStatus extends Equatable {
  final Duration bufferedAhead;
  final Duration totalBuffered;
  final double bufferPercentage;
  final bool isBuffering;
  final int bufferHealth; // 0-100, higher is better

  const BufferStatus({
    this.bufferedAhead = Duration.zero,
    this.totalBuffered = Duration.zero,
    this.bufferPercentage = 0.0,
    this.isBuffering = false,
    this.bufferHealth = 100,
  });

  /// Target buffer: 10-30 seconds ahead
  bool get isHealthy => bufferedAhead.inSeconds >= 10;
  bool get isOptimal => bufferedAhead.inSeconds >= 20;

  @override
  List<Object?> get props => [
    bufferedAhead,
    totalBuffered,
    bufferPercentage,
    isBuffering,
  ];
}

/// Streaming quality metrics
class StreamingMetrics extends Equatable {
  final int currentBitrate; // kbps
  final int peakBitrate;
  final double droppedFrames;
  final double totalFrames;
  final Duration latency;
  final NetworkQuality networkQuality;
  final DateTime timestamp;

  const StreamingMetrics({
    this.currentBitrate = 0,
    this.peakBitrate = 0,
    this.droppedFrames = 0,
    this.totalFrames = 0,
    this.latency = Duration.zero,
    this.networkQuality = NetworkQuality.good,
    required this.timestamp,
  });

  /// Frame drop percentage
  double get frameDropRate =>
      totalFrames > 0 ? (droppedFrames / totalFrames) * 100 : 0;

  /// Is playback smooth (< 1% frame drops)
  bool get isSmooth => frameDropRate < 1.0;

  @override
  List<Object?> get props => [
    currentBitrate,
    droppedFrames,
    latency,
    networkQuality,
  ];
}

/// Complete streaming state with Live DVR support
class StreamingState extends Equatable {
  final IPTVChannel? currentChannel;
  final PlaybackState playbackState;
  final VideoQuality currentQuality;
  final VideoQuality selectedQuality; // User preference (auto or specific)
  final BufferStatus bufferStatus;
  final StreamingMetrics? metrics;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final String? errorMessage;
  final int retryCount;
  final DateTime? lastError;

  // === Live DVR Properties (P0-1 to P0-4) ===

  /// Whether the current stream is a live stream (vs VOD)
  final bool isLiveStream;

  /// The live edge position (latest available position in stream)
  final Duration? liveEdge;

  /// Current delay from live edge (liveEdge - position)
  final Duration liveDelay;

  /// Start of DVR window (earliest seekable position)
  final Duration? dvrWindowStart;

  /// Duration of available DVR window
  final Duration? dvrWindowDuration;

  /// Current live stream state (LIVE, BEHIND_LIVE, etc.)
  final LiveStreamState liveStreamState;

  /// Whether DVR is supported by this stream
  final bool hasDvrSupport;

  /// Timestamp of last live edge update
  final DateTime? lastLiveEdgeUpdate;

  const StreamingState({
    this.currentChannel,
    this.playbackState = PlaybackState.idle,
    this.currentQuality = VideoQuality.auto,
    this.selectedQuality = VideoQuality.auto,
    this.bufferStatus = const BufferStatus(),
    this.metrics,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.errorMessage,
    this.retryCount = 0,
    this.lastError,
    // Live DVR defaults
    this.isLiveStream = false,
    this.liveEdge,
    this.liveDelay = Duration.zero,
    this.dvrWindowStart,
    this.dvrWindowDuration,
    this.liveStreamState = LiveStreamState.unknown,
    this.hasDvrSupport = false,
    this.lastLiveEdgeUpdate,
  });

  // === Existing Getters ===

  bool get isPlaying => playbackState == PlaybackState.playing;
  bool get isLoading => playbackState == PlaybackState.loading;
  bool get isBuffering => playbackState == PlaybackState.buffering;
  bool get hasError => playbackState == PlaybackState.error;
  bool get canRetry => retryCount < 3;

  /// Time to first frame target: < 2 seconds
  bool get meetsLoadTimeTarget =>
      metrics != null && metrics!.latency.inMilliseconds < 2000;

  // === Live DVR Getters (P0-5 visibility logic) ===

  /// Whether user is at live edge (delay <= 3 seconds)
  bool get isAtLiveEdge =>
      isLiveStream &&
      liveDelay.inSeconds <=
          LiveEdgeConfig.defaultConfig.liveEdgeThreshold.inSeconds;

  /// Whether user is behind live (delay > threshold)
  bool get isBehindLive =>
      isLiveStream &&
      liveDelay.inSeconds >
          LiveEdgeConfig.defaultConfig.liveEdgeThreshold.inSeconds;

  /// Whether "Go Live" button should be visible (P0-5)
  bool get shouldShowGoLive =>
      isLiveStream && (isBehindLive || playbackState == PlaybackState.paused);

  /// Whether auto-resync should trigger (delay > 30s without user action)
  bool get shouldAutoResync =>
      isLiveStream &&
      liveDelay.inSeconds >
          LiveEdgeConfig.defaultConfig.autoResyncThreshold.inSeconds;

  /// Formatted delay string for UI (e.g., "45s behind")
  String get formattedDelay {
    if (!isLiveStream || isAtLiveEdge) return '';
    final seconds = liveDelay.inSeconds;
    if (seconds < 60) return '${seconds}s behind';
    final minutes = liveDelay.inMinutes;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) return '${minutes}m behind';
    return '${minutes}m ${remainingSeconds}s behind';
  }

  /// Whether seeking is allowed (within DVR window)
  bool get canSeekBack =>
      isLiveStream && hasDvrSupport && dvrWindowDuration != null;

  StreamingState copyWith({
    IPTVChannel? currentChannel,
    PlaybackState? playbackState,
    VideoQuality? currentQuality,
    VideoQuality? selectedQuality,
    BufferStatus? bufferStatus,
    StreamingMetrics? metrics,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    String? errorMessage,
    int? retryCount,
    DateTime? lastError,
    // Live DVR properties
    bool? isLiveStream,
    Duration? liveEdge,
    Duration? liveDelay,
    Duration? dvrWindowStart,
    Duration? dvrWindowDuration,
    LiveStreamState? liveStreamState,
    bool? hasDvrSupport,
    DateTime? lastLiveEdgeUpdate,
  }) {
    return StreamingState(
      currentChannel: currentChannel ?? this.currentChannel,
      playbackState: playbackState ?? this.playbackState,
      currentQuality: currentQuality ?? this.currentQuality,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      bufferStatus: bufferStatus ?? this.bufferStatus,
      metrics: metrics ?? this.metrics,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      errorMessage: errorMessage,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      // Live DVR properties
      isLiveStream: isLiveStream ?? this.isLiveStream,
      liveEdge: liveEdge ?? this.liveEdge,
      liveDelay: liveDelay ?? this.liveDelay,
      dvrWindowStart: dvrWindowStart ?? this.dvrWindowStart,
      dvrWindowDuration: dvrWindowDuration ?? this.dvrWindowDuration,
      liveStreamState: liveStreamState ?? this.liveStreamState,
      hasDvrSupport: hasDvrSupport ?? this.hasDvrSupport,
      lastLiveEdgeUpdate: lastLiveEdgeUpdate ?? this.lastLiveEdgeUpdate,
    );
  }

  @override
  List<Object?> get props => [
    currentChannel,
    playbackState,
    currentQuality,
    bufferStatus,
    position,
    volume,
    isMuted,
    errorMessage,
    // Live DVR properties
    isLiveStream,
    liveEdge,
    liveDelay,
    liveStreamState,
  ];
}
