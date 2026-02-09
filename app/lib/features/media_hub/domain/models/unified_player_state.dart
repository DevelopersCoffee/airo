import 'package:equatable/equatable.dart';
import '../../../iptv/domain/models/streaming_state.dart';
import 'player_display_mode.dart';
import 'quality_settings.dart';
import 'unified_media_content.dart';

/// Unified player state combining music and TV player states
class UnifiedPlayerState extends Equatable {
  /// Currently playing content
  final UnifiedMediaContent? currentContent;

  /// Current playback state
  final PlaybackState playbackState;

  /// Player display mode
  final PlayerDisplayMode displayMode;

  /// Current playback position
  final Duration position;

  /// Total duration (for non-live content)
  final Duration duration;

  /// Volume level (0.0 - 1.0)
  final double volume;

  /// Whether audio is muted
  final bool isMuted;

  /// Quality settings
  final QualitySettings qualitySettings;

  /// Buffer status
  final BufferStatus bufferStatus;

  /// Playback queue
  final List<UnifiedMediaContent> queue;

  /// Current index in queue
  final int currentIndex;

  /// Error message if any
  final String? errorMessage;

  const UnifiedPlayerState({
    this.currentContent,
    this.playbackState = PlaybackState.idle,
    this.displayMode = PlayerDisplayMode.collapsed,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.qualitySettings = const QualitySettings(),
    this.bufferStatus = const BufferStatus(),
    this.queue = const [],
    this.currentIndex = -1,
    this.errorMessage,
  });

  /// Check if currently playing
  bool get isPlaying => playbackState == PlaybackState.playing;

  /// Check if loading
  bool get isLoading => playbackState == PlaybackState.loading;

  /// Check if buffering
  bool get isBuffering => playbackState == PlaybackState.buffering;

  /// Check if has error
  bool get hasError => playbackState == PlaybackState.error;

  /// Check if has content
  bool get hasContent => currentContent != null;

  /// Check if playing music
  bool get isMusic => currentContent?.isMusic ?? false;

  /// Check if playing TV
  bool get isTV => currentContent?.isTV ?? false;

  /// Check if can go to next track
  bool get hasNext => currentIndex < queue.length - 1;

  /// Check if can go to previous track
  bool get hasPrevious => currentIndex > 0;

  /// Progress as percentage (0.0 - 1.0)
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Remaining time
  Duration get remaining => duration - position;

  UnifiedPlayerState copyWith({
    UnifiedMediaContent? currentContent,
    PlaybackState? playbackState,
    PlayerDisplayMode? displayMode,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    QualitySettings? qualitySettings,
    BufferStatus? bufferStatus,
    List<UnifiedMediaContent>? queue,
    int? currentIndex,
    String? errorMessage,
  }) {
    return UnifiedPlayerState(
      currentContent: currentContent ?? this.currentContent,
      playbackState: playbackState ?? this.playbackState,
      displayMode: displayMode ?? this.displayMode,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      qualitySettings: qualitySettings ?? this.qualitySettings,
      bufferStatus: bufferStatus ?? this.bufferStatus,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    currentContent,
    playbackState,
    displayMode,
    position,
    duration,
    volume,
    isMuted,
    qualitySettings,
    bufferStatus,
    queue,
    currentIndex,
    errorMessage,
  ];
}
