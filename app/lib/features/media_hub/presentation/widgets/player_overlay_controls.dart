import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/media_hub_providers.dart';
import '../../domain/models/player_display_mode.dart';

/// Overlay controls for the media player with auto-hide behavior.
///
/// Key behaviors:
/// - Fade-in on tap/hover interaction
/// - Auto-hide after 4 seconds of inactivity
/// - Gradient background for visibility
/// - Actions: Play/Pause, Favorite, Fullscreen, Settings
class PlayerOverlayControls extends ConsumerStatefulWidget {
  /// Whether the media is currently playing
  final bool isPlaying;

  /// Whether the current content is favorited
  final bool isFavorite;

  /// Callback when play/pause is tapped
  final VoidCallback? onPlayPause;

  /// Callback when favorite is tapped
  final VoidCallback? onFavorite;

  /// Callback when fullscreen is tapped
  final VoidCallback? onFullscreen;

  /// Callback when settings is tapped
  final VoidCallback? onSettings;

  /// Title to display at the top
  final String? title;

  /// Subtitle to display below title
  final String? subtitle;

  /// Duration for auto-hide (default: 4 seconds)
  static const Duration autoHideDelay = Duration(seconds: 4);

  /// Duration for fade animation (default: 300ms)
  static const Duration fadeAnimationDuration = Duration(milliseconds: 300);

  const PlayerOverlayControls({
    super.key,
    this.isPlaying = false,
    this.isFavorite = false,
    this.onPlayPause,
    this.onFavorite,
    this.onFullscreen,
    this.onSettings,
    this.title,
    this.subtitle,
  });

  @override
  ConsumerState<PlayerOverlayControls> createState() =>
      _PlayerOverlayControlsState();
}

class _PlayerOverlayControlsState extends ConsumerState<PlayerOverlayControls> {
  Timer? _hideTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(PlayerOverlayControls.autoHideDelay, () {
      if (mounted) {
        setState(() => _visible = false);
        ref.read(controlsVisibleProvider.notifier).state = false;
      }
    });
  }

  void _showControls() {
    setState(() => _visible = true);
    ref.read(controlsVisibleProvider.notifier).state = true;
    _startHideTimer();
  }

  void _handlePlayPause() {
    _showControls();
    widget.onPlayPause?.call();
  }

  void _handleFavorite() {
    _showControls();
    widget.onFavorite?.call();
  }

  void _handleFullscreen() {
    _showControls();
    widget.onFullscreen?.call();
  }

  void _handleSettings() {
    _hideTimer?.cancel(); // Don't hide while settings is open
    widget.onSettings?.call();
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(playerDisplayModeProvider);
    final isFullscreen = displayMode == PlayerDisplayMode.fullscreen;

    return MouseRegion(
      onHover: (_) => _showControls(),
      onEnter: (_) => _showControls(),
      child: GestureDetector(
        onTap: _showControls,
        behavior: HitTestBehavior.translucent,
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: PlayerOverlayControls.fadeAnimationDuration,
          child: IgnorePointer(
            ignoring: !_visible,
            child: _buildOverlay(context, isFullscreen),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, bool isFullscreen) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopBar(context),
          _buildCenterControls(context),
          _buildBottomBar(context, isFullscreen),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          // Settings button in top right
          _buildIconButton(
            icon: Icons.settings,
            onTap: _handleSettings,
            semanticLabel: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play/Pause button (large, center)
        _buildPlayPauseButton(),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isFullscreen) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Favorite button (left)
          _buildIconButton(
            icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
            onTap: _handleFavorite,
            semanticLabel: widget.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            color: widget.isFavorite ? Colors.red : Colors.white,
          ),
          // Fullscreen button (right)
          _buildIconButton(
            icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            onTap: _handleFullscreen,
            semanticLabel: isFullscreen
                ? 'Exit fullscreen'
                : 'Enter fullscreen',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _handlePlayPause,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(
            widget.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
            semanticLabel: widget.isPlaying ? 'Pause' : 'Play',
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    Color color = Colors.white,
  }) {
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: color,
            size: 24,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
