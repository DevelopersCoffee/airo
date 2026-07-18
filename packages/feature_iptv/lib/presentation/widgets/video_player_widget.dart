import 'dart:async';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../application/providers/iptv_providers.dart';
import '../../application/providers/video_aspect_ratio_provider.dart';
import '../../domain/wakelock_debouncer.dart';
import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import '../utils/web_fullscreen.dart' as web_fullscreen;
import 'iptv_icon_placeholder.dart';
import 'live_indicators.dart';

/// Video player widget with YouTube-like controls
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final VoidCallback? onFullscreenToggle;
  final bool enableSwipeChannelChange;
  final bool initiallyFullscreen;

  const VideoPlayerWidget({
    super.key,
    this.showControls = true,
    this.onFullscreenToggle,
    this.enableSwipeChannelChange = false,
    this.initiallyFullscreen = false,
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
  final _wakelockDebouncer = WakelockDebouncer();

  // Channel change overlay state
  String? _channelChangeOverlayText;
  Timer? _channelChangeOverlayTimer;

  @override
  void initState() {
    super.initState();
    _isFullscreen = widget.initiallyFullscreen;
    _startHideControlsTimer();
    // Note: Wakelock is now managed by _updateWakelockForPlayback
    // based on actual playback state, not just widget mount
  }

  @override
  void dispose() {
    _cancelHideControlsTimer();
    _channelChangeOverlayTimer?.cancel();
    _wakelockDebouncer.cancel();
    _disableWakelock();
    super.dispose();
  }

  /// Update wakelock based on playback state
  /// Enable only when video is actively playing (not audio-only)
  ///
  /// Debounced via [WakelockDebouncer]: a single buffering tick shouldn't
  /// flip the OS wakelock, only a target that holds steady does.
  void _updateWakelockForPlayback(StreamingState state) {
    if (!mounted) return;
    final isVideoPlaying =
        state.isPlaying &&
        state.currentChannel != null &&
        !state.currentChannel!.isAudioOnly;

    _wakelockDebouncer.update(
      current: _wakelockEnabled,
      target: isVideoPlaying,
      onSettled: (target) {
        if (!mounted) return;
        if (target) {
          _enableWakelock();
        } else {
          _disableWakelock();
        }
      },
    );
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
    final enteringFullscreen = !_isFullscreen;
    if (kIsWeb) {
      _toggleWebFullscreen();
    }
    setState(() => _isFullscreen = enteringFullscreen);
    unawaited(AiroNativeFullscreen.setMacosFullscreen(enteringFullscreen));
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
    final aspectRatioFit = ref.watch(videoAspectRatioProvider);

    return streamingState.when(
      data: (state) =>
          _buildPlayer(context, streamingService, state, aspectRatioFit),
      loading: () => _buildLoading(),
      error: (err, _) => _buildError(err.toString()),
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
    AiroPlaybackViewFit aspectRatioFit,
  ) {
    // Update wakelock based on current playback state
    // This is called on every build when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWakelockForPlayback(state);
    });

    final videoView = service.buildVideoView();

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
              if (videoView != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: _boxFitFor(aspectRatioFit),
                    child: videoView,
                  ),
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

              // Quality indicator and Live badge
              Positioned(
                top: 8,
                left: 8,
                child: Row(
                  children: [
                    _buildQualityBadge(state.currentQuality),
                    const SizedBox(width: 8),
                    // Live badge - shows "LIVE" when at live edge
                    LiveBadge(state: state, showWhenNotLive: true),
                    // Note: DelayIndicator removed for cleaner UI per design spec
                  ],
                ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blueGrey.shade900, Colors.black87],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon with subtle animation effect
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              // Primary error message
              const Text(
                'Unable to play this channel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Secondary message (technical details)
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              // Retry button with better styling
              ElevatedButton.icon(
                onPressed: () => ref.read(iptvStreamingServiceProvider).retry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Hint text
              Text(
                'The stream may be temporarily unavailable',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(StreamingState state) {
    final channel = state.currentChannel;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blueGrey.shade900, Colors.black],
        ),
      ),
      child: Center(
        child: channel != null && channel.hasLogo
            ? AiroNetworkImage(
                url: channel.logoUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultPlaceholder(),
              )
            : _buildDefaultPlaceholder(),
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return IptvIconPlaceholder.videoPlayer();
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (state.currentChannel != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (state.currentChannel!.logoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AiroNetworkImage(
                          url: state.currentChannel!.logoUrl!,
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
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
            ),
          ),
        Center(child: _buildCenterButton(service, state)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBufferIndicator(state),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mute button + YouTube-style volume slider
                      _VolumeControl(
                        key: const ValueKey('iptv-player-volume-control'),
                        volume: state.volume,
                        isMuted: state.isMuted,
                        onToggleMute: () => service.toggleMute(),
                        onVolumeChanged: (value) {
                          if (state.isMuted) service.toggleMute();
                          service.setVolume(value);
                        },
                      ),
                      const Spacer(),
                      // Aspect ratio toggle
                      _PlayerControlButton(
                        key: const ValueKey('iptv-player-aspect-ratio-button'),
                        icon: Icons.aspect_ratio,
                        tooltip: 'Aspect Ratio',
                        onPressed: () => ref
                            .read(videoAspectRatioProvider.notifier)
                            .cycleToNext(),
                      ),
                      // Cinema mode toggle
                      _PlayerControlButton(
                        icon: _isCinemaMode ? Icons.wb_sunny : Icons.theaters,
                        iconColor: _isCinemaMode ? Colors.amber : Colors.white,
                        tooltip: _isCinemaMode
                            ? 'Standard Mode'
                            : 'Cinema Mode',
                        onPressed: () {
                          setState(() => _isCinemaMode = !_isCinemaMode);
                        },
                      ),
                      // Fullscreen button
                      _PlayerControlButton(
                        key: const ValueKey('iptv-player-fullscreen-button'),
                        icon: _isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the center button - either "Go Live" or play/pause based on state
  ///
  /// Behavior:
  /// - Behind live (delay > 3s): Shows "Go Live" button with red styling
  /// - At live edge & playing: Shows pause button
  /// - At live edge & paused: Shows play button
  Widget _buildCenterButton(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    // Check if we should show "Go Live" (behind live by more than 3 seconds)
    // But NOT when paused - paused should show play button
    final showGoLive =
        state.isLiveStream && state.isBehindLive && state.isPlaying;

    if (showGoLive) {
      // "Go Live" button - red themed to indicate user is behind
      return GestureDetector(
        onTap: () => service.goLive(),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Standard play/pause button — translucent white circle behind a dark
    // glyph, matching the design handoff's player chrome.
    return GestureDetector(
      onTap: () {
        if (state.isPlaying) {
          service.pause();
        } else {
          service.resume();
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
            ),
          ],
        ),
        child: Icon(
          state.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
          size: 32,
        ),
      ),
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

  /// Maps the view-layer [AiroPlaybackViewFit] contract to a concrete
  /// [BoxFit]. `fill` keeps the full frame (letterboxed on one axis only,
  /// matching the common TV "fill width" mode); `stretch` is Flutter's
  /// [BoxFit.fill] — a full non-uniform stretch to the edges.
  BoxFit _boxFitFor(AiroPlaybackViewFit fit) {
    switch (fit) {
      case AiroPlaybackViewFit.contain:
        return BoxFit.contain;
      case AiroPlaybackViewFit.cover:
        return BoxFit.cover;
      case AiroPlaybackViewFit.fill:
        return BoxFit.fitWidth;
      case AiroPlaybackViewFit.stretch:
        return BoxFit.fill;
    }
  }
}

/// YouTube-style volume control: a mute icon that reveals a horizontal
/// slider on hover/focus instead of taking up permanent control-bar width.
class _VolumeControl extends StatefulWidget {
  const _VolumeControl({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  final double volume;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  static const _sliderWidth = 72.0;

  bool _expanded = false;

  void _setExpanded(bool expanded) {
    if (_expanded == expanded) return;
    setState(() => _expanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveVolume = widget.isMuted ? 0.0 : widget.volume;
    return MouseRegion(
      onEnter: (_) => _setExpanded(true),
      onExit: (_) => _setExpanded(false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayerControlButton(
            icon: effectiveVolume == 0
                ? Icons.volume_off
                : effectiveVolume < 0.5
                ? Icons.volume_down
                : Icons.volume_up,
            tooltip: widget.isMuted ? 'Unmute' : 'Mute',
            onPressed: widget.onToggleMute,
          ),
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: _expanded ? _sliderWidth : 0,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  key: const ValueKey('iptv-player-volume-slider'),
                  value: effectiveVolume,
                  onChanged: widget.onVolumeChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tight-footprint control-bar icon button. The default [IconButton]'s
/// 48x48 minimum tap target doesn't fit six of them in the compact mini
/// player's ~268px width (see CV-016 volume controls); this trims padding
/// and tap-target constraints while keeping icons legible and tappable.
class _PlayerControlButton extends StatelessWidget {
  const _PlayerControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: iconColor, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}
