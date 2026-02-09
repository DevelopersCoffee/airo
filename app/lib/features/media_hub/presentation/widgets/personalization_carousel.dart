import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/media_hub_providers.dart';
import '../../application/providers/personalization_provider.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';
import 'content_carousel.dart';

/// Type of personalization section to display
enum PersonalizationSectionType {
  /// Shows partially watched/listened content that can be resumed
  continueWatching,

  /// Shows recently played content
  recentlyPlayed,

  /// Shows favorited content
  favorites,
}

/// A carousel that displays personalized content based on section type.
///
/// Automatically filters content by the current media mode (Music/TV).
/// Provides tap-to-resume functionality for continue watching items.
class PersonalizationCarousel extends ConsumerWidget {
  const PersonalizationCarousel({
    super.key,
    required this.sectionType,
    this.onItemTap,
    this.onItemLongPress,
    this.onSeeAllTap,
    this.showSeeAll = true,
    this.maxItems,
  });

  /// The type of personalization section to display
  final PersonalizationSectionType sectionType;

  /// Callback when an item is tapped
  /// Default behavior: resume playback for continue watching
  final void Function(UnifiedMediaContent)? onItemTap;

  /// Callback when an item is long-pressed
  final void Function(UnifiedMediaContent)? onItemLongPress;

  /// Callback when "See All" is tapped
  final VoidCallback? onSeeAllTap;

  /// Whether to show the "See All" button
  final bool showSeeAll;

  /// Maximum number of items to display (null = unlimited)
  final int? maxItems;

  /// Minimum items to show section (avoid showing 1 item)
  static const int minItemsToShow = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(selectedMediaModeProvider);
    final content = _getContentForSection(ref, currentMode);

    if (content.length < minItemsToShow) {
      return const SizedBox.shrink();
    }

    final displayContent = maxItems != null
        ? content.take(maxItems!).toList()
        : content;

    return ContentCarousel(
      title: _getTitleForSection(),
      content: displayContent,
      onItemTap: onItemTap ?? (item) => _handleDefaultTap(ref, item),
      onItemLongPress: onItemLongPress,
      onSeeAllTap: showSeeAll ? onSeeAllTap : null,
      showSeeAll: showSeeAll && content.length > (maxItems ?? 10),
      showFavoriteButton: true,
      isFavoriteCallback: (contentId) =>
          ref.read(personalizationProvider).isFavorite(contentId),
      onFavoriteToggle: (contentId) =>
          ref.read(personalizationProvider.notifier).toggleFavorite(contentId),
    );
  }

  List<UnifiedMediaContent> _getContentForSection(
    WidgetRef ref,
    MediaMode mode,
  ) {
    final personalization = ref.watch(personalizationProvider);

    switch (sectionType) {
      case PersonalizationSectionType.continueWatching:
        return personalization.continueWatching
            .where((c) => c.type == mode)
            .toList();
      case PersonalizationSectionType.recentlyPlayed:
        return personalization.recentlyPlayed
            .where((c) => c.type == mode)
            .toList();
      case PersonalizationSectionType.favorites:
        // Favorites are stored as IDs, need to get from recently played
        // This is a limitation - ideally we'd have a separate favorites list
        return personalization.recentlyPlayed
            .where(
              (c) =>
                  c.type == mode && personalization.favoriteIds.contains(c.id),
            )
            .toList();
    }
  }

  String _getTitleForSection() {
    switch (sectionType) {
      case PersonalizationSectionType.continueWatching:
        return 'Continue Watching';
      case PersonalizationSectionType.recentlyPlayed:
        return 'Recently Played';
      case PersonalizationSectionType.favorites:
        return 'Favorites';
    }
  }

  void _handleDefaultTap(WidgetRef ref, UnifiedMediaContent item) {
    if (sectionType == PersonalizationSectionType.continueWatching) {
      // Resume from last position
      final position = ref
          .read(personalizationProvider)
          .getLastPosition(item.id);
      if (position != null) {
        // TODO: Integrate with actual player to seek to position
        debugPrint('Resume ${item.title} from ${position.inSeconds}s');
      }
    }
    // For other section types, the onItemTap callback should be provided
  }
}

/// A convenience widget that displays the Continue Watching section
class ContinueWatchingSection extends ConsumerWidget {
  const ContinueWatchingSection({
    super.key,
    this.onItemTap,
    this.onSeeAllTap,
    this.maxItems = 10,
  });

  final void Function(UnifiedMediaContent)? onItemTap;
  final VoidCallback? onSeeAllTap;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PersonalizationCarousel(
        sectionType: PersonalizationSectionType.continueWatching,
        onItemTap: onItemTap,
        onSeeAllTap: onSeeAllTap,
        maxItems: maxItems,
      ),
    );
  }
}

/// A convenience widget that displays the Recently Played section
class RecentlyPlayedSection extends ConsumerWidget {
  const RecentlyPlayedSection({
    super.key,
    this.onItemTap,
    this.onSeeAllTap,
    this.maxItems = 20,
  });

  final void Function(UnifiedMediaContent)? onItemTap;
  final VoidCallback? onSeeAllTap;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PersonalizationCarousel(
        sectionType: PersonalizationSectionType.recentlyPlayed,
        onItemTap: onItemTap,
        onSeeAllTap: onSeeAllTap,
        maxItems: maxItems,
      ),
    );
  }
}

/// A convenience widget that displays the Favorites section
class FavoritesSection extends ConsumerWidget {
  const FavoritesSection({
    super.key,
    this.onItemTap,
    this.onSeeAllTap,
    this.maxItems,
  });

  final void Function(UnifiedMediaContent)? onItemTap;
  final VoidCallback? onSeeAllTap;
  final int? maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PersonalizationCarousel(
        sectionType: PersonalizationSectionType.favorites,
        onItemTap: onItemTap,
        onSeeAllTap: onSeeAllTap,
        maxItems: maxItems,
      ),
    );
  }
}
