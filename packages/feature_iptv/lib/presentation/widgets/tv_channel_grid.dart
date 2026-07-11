import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/tv/tv.dart';
import '../../../../shared/widgets/app_icon_placeholder.dart';
import '../../application/providers/iptv_providers.dart';
import "package:platform_channels/platform_channels.dart";

/// Configuration for lazy loading behavior
class TvChannelGridConfig {
  /// Number of items to preload ahead of the visible area
  final int preloadItemCount;

  /// Whether to preload thumbnails in focus direction
  final bool preloadThumbnails;

  /// Debounce duration for rapid D-pad inputs (milliseconds)
  final int inputDebounceMs;

  const TvChannelGridConfig({
    this.preloadItemCount = 12,
    this.preloadThumbnails = true,
    this.inputDebounceMs = 50,
  });
}

/// TV-optimized channel grid for Android TV/Fire TV
///
/// Features:
/// - Grid layout optimized for 10-foot UI
/// - D-pad navigation with visual focus indicators
/// - Larger channel cards (200x150)
/// - Focus memory for returning to last selected channel
/// - Performance optimizations:
///   - Lazy loading for large channel lists (500+ channels)
///   - Thumbnail preloading in focus direction
///   - D-pad input debouncing for rapid navigation
///   - Channel up/down navigation for Fire TV
class TvChannelGrid extends ConsumerStatefulWidget {
  final Function(IPTVChannel) onChannelSelect;
  final String? initialFocusChannelId;
  final TvChannelGridConfig config;

  const TvChannelGrid({
    super.key,
    required this.onChannelSelect,
    this.initialFocusChannelId,
    this.config = const TvChannelGridConfig(),
  });

  @override
  ConsumerState<TvChannelGrid> createState() => _TvChannelGridState();
}

class _TvChannelGridState extends ConsumerState<TvChannelGrid> {
  final ScrollController _scrollController = ScrollController();
  int _currentFocusedIndex = 0;
  DateTime? _lastInputTime;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Check if input should be debounced
  bool _shouldDebounce() {
    final now = DateTime.now();
    if (_lastInputTime != null) {
      final elapsed = now.difference(_lastInputTime!).inMilliseconds;
      if (elapsed < widget.config.inputDebounceMs) {
        return true;
      }
    }
    _lastInputTime = now;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(filteredChannelsProvider);
    final dimensions = ref.watch(tvDimensionsProvider(context));
    final currentChannel = ref.watch(currentChannelProvider);

    // Apply safe zone padding for Fire TV
    final padding =
        EdgeInsets.all(dimensions.gridSpacing) + dimensions.safeZone;

    return TvInputHandler(
      onInput: (key) => _handleNavigation(key, channels),
      child: GridView.builder(
        // ignore: deprecated_member_use
        cacheExtent: dimensions.channelCardHeight * 3,
        controller: _scrollController,
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _calculateCrossAxisCount(context, dimensions),
          childAspectRatio:
              dimensions.channelCardWidth / dimensions.channelCardHeight,
          mainAxisSpacing: dimensions.gridSpacing,
          crossAxisSpacing: dimensions.gridSpacing,
        ),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final isPlaying = currentChannel?.id == channel.id;
          final isInitialFocus = widget.initialFocusChannelId != null
              ? channel.id == widget.initialFocusChannelId
              : index == 0;

          // Preload adjacent thumbnails when configured
          if (widget.config.preloadThumbnails) {
            _preloadAdjacentThumbnails(channels, index, dimensions);
          }

          return _TvChannelCard(
            key: ValueKey('channel_card_${channel.id}'),
            channel: channel,
            dimensions: dimensions,
            isPlaying: isPlaying,
            autofocus: isInitialFocus,
            onSelect: () => widget.onChannelSelect(channel),
            onFocus: () {
              _currentFocusedIndex = index;
              _ensureVisible(index, channels.length, dimensions);
            },
          );
        },
      ),
    );
  }

  /// Preload thumbnails for adjacent items in focus direction
  void _preloadAdjacentThumbnails(
    List<IPTVChannel> channels,
    int currentIndex,
    TvUiDimensions dimensions,
  ) {
    final preloadCount = widget.config.preloadItemCount;
    final startIndex = (currentIndex - preloadCount).clamp(0, channels.length);
    final endIndex = (currentIndex + preloadCount).clamp(0, channels.length);

    for (var i = startIndex; i < endIndex; i++) {
      final channel = channels[i];
      if (channel.hasLogo) {
        // Precache the image in Flutter's image cache
        precacheImage(NetworkImage(channel.logoUrl!), context);
      }
    }
  }

  int _calculateCrossAxisCount(
    BuildContext context,
    TvUiDimensions dimensions,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (dimensions.gridSpacing * 2);
    final cardWidth = dimensions.channelCardWidth + dimensions.gridSpacing;
    return (availableWidth / cardWidth).floor().clamp(3, 8);
  }

  void _ensureVisible(int index, int totalItems, TvUiDimensions dimensions) {
    // Scroll to ensure focused item is visible
    final crossAxisCount = _calculateCrossAxisCount(context, dimensions);
    final row = index ~/ crossAxisCount;
    final rowHeight = dimensions.channelCardHeight + dimensions.gridSpacing;
    final targetOffset = row * rowHeight;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  TvInputResult _handleNavigation(TvInputKey key, List<IPTVChannel> channels) {
    // Debounce rapid inputs
    if (_shouldDebounce()) {
      return TvInputResult.handled;
    }

    // Handle Fire TV channel up/down for quick channel switching
    if (key.isChannelKey && channels.isNotEmpty) {
      final currentIndex = _currentFocusedIndex;
      int newIndex;

      if (key == TvInputKey.channelUp) {
        // Move to previous channel (wrap to end if at start)
        newIndex = currentIndex > 0 ? currentIndex - 1 : channels.length - 1;
      } else {
        // Move to next channel (wrap to start if at end)
        newIndex = currentIndex < channels.length - 1 ? currentIndex + 1 : 0;
      }

      // Select the channel directly
      widget.onChannelSelect(channels[newIndex]);
      return TvInputResult.handled;
    }

    // Navigation is handled by Flutter's focus system
    // This is for additional key handling
    switch (key) {
      case TvInputKey.back:
        Navigator.of(context).maybePop();
        return TvInputResult.handled;
      default:
        return TvInputResult.notHandled;
    }
  }
}

/// TV-optimized channel card with focus support
///
/// Includes semantic labels for screen reader support (CP-AC-003)
class _TvChannelCard extends StatelessWidget {
  final IPTVChannel channel;
  final TvUiDimensions dimensions;
  final bool isPlaying;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback? onFocus;

  const _TvChannelCard({
    super.key,
    required this.channel,
    required this.dimensions,
    required this.isPlaying,
    required this.autofocus,
    required this.onSelect,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    // Build semantic label for screen readers (CP-AC-003)
    final semanticLabel = isPlaying
        ? '${channel.name}, currently playing'
        : channel.name;
    final semanticHint = isPlaying
        ? 'Press OK to view controls'
        : 'Press OK to play channel';

    return TvFocusable(
      onSelect: onSelect,
      onFocus: onFocus,
      autofocus: autofocus,
      focusColor: isPlaying ? Colors.green : null,
      // Accessibility: semantic labels for screen readers (CP-AC-003)
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      semanticButton: true,
      child: Container(
        decoration: BoxDecoration(
          color: isPlaying
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey[850],
          borderRadius: BorderRadius.circular(
            TvFocusConstants.focusBorderRadius,
          ),
          border: isPlaying ? Border.all(color: Colors.green, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Channel logo
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(dimensions.cardPadding),
                child: _buildChannelLogo(),
              ),
            ),
            // Channel name
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dimensions.cardPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14 * dimensions.textScaleFactor,
                        fontWeight: isPlaying
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isPlaying) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            size: 14 * dimensions.textScaleFactor,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Now Playing',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11 * dimensions.textScaleFactor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelLogo() {
    if (channel.hasLogo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          channel.logoUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildDefaultIcon(),
        ),
      );
    }
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return AppIconPlaceholder.channel(isAudioOnly: channel.isAudioOnly);
  }
}
