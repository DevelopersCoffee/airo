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
enum PlaybackState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  error,
  ended,
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
  List<Object?> get props => [bufferedAhead, totalBuffered, bufferPercentage, isBuffering];
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
  List<Object?> get props => [currentBitrate, droppedFrames, latency, networkQuality];
}

/// Complete streaming state
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
  });

  bool get isPlaying => playbackState == PlaybackState.playing;
  bool get isLoading => playbackState == PlaybackState.loading;
  bool get isBuffering => playbackState == PlaybackState.buffering;
  bool get hasError => playbackState == PlaybackState.error;
  bool get canRetry => retryCount < 3;

  /// Time to first frame target: < 2 seconds
  bool get meetsLoadTimeTarget =>
      metrics != null && metrics!.latency.inMilliseconds < 2000;

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
      ];
}

