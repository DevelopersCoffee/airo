import 'dart:async';
import 'package:video_player/video_player.dart';
import '../models/iptv_channel.dart';
import '../models/streaming_state.dart';

/// IPTV Streaming Service with YouTube-quality optimizations
///
/// Features:
/// - Adaptive bitrate streaming (ABR)
/// - 10-30 second buffer ahead
/// - Fast initial load (<2 seconds target)
/// - Seamless quality switching
/// - Auto-retry on network interruptions
/// - Background audio for music channels
abstract class IPTVStreamingService {
  /// Initialize the service
  Future<void> initialize();

  /// Play a channel
  Future<void> playChannel(IPTVChannel channel);

  /// Pause playback
  Future<void> pause();

  /// Resume playback
  Future<void> resume();

  /// Stop playback and release resources
  Future<void> stop();

  /// Seek to position (for VOD content)
  Future<void> seek(Duration position);

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume);

  /// Toggle mute
  Future<void> toggleMute();

  /// Set preferred quality (auto or specific)
  Future<void> setQuality(VideoQuality quality);

  /// Get current streaming state stream
  Stream<StreamingState> get stateStream;

  /// Get current state
  StreamingState get currentState;

  /// Retry playback after error
  Future<void> retry();

  /// Enable/disable background audio mode
  Future<void> setBackgroundAudioMode(bool enabled);

  /// Dispose resources
  Future<void> dispose();
}

/// Configuration for streaming optimization
class StreamingConfig {
  /// Target buffer duration (10-30 seconds)
  final Duration targetBufferDuration;

  /// Minimum buffer before playback starts
  final Duration minBufferDuration;

  /// Maximum retry attempts
  final int maxRetries;

  /// Retry delay
  final Duration retryDelay;

  /// Enable adaptive bitrate
  final bool enableABR;

  /// Low latency mode (for live streams)
  final bool lowLatencyMode;

  const StreamingConfig({
    this.targetBufferDuration = const Duration(seconds: 20),
    this.minBufferDuration = const Duration(seconds: 2),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.enableABR = true,
    this.lowLatencyMode = false,
  });

  /// YouTube-like configuration
  static const youtube = StreamingConfig(
    targetBufferDuration: Duration(seconds: 30),
    minBufferDuration: Duration(seconds: 2),
    maxRetries: 5,
    retryDelay: Duration(seconds: 1),
    enableABR: true,
    lowLatencyMode: false,
  );

  /// Low latency live streaming
  static const live = StreamingConfig(
    targetBufferDuration: Duration(seconds: 10),
    minBufferDuration: Duration(seconds: 1),
    maxRetries: 3,
    retryDelay: Duration(milliseconds: 500),
    enableABR: true,
    lowLatencyMode: true,
  );
}
