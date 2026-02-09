import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/unified_media_content.dart';
import 'media_content_card.dart';

/// A horizontal carousel for displaying music content.
///
/// Displays content in a horizontally scrolling list with optional section title.
/// Supports responsive card sizing based on screen width.
class ContentCarousel extends ConsumerWidget {
  const ContentCarousel({
    super.key,
    required this.content,
    this.title,
    this.onItemTap,
    this.onItemLongPress,
    this.onSeeAllTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.itemSpacing = 12,
    this.itemWidth,
    this.itemHeight,
    this.showSeeAll = true,
  });

  /// List of content items to display
  final List<UnifiedMediaContent> content;

  /// Optional section title
  final String? title;

  /// Callback when an item is tapped
  final void Function(UnifiedMediaContent)? onItemTap;

  /// Callback when an item is long-pressed
  final void Function(UnifiedMediaContent)? onItemLongPress;

  /// Callback when "See All" is tapped
  final VoidCallback? onSeeAllTap;

  /// Padding around the carousel
  final EdgeInsets padding;

  /// Spacing between items
  final double itemSpacing;

  /// Fixed width for each item (default: responsive)
  final double? itemWidth;

  /// Fixed height for each item (default: responsive)
  final double? itemHeight;

  /// Whether to show "See All" button
  final bool showSeeAll;

  /// Default card width on mobile
  static const double mobileCardWidth = 140;

  /// Default card width on tablet
  static const double tabletCardWidth = 160;

  /// Default card width on desktop
  static const double desktopCardWidth = 180;

  /// Default card height multiplier (based on aspect ratio)
  static const double cardHeightMultiplier = 1.33;

  /// Carousel height including title
  static const double carouselHeight = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header with title and "See All"
        if (title != null) _buildHeader(context),
        // Horizontal list
        SizedBox(
          height: itemHeight ?? _getCardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: content.length,
            separatorBuilder: (_, __) => SizedBox(width: itemSpacing),
            itemBuilder: (context, index) {
              final item = content[index];
              return SizedBox(
                width: itemWidth ?? _getCardWidth(context),
                child: MediaContentCard(
                  content: item,
                  onTap: onItemTap != null ? () => onItemTap!(item) : null,
                  onLongPress: onItemLongPress != null ? () => onItemLongPress!(item) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showSeeAll && onSeeAllTap != null)
            TextButton(
              onPressed: onSeeAllTap,
              child: Text(
                'See All',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _getCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      return mobileCardWidth;
    } else if (width < 1200) {
      return tabletCardWidth;
    } else {
      return desktopCardWidth;
    }
  }

  double _getCardHeight(BuildContext context) {
    return _getCardWidth(context) * cardHeightMultiplier;
  }
}

/// A section widget that combines a title with a carousel
class ContentSection extends ConsumerWidget {
  const ContentSection({
    super.key,
    required this.title,
    required this.content,
    this.onItemTap,
    this.onItemLongPress,
    this.onSeeAllTap,
  });

  final String title;
  final List<UnifiedMediaContent> content;
  final void Function(UnifiedMediaContent)? onItemTap;
  final void Function(UnifiedMediaContent)? onItemLongPress;
  final VoidCallback? onSeeAllTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ContentCarousel(
        title: title,
        content: content,
        onItemTap: onItemTap,
        onItemLongPress: onItemLongPress,
        onSeeAllTap: onSeeAllTap,
      ),
    );
  }
}

