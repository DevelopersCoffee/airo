import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import '../tv/tv_support.dart';

/// TV-specific player controls for Android TV/Fire TV
///
/// Features:
/// - Larger touch targets (56dp minimum)
/// - D-pad focusable controls
/// - Visual focus indicators
/// - Navigation hints ("Press OK to select")
/// - 10ft UI optimized layout
class TvPlayerControls extends ConsumerStatefulWidget {
  final VideoPlayerStreamingService service;
  final StreamingState state;
  final VoidCallback? onFullscreenToggle;

  const TvPlayerControls({
    super.key,
    required this.service,
    required this.state,
    this.onFullscreenToggle,
  });

  @override
  ConsumerState<TvPlayerControls> createState() => _TvPlayerControlsState();
}

class _TvPlayerControlsState extends ConsumerState<TvPlayerControls> {
  @override
  Widget build(BuildContext context) {
    final dimensions = ref.watch(tvDimensionsProvider(context));

    return TvInputHandler(
      onInput: _handleTvInput,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black54,
              Colors.transparent,
              Colors.transparent,
              Colors.black87,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTopBar(dimensions),
            _buildCenterControls(dimensions),
            _buildBottomBar(dimensions),
          ],
        ),
      ),
    );
  }

  TvInputResult _handleTvInput(TvInputKey key) {
    switch (key) {
      case TvInputKey.playPause:
        _togglePlayPause();
        return TvInputResult.handled;
      case TvInputKey.fastForward:
        _seekForward();
        return TvInputResult.handled;
      case TvInputKey.rewind:
        _seekBackward();
        return TvInputResult.handled;
      default:
        return TvInputResult.notHandled;
    }
  }

  void _togglePlayPause() {
    if (widget.state.isPlaying) {
      widget.service.pause();
    } else {
      widget.service.resume();
    }
  }

  void _seekForward() {
    final current = widget.state.position;
    final target = current + const Duration(seconds: 10);
    widget.service.seek(target);
  }

  void _seekBackward() {
    final current = widget.state.position;
    final target = current - const Duration(seconds: 10);
    widget.service.seek(target.isNegative ? Duration.zero : target);
  }

  Widget _buildTopBar(TvUiDimensions dimensions) {
    final channel = widget.state.currentChannel;
    if (channel == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(dimensions.cardPadding * 1.5),
      child: Row(
        children: [
          if (channel.logoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                channel.logoUrl!,
                width: 48,
                height: 48,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24 * dimensions.textScaleFactor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.state.isLiveStream) _buildLiveIndicator(dimensions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator(TvUiDimensions dimensions) {
    final isAtLive = widget.state.isAtLiveEdge;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAtLive ? Colors.red : Colors.red.shade900,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isAtLive ? 'LIVE' : 'BEHIND LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12 * dimensions.textScaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (!isAtLive) ...[
          const SizedBox(width: 8),
          Text(
            widget.state.formattedDelay,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14 * dimensions.textScaleFactor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCenterControls(TvUiDimensions dimensions) {
    final showGoLive =
        widget.state.isLiveStream &&
        widget.state.isBehindLive &&
        widget.state.isPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind button
        _TvControlButton(
          icon: Icons.replay_10,
          onSelect: _seekBackward,
          size: dimensions.controlButtonSize,
          tooltip: 'Rewind 10s',
        ),
        SizedBox(width: dimensions.gridSpacing),
        // Play/Pause or Go Live
        showGoLive
            ? _TvControlButton(
                icon: Icons.skip_next_rounded,
                onSelect: () => widget.service.goLive(),
                size: dimensions.controlButtonSize * 1.5,
                color: Colors.red,
                tooltip: 'Go Live',
                showLabel: true,
                label: 'GO LIVE',
              )
            : _TvControlButton(
                icon: widget.state.isPlaying ? Icons.pause : Icons.play_arrow,
                onSelect: _togglePlayPause,
                size: dimensions.controlButtonSize * 1.5,
                autofocus: true,
                tooltip: widget.state.isPlaying ? 'Pause' : 'Play',
              ),
        SizedBox(width: dimensions.gridSpacing),
        // Fast forward button
        _TvControlButton(
          icon: Icons.forward_10,
          onSelect: _seekForward,
          size: dimensions.controlButtonSize,
          tooltip: 'Forward 10s',
        ),
      ],
    );
  }

  Widget _buildBottomBar(TvUiDimensions dimensions) {
    return Padding(
      padding: EdgeInsets.all(dimensions.cardPadding * 1.5),
      child: Column(
        children: [
          // Progress/buffer indicator
          _buildProgressBar(dimensions),
          SizedBox(height: dimensions.cardPadding),
          // Bottom control row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Mute
              _TvControlButton(
                icon: widget.state.isMuted ? Icons.volume_off : Icons.volume_up,
                onSelect: () => widget.service.toggleMute(),
                size: dimensions.minTargetSize,
                tooltip: widget.state.isMuted ? 'Unmute' : 'Mute',
              ),
              // Center: Navigation hint
              Text(
                'Press OK to select • ← → to navigate',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14 * dimensions.textScaleFactor,
                ),
              ),
              // Right: Fullscreen
              _TvControlButton(
                icon: Icons.fullscreen,
                onSelect: widget.onFullscreenToggle,
                size: dimensions.minTargetSize,
                tooltip: 'Fullscreen',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(TvUiDimensions dimensions) {
    final position = widget.state.position.inSeconds.toDouble();
    final duration = widget.state.duration.inSeconds.toDouble();
    final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.white24,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: widget.state.isLiveStream ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(widget.state.position),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14 * dimensions.textScaleFactor,
              ),
            ),
            Text(
              _formatDuration(widget.state.duration),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14 * dimensions.textScaleFactor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

/// TV-optimized control button with focus support
///
/// Includes semantic labels for screen reader support (CP-AC-003)
class _TvControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onSelect;
  final double size;
  final Color? color;
  final String? tooltip;
  final bool autofocus;
  final bool showLabel;
  final String? label;

  const _TvControlButton({
    required this.icon,
    this.onSelect,
    required this.size,
    this.color,
    this.tooltip,
    this.autofocus = false,
    this.showLabel = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onSelect: onSelect,
      autofocus: autofocus,
      focusColor: color ?? Colors.white,
      borderRadius: size / 2,
      // Accessibility: semantic labels for screen readers (CP-AC-003)
      semanticLabel: tooltip ?? label,
      semanticHint: 'Press OK to activate',
      semanticButton: true,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.8) ?? Colors.black45,
            shape: BoxShape.circle,
          ),
          child: showLabel
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: size * 0.4),
                    if (label != null)
                      Text(
                        label!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                )
              : Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
