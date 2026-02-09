import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/media_hub_providers.dart';
import '../../domain/models/player_display_mode.dart';
import 'player_overlay_controls.dart';

/// A collapsible player container that resizes based on scroll position.
///
/// Key behaviors:
/// - Default collapsed height is ~65-70% of expanded height
/// - Collapses smoothly on content scroll (300ms, easeOutCubic)
/// - Expands to fullscreen on button tap
/// - State persists when navigating between tabs
class CollapsiblePlayerContainer extends ConsumerStatefulWidget {
  /// The child widget to display inside the player container (e.g., video player)
  final Widget child;

  /// Scroll controller to listen for scroll events
  final ScrollController? scrollController;

  /// Callback when fullscreen is toggled
  final VoidCallback? onFullscreenToggle;

  /// Whether to show overlay controls (play/pause, favorite, fullscreen, settings)
  final bool showOverlayControls;

  /// Whether media is currently playing (for overlay controls)
  final bool isPlaying;

  /// Whether current content is favorited (for overlay controls)
  final bool isFavorite;

  /// Callback when play/pause is tapped
  final VoidCallback? onPlayPause;

  /// Callback when favorite is tapped
  final VoidCallback? onFavorite;

  /// Callback when settings is tapped
  final VoidCallback? onSettings;

  /// Title to display in overlay controls
  final String? title;

  /// Subtitle to display in overlay controls
  final String? subtitle;

  /// Collapsed height on mobile (default: 200px)
  static const double mobileCollapsedHeight = 200.0;

  /// Collapsed height on tablet (default: 280px)
  static const double tabletCollapsedHeight = 280.0;

  /// Expanded height multiplier (collapsed * this = expanded)
  static const double expandedMultiplier = 1.54; // ~65% collapsed

  /// Animation duration
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// Animation curve
  static const Curve animationCurve = Curves.easeOutCubic;

  const CollapsiblePlayerContainer({
    super.key,
    required this.child,
    this.scrollController,
    this.onFullscreenToggle,
    this.showOverlayControls = false,
    this.isPlaying = false,
    this.isFavorite = false,
    this.onPlayPause,
    this.onFavorite,
    this.onSettings,
    this.title,
    this.subtitle,
  });

  @override
  ConsumerState<CollapsiblePlayerContainer> createState() =>
      _CollapsiblePlayerContainerState();
}

class _CollapsiblePlayerContainerState
    extends ConsumerState<CollapsiblePlayerContainer> {
  late ScrollController _scrollController;
  bool _isOwnController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _isOwnController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CollapsiblePlayerContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController.removeListener(_onScroll);
      if (_isOwnController) {
        _scrollController.dispose();
      }
      if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
        _isOwnController = false;
      } else {
        _scrollController = ScrollController();
        _isOwnController = true;
      }
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_isOwnController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    // Update scroll offset in provider for other widgets to react
    ref.read(mediaHubScrollOffsetProvider.notifier).state =
        _scrollController.offset;
  }

  /// Get the collapsed height based on screen width
  double _getCollapsedHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Tablet breakpoint at 600dp
    if (width >= 600) {
      return CollapsiblePlayerContainer.tabletCollapsedHeight;
    }
    return CollapsiblePlayerContainer.mobileCollapsedHeight;
  }

  /// Get the expanded height
  double _getExpandedHeight(BuildContext context) {
    return _getCollapsedHeight(context) *
        CollapsiblePlayerContainer.expandedMultiplier;
  }

  /// Calculate current height based on display mode and scroll
  double _getCurrentHeight(BuildContext context, PlayerDisplayMode mode) {
    final collapsedHeight = _getCollapsedHeight(context);
    final expandedHeight = _getExpandedHeight(context);

    switch (mode) {
      case PlayerDisplayMode.collapsed:
        return collapsedHeight;
      case PlayerDisplayMode.expanded:
        return expandedHeight;
      case PlayerDisplayMode.fullscreen:
        return MediaQuery.of(context).size.height;
      case PlayerDisplayMode.mini:
        return 64.0; // Mini player bar height
      case PlayerDisplayMode.hidden:
        return 0.0;
    }
  }

  void _toggleExpand() {
    final currentMode = ref.read(playerDisplayModeProvider);
    if (currentMode == PlayerDisplayMode.collapsed) {
      ref.read(playerDisplayModeProvider.notifier).state =
          PlayerDisplayMode.expanded;
    } else if (currentMode == PlayerDisplayMode.expanded) {
      ref.read(playerDisplayModeProvider.notifier).state =
          PlayerDisplayMode.collapsed;
    }
  }

  void _toggleFullscreen() {
    final currentMode = ref.read(playerDisplayModeProvider);
    if (currentMode == PlayerDisplayMode.fullscreen) {
      ref.read(playerDisplayModeProvider.notifier).state =
          PlayerDisplayMode.collapsed;
    } else {
      ref.read(playerDisplayModeProvider.notifier).state =
          PlayerDisplayMode.fullscreen;
    }
    widget.onFullscreenToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(playerDisplayModeProvider);
    final currentHeight = _getCurrentHeight(context, displayMode);

    // Hide if mode is hidden
    if (displayMode == PlayerDisplayMode.hidden) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: CollapsiblePlayerContainer.animationDuration,
      curve: CollapsiblePlayerContainer.animationCurve,
      height: currentHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main player content
          Positioned.fill(child: widget.child),

          // Overlay controls (when enabled) - includes play/pause, favorite, fullscreen, settings
          if (widget.showOverlayControls)
            Positioned.fill(
              child: PlayerOverlayControls(
                isPlaying: widget.isPlaying,
                isFavorite: widget.isFavorite,
                onPlayPause: widget.onPlayPause,
                onFavorite: widget.onFavorite,
                onFullscreen: _toggleFullscreen,
                onSettings: widget.onSettings,
                title: widget.title,
                subtitle: widget.subtitle,
              ),
            ),

          // Simple expand/fullscreen buttons when overlay controls are disabled
          if (!widget.showOverlayControls) ...[
            // Expand/Collapse button (top right)
            if (displayMode != PlayerDisplayMode.fullscreen)
              Positioned(
                top: 8,
                right: 48,
                child: _buildExpandButton(displayMode),
              ),

            // Fullscreen button (top right)
            Positioned(
              top: 8,
              right: 8,
              child: _buildFullscreenButton(displayMode),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandButton(PlayerDisplayMode mode) {
    final isExpanded = mode == PlayerDisplayMode.expanded;
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isExpanded ? Icons.unfold_less : Icons.unfold_more,
            color: Colors.white,
            size: 20,
            semanticLabel: isExpanded ? 'Collapse player' : 'Expand player',
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenButton(PlayerDisplayMode mode) {
    final isFullscreen = mode == PlayerDisplayMode.fullscreen;
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: _toggleFullscreen,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
            size: 20,
            semanticLabel: isFullscreen
                ? 'Exit fullscreen'
                : 'Enter fullscreen',
          ),
        ),
      ),
    );
  }
}
