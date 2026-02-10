import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../shared/widgets/app_icon_placeholder.dart';
import '../../application/providers/iptv_providers.dart';
import '../../domain/models/iptv_channel.dart';
import '../../domain/models/streaming_state.dart';
import '../../domain/services/video_player_streaming_service.dart';
import '../utils/web_fullscreen.dart' as web_fullscreen;

/// Video player widget with YouTube-like controls
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final VoidCallback? onFullscreenToggle;
  final bool enableSwipeChannelChange;

  const VideoPlayerWidget({
    super.key,
    this.showControls = true,
    this.onFullscreenToggle,
    this.enableSwipeChannelChange = false,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  bool _showControlsOverlay = true;
  bool _isFullscreen = false;
  bool _isCinemaMode = false;
  Timer? _hideControlsTimer;
  static const _controlsHideDelay = Duration(seconds: 4);
  bool _wakelockEnabled = false;

  // Channel change overlay state
  String? _channelChangeOverlayText;
  Timer? _channelChangeOverlayTimer;

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
    // Note: Wakelock is now managed by _updateWakelockForPlayback
    // based on actual playback state, not just widget mount
  }

  @override
  void dispose() {
    _cancelHideControlsTimer();
    _channelChangeOverlayTimer?.cancel();
    _disableWakelock();
    super.dispose();
  }

  /// Update wakelock based on playback state
  /// Enable only when video is actively playing (not audio-only)
  void _updateWakelockForPlayback(StreamingState state) {
    final isVideoPlaying =
        state.isPlaying &&
        state.currentChannel != null &&
        !state.currentChannel!.isAudioOnly;

    if (isVideoPlaying && !_wakelockEnabled) {
      _enableWakelock();
    } else if (!isVideoPlaying && _wakelockEnabled) {
      _disableWakelock();
    }
  }

  /// Enable screen wake lock to prevent screen from going off during video playback
  Future<void> _enableWakelock() async {
    if (!_wakelockEnabled) {
      try {
        await WakelockPlus.enable();
        _wakelockEnabled = true;
        debugPrint(
          'Wakelock enabled - screen will stay on during video playback',
        );
      } catch (e) {
        debugPrint('Failed to enable wakelock: $e');
      }
    }
  }

  /// Disable screen wake lock when video is stopped or widget is disposed
  Future<void> _disableWakelock() async {
    if (_wakelockEnabled) {
      try {
        await WakelockPlus.disable();
        _wakelockEnabled = false;
        debugPrint('Wakelock disabled - screen can now sleep');
      } catch (e) {
        debugPrint('Failed to disable wakelock: $e');
      }
    }
  }

  void _startHideControlsTimer() {
    _cancelHideControlsTimer();
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (mounted) {
        setState(() => _showControlsOverlay = false);
      }
    });
  }

  void _cancelHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  void _showControls() {
    setState(() => _showControlsOverlay = true);
    _startHideControlsTimer();
  }

  void _toggleFullscreen() {
    if (kIsWeb) {
      _toggleWebFullscreen();
    }
    setState(() => _isFullscreen = !_isFullscreen);
    widget.onFullscreenToggle?.call();
  }

  void _toggleWebFullscreen() {
    if (kIsWeb) {
      try {
        web_fullscreen.toggleFullscreen();
      } catch (e) {
        debugPrint('Fullscreen error: $e');
      }
    }
  }

  // Channel navigation button handlers
  void _goToNextChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final nextChannel = ref.read(nextChannelProvider);
    if (nextChannel != null) {
      streamingService.playChannel(nextChannel);
      _showChannelChangeOverlay(nextChannel.name);
    }
  }

  void _goToPreviousChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final prevChannel = ref.read(previousChannelProvider);
    if (prevChannel != null) {
      streamingService.playChannel(prevChannel);
      _showChannelChangeOverlay(prevChannel.name);
    }
  }

  void _showChannelChangeOverlay(String text) {
    _channelChangeOverlayTimer?.cancel();
    setState(() {
      _channelChangeOverlayText = text;
    });
    _channelChangeOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _channelChangeOverlayText = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final streamingService = ref.watch(iptvStreamingServiceProvider);
    final streamingState = ref.watch(streamingStateProvider);

    return streamingState.when(
      data: (state) => _buildPlayer(context, streamingService, state),
      loading: () => _buildLoading(),
      error: (err, _) => _buildError(err.toString()),
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    // Update wakelock based on current playback state
    // This is called on every build when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWakelockForPlayback(state);
    });

    final controller = service.controller;

    return MouseRegion(
      onHover: (_) => _showControls(),
      onEnter: (_) => _showControls(),
      child: GestureDetector(
        onTap: _showControls,
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video display
              if (controller != null && controller.value.isInitialized)
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                )
              else if (state.playbackState == PlaybackState.loading)
                _buildLoading()
              else
                _buildPlaceholder(state),

              // Cinema mode vignette overlay
              if (_isCinemaMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.15,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

              // Buffering indicator
              if (state.isBuffering)
                Container(
                  color: Colors.black45,
                  child: const CircularProgressIndicator(color: Colors.white),
                ),

              // Controls overlay with fade animation
              AnimatedOpacity(
                opacity: (widget.showControls && _showControlsOverlay)
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControlsOverlay,
                  child: _buildControlsOverlay(context, service, state),
                ),
              ),

              // Network quality badge
              if (state.metrics != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildNetworkBadge(state.metrics!.networkQuality),
                ),

              // Quality indicator
              Positioned(
                top: 8,
                left: 8,
                child: _buildQualityBadge(state.currentQuality),
              ),

              // Previous/Next channel buttons (for fullscreen mode)
              if (widget.enableSwipeChannelChange && _showControlsOverlay)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous, size: 40),
                      color: Colors.white,
                      onPressed: _goToPreviousChannel,
                    ),
                  ),
                ),
              if (widget.enableSwipeChannelChange && _showControlsOverlay)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.skip_next, size: 40),
                      color: Colors.white,
                      onPressed: _goToNextChannel,
                    ),
                  ),
                ),

              // Channel change overlay
              if (_channelChangeOverlayText != null)
                Positioned(
                  child: AnimatedOpacity(
                    opacity: _channelChangeOverlayText != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _channelChangeOverlayText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(iptvStreamingServiceProvider).retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(StreamingState state) {
    return Container(
      color: Colors.black,
      child: Center(
        child: state.currentChannel?.logoUrl != null
            ? Image.network(
                state.currentChannel!.logoUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildDefaultPlaceholder(),
              )
            : _buildDefaultPlaceholder(),
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    // Use shared AppIconPlaceholder for brand consistency and optimized caching
    return AppIconPlaceholder.videoPlayer();
  }

  Widget _buildControlsOverlay(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
        ),
      ),
      child: _buildControlButtons(service, state),
    );
  }

  Widget _buildControlButtons(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top bar - channel info
        if (state.currentChannel != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (state.currentChannel!.logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      state.currentChannel!.logoUrl!,
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.currentChannel!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // Center - play/pause button
        IconButton(
          iconSize: 64,
          icon: Icon(
            state.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: Colors.white,
          ),
          onPressed: () {
            if (state.isPlaying) {
              service.pause();
            } else {
              service.resume();
            }
          },
        ),
        // Bottom bar - buffer & controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBufferIndicator(state),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mute button
                  IconButton(
                    icon: Icon(
                      state.isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                    onPressed: () => service.toggleMute(),
                  ),
                  // Cinema mode toggle
                  IconButton(
                    icon: Icon(
                      _isCinemaMode ? Icons.wb_sunny : Icons.theaters,
                      color: _isCinemaMode ? Colors.amber : Colors.white,
                    ),
                    tooltip: _isCinemaMode ? 'Standard Mode' : 'Cinema Mode',
                    onPressed: () {
                      setState(() => _isCinemaMode = !_isCinemaMode);
                    },
                  ),
                  // Fullscreen button
                  IconButton(
                    icon: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                    ),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBufferIndicator(StreamingState state) {
    final bufferHealth = state.bufferStatus.bufferHealth;
    final color = bufferHealth >= 80
        ? Colors.green
        : bufferHealth >= 50
        ? Colors.yellow
        : Colors.red;
    return Column(
      children: [
        LinearProgressIndicator(
          value: bufferHealth / 100,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 4),
        Text(
          'Buffer: ${state.bufferStatus.bufferedAhead.inSeconds}s',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNetworkBadge(NetworkQuality quality) {
    final colors = {
      NetworkQuality.excellent: Colors.green,
      NetworkQuality.good: Colors.lightGreen,
      NetworkQuality.fair: Colors.orange,
      NetworkQuality.poor: Colors.red,
      NetworkQuality.offline: Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[quality],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_cellular_alt, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            quality.label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBadge(VideoQuality quality) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quality.label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
