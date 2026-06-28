import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../media_hub/application/providers/personalization_provider.dart';
import '../../../media_hub/domain/models/media_mode.dart';
import '../../../media_hub/domain/models/personalization_state.dart';
import '../../../media_hub/domain/models/unified_media_content.dart';
import '../../../media_hub/presentation/widgets/personalization_carousel.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../../iptv/presentation/screens/iptv_screen.dart';
import '../../../music/application/providers/music_provider.dart';
import '../../../music/application/providers/music_tracks_provider.dart';
import '../../../music/presentation/screens/music_screen.dart';

enum MediaSection { music, tv }

List<UnifiedMediaContent> recentItemsForSection(
  PersonalizationState state,
  MediaSection section,
) {
  final mode = switch (section) {
    MediaSection.music => MediaMode.music,
    MediaSection.tv => MediaMode.tv,
  };
  return state.recentlyPlayed
      .where((item) => item.mode == mode)
      .take(20)
      .toList();
}

List<UnifiedMediaContent> favoriteItemsForSection(
  PersonalizationState state,
  MediaSection section,
) {
  final mode = switch (section) {
    MediaSection.music => MediaMode.music,
    MediaSection.tv => MediaMode.tv,
  };
  return state.favorites.where((item) => item.mode == mode).toList();
}

List<UnifiedMediaContent> continueWatchingItemsForSection(
  PersonalizationState state,
  MediaSection section,
) {
  final mode = switch (section) {
    MediaSection.music => MediaMode.music,
    MediaSection.tv => MediaMode.tv,
  };
  return state.continueWatching
      .where(
        (item) =>
            item.mode == mode &&
            item.canResume &&
            item.lastPosition > const Duration(seconds: 10),
      )
      .take(20)
      .toList();
}

class MediaHubScreen extends ConsumerWidget {
  const MediaHubScreen({super.key, required this.section});

  final MediaSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalization = ref.watch(personalizationProvider);
    final personalizationNotifier = ref.read(personalizationProvider.notifier);
    final state = personalization.valueOrNull;
    final favoriteItems = state == null
        ? const <UnifiedMediaContent>[]
        : favoriteItemsForSection(state, section);
    final continueWatchingItems = state == null
        ? const <UnifiedMediaContent>[]
        : continueWatchingItemsForSection(state, section);
    final recentItems = personalization.valueOrNull == null
        ? const <UnifiedMediaContent>[]
        : recentItemsForSection(personalization.valueOrNull!, section);

    return Column(
      children: [
        _MediaModeBar(section: section),
        PersonalizationCarousel(
          title: 'Favorites',
          items: favoriteItems,
          showFavoriteButton: true,
          isFavorite: (_) => true,
          onFavoriteToggle: (item) {
            personalizationNotifier.toggleFavorite(item);
          },
        ),
        PersonalizationCarousel(
          title: 'Continue Watching',
          items: continueWatchingItems,
          onSelected: (item) async {
            await _resumeItem(ref, item);
          },
        ),
        PersonalizationCarousel(title: 'Recently Played', items: recentItems),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (section) {
              MediaSection.music => const MusicScreenBody(
                key: ValueKey('media-music'),
              ),
              MediaSection.tv => const IPTVScreenBody(
                key: ValueKey('media-tv'),
              ),
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _resumeItem(WidgetRef ref, UnifiedMediaContent item) async {
  switch (item.mode) {
    case MediaMode.music:
      final tracks = await ref.read(musicTracksProvider.future);
      final track = _findById(tracks, item.id);
      if (track == null) return;
      final controller = ref.read(musicControllerProvider);
      await controller.playTrack(track);
      await controller.seek(item.lastPosition);
    case MediaMode.tv:
      final channels = await ref.read(iptvChannelsProvider.future);
      final channel = _findById(channels, item.id);
      if (channel == null) return;
      final service = ref.read(iptvStreamingServiceProvider);
      await service.playChannel(channel);
      await service.seek(item.lastPosition);
  }
}

T? _findById<T>(Iterable<T> items, String id) {
  for (final item in items) {
    final dynamic value = item;
    if (value.id == id) {
      return item;
    }
  }
  return null;
}

class _MediaModeBar extends StatelessWidget {
  const _MediaModeBar({required this.section});

  final MediaSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
          right: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _MediaModeButton(
                label: 'Music',
                icon: Icons.music_note,
                selected: section == MediaSection.music,
                onTap: () => context.go('/media/music'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MediaModeButton(
                label: 'TV',
                icon: Icons.live_tv,
                selected: section == MediaSection.tv,
                onTap: () => context.go('/media/tv'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaModeButton extends StatelessWidget {
  const _MediaModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surface.withValues(alpha: 0.18),
      child: InkWell(
        onTap: selected ? null : onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
