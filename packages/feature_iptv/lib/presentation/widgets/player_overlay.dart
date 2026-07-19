import 'dart:async';

import 'package:flutter/material.dart';
import 'package:platform_player/platform_player.dart';

/// Renderer-agnostic minimal player overlay: back/title/quality/LIVE chrome,
/// center transport controls, a failover toast, and a bottom scrubber row.
///
/// This widget depends ONLY on [PlayerViewState] — never on ExoPlayer/VLC/
/// engine-specific types — so it can sit in front of any playback backend
/// without change (see `PlayerViewState` doc in platform_player).
class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({
    super.key,
    required this.state,
    required this.onBack,
    required this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onGuide,
    this.onFullscreen,
    this.autoHideDelay = const Duration(seconds: 3),
    this.showCenterControls = true,
    this.showBottomBar = true,
  });

  final PlayerViewState state;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onGuide;
  final VoidCallback? onFullscreen;
  final Duration autoHideDelay;

  /// Whether to render the center prev/play-pause/next row. Defaults to
  /// `true` (full standalone overlay per spec); callers that already have a
  /// richer, feature-specific transport bar (e.g. VOD seek, subtitle
  /// selector) can set this to `false` and use [PlayerOverlay] only for its
  /// top chrome (back/title/quality/LIVE) and failover toast, avoiding
  /// duplicate controls.
  final bool showCenterControls;

  /// Whether to render the bottom scrubber/LIVE/buffer/volume row. See
  /// [showCenterControls] for why a host might opt out.
  final bool showBottomBar;

  @override
  State<PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<PlayerOverlay> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void didUpdateWidget(PlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoHideDelay != widget.autoHideDelay) {
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.autoHideDelay, () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _reveal() {
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _reveal,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            key: const ValueKey('player-overlay-controls-opacity'),
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildTopGradient(state),
                  if (widget.showCenterControls) _buildCenterControls(state),
                  if (widget.showBottomBar) _buildBottomGradient(state),
                ],
              ),
            ),
          ),
          if (state.failover != null) _buildFailoverToast(state.failover!),
        ],
      ),
    );
  }

  Widget _buildTopGradient(PlayerViewState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _CircleIconButton(
                  key: const ValueKey('player-overlay-back'),
                  icon: Icons.arrow_back,
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.title.isNotEmpty)
                        Text(
                          state.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (state.subtitle.isNotEmpty)
                        Text(
                          state.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildQualityPill(state),
                if (state.liveState == LiveStreamState.live) ...[
                  const SizedBox(width: 8),
                  _buildLivePill(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityPill(PlayerViewState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${state.networkQuality.label} · ${state.qualityLabel}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildLivePill() {
    return Container(
      key: const ValueKey('player-overlay-live-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCenterControls(PlayerViewState state) {
    final isPlaying = state.playback == PlaybackState.playing;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.onPrevious != null)
            _CircleIconButton(
              key: const ValueKey('player-overlay-previous'),
              icon: Icons.skip_previous,
              size: 48,
              onPressed: widget.onPrevious,
            ),
          const SizedBox(width: 24),
          _CircleIconButton(
            key: const ValueKey('player-overlay-play-pause'),
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            size: 62,
            backgroundColor: Colors.white,
            iconColor: Colors.black,
            onPressed: widget.onPlayPause,
          ),
          const SizedBox(width: 24),
          if (widget.onNext != null)
            _CircleIconButton(
              key: const ValueKey('player-overlay-next'),
              icon: Icons.skip_next,
              size: 48,
              onPressed: widget.onNext,
            ),
        ],
      ),
    );
  }

  Widget _buildFailoverToast(FailoverProgress failover) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 80,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Switching to source ${failover.currentSource} of '
            '${failover.totalSources}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient(PlayerViewState state) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildScrubber(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      color: Colors.red,
                      size: 8,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Buffer: ${state.bufferSeconds}s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    _CircleIconButton(
                      key: const ValueKey('player-overlay-volume'),
                      icon: Icons.volume_up,
                      size: 36,
                      onPressed: () {},
                    ),
                    if (widget.onGuide != null)
                      _CircleIconButton(
                        key: const ValueKey('player-overlay-guide'),
                        icon: Icons.grid_view,
                        size: 36,
                        onPressed: widget.onGuide,
                      ),
                    if (widget.onFullscreen != null)
                      _CircleIconButton(
                        key: const ValueKey('player-overlay-fullscreen'),
                        icon: Icons.fullscreen,
                        size: 36,
                        onPressed: widget.onFullscreen,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrubber() {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: 1.0,
        child: DecoratedBox(decoration: BoxDecoration(color: Colors.red)),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.backgroundColor = Colors.black45,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
