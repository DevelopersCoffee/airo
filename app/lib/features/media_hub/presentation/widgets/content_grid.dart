import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/unified_media_content.dart';
import 'media_content_card.dart';

/// A responsive grid layout for displaying TV content.
///
/// Uses a 2-column layout on mobile, 3-column on tablet, and 4-column on desktop.
/// Integrates with the discovery provider for content filtering.
class ContentGrid extends ConsumerWidget {
  const ContentGrid({
    super.key,
    required this.content,
    this.onItemTap,
    this.onItemLongPress,
    this.padding = const EdgeInsets.all(8),
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.childAspectRatio,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
  });

  /// List of content items to display
  final List<UnifiedMediaContent> content;

  /// Callback when an item is tapped
  final void Function(UnifiedMediaContent)? onItemTap;

  /// Callback when an item is long-pressed
  final void Function(UnifiedMediaContent)? onItemLongPress;

  /// Padding around the grid
  final EdgeInsets padding;

  /// Horizontal spacing between items
  final double crossAxisSpacing;

  /// Vertical spacing between items
  final double mainAxisSpacing;

  /// Custom aspect ratio for grid items (default: 0.75)
  final double? childAspectRatio;

  /// Optional scroll controller
  final ScrollController? scrollController;

  /// Scroll physics
  final ScrollPhysics? physics;

  /// Whether to shrink wrap the grid
  final bool shrinkWrap;

  /// Mobile breakpoint (< 600dp)
  static const double mobileBreakpoint = 600;

  /// Tablet breakpoint (< 1200dp)
  static const double tabletBreakpoint = 1200;

  /// Default columns for mobile
  static const int mobileColumns = 2;

  /// Default columns for tablet
  static const int tabletColumns = 3;

  /// Default columns for desktop
  static const int desktopColumns = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (content.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _getColumnCount(constraints.maxWidth);
        final aspectRatio = childAspectRatio ?? MediaContentCard.aspectRatio;

        return GridView.builder(
          controller: scrollController,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: content.length,
          itemBuilder: (context, index) {
            final item = content[index];
            return MediaContentCard(
              content: item,
              onTap: onItemTap != null ? () => onItemTap!(item) : null,
              onLongPress: onItemLongPress != null ? () => onItemLongPress!(item) : null,
            );
          },
        );
      },
    );
  }

  int _getColumnCount(double width) {
    if (width < mobileBreakpoint) {
      return mobileColumns;
    } else if (width < tabletBreakpoint) {
      return tabletColumns;
    } else {
      return desktopColumns;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              semanticLabel: 'No content',
            ),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or check back later',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A sliver version of ContentGrid for use in CustomScrollView
class SliverContentGrid extends ConsumerWidget {
  const SliverContentGrid({
    super.key,
    required this.content,
    this.onItemTap,
    this.onItemLongPress,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.childAspectRatio,
  });

  final List<UnifiedMediaContent> content;
  final void Function(UnifiedMediaContent)? onItemTap;
  final void Function(UnifiedMediaContent)? onItemLongPress;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double? childAspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (content.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = _getColumnCount(width);
        final aspectRatio = childAspectRatio ?? MediaContentCard.aspectRatio;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: aspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = content[index];
              return MediaContentCard(
                content: item,
                onTap: onItemTap != null ? () => onItemTap!(item) : null,
                onLongPress: onItemLongPress != null ? () => onItemLongPress!(item) : null,
              );
            },
            childCount: content.length,
          ),
        );
      },
    );
  }

  int _getColumnCount(double width) {
    if (width < ContentGrid.mobileBreakpoint) {
      return ContentGrid.mobileColumns;
    } else if (width < ContentGrid.tabletBreakpoint) {
      return ContentGrid.tabletColumns;
    } else {
      return ContentGrid.desktopColumns;
    }
  }
}

