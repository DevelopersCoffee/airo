import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../media_hub/application/providers/discovery_provider.dart';
import '../../../media_hub/domain/models/discovery_state.dart';
import '../../../media_hub/presentation/widgets/content_carousel.dart';
import '../../../media_hub/presentation/widgets/content_grid.dart';
import '../../../media_hub/application/providers/personalization_provider.dart';
import '../../../media_hub/domain/models/media_mode.dart';
import '../../../media_hub/domain/models/personalization_state.dart';
import '../../../media_hub/domain/models/unified_media_content.dart';
import '../../../media_hub/presentation/widgets/personalization_carousel.dart';
import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
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
    final state = personalization.value;
    final favoriteItems = state == null
        ? const <UnifiedMediaContent>[]
        : favoriteItemsForSection(state, section);
    final continueWatchingItems = state == null
        ? const <UnifiedMediaContent>[]
        : continueWatchingItemsForSection(state, section);
    final recentItems = personalization.value == null
        ? const <UnifiedMediaContent>[]
        : recentItemsForSection(personalization.value!, section);
    final discoveryMode = mediaModeForSection(section);
    final discovery = ref.watch(mediaHubDiscoveryProvider(discoveryMode));

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
        _DiscoverySection(
          section: section,
          discovery: discovery,
          onSelected: (item) async {
            await _openItem(ref, item);
          },
          onLoadMore: () {
            ref
                .read(mediaHubDiscoveryProvider(discoveryMode).notifier)
                .loadNextPage();
          },
        ),
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

MediaMode mediaModeForSection(MediaSection section) {
  return switch (section) {
    MediaSection.music => MediaMode.music,
    MediaSection.tv => MediaMode.tv,
  };
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

Future<void> _openItem(WidgetRef ref, UnifiedMediaContent item) async {
  await ref.read(personalizationProvider.notifier).addRecent(item);
  switch (item.mode) {
    case MediaMode.music:
      final tracks = await ref.read(musicTracksProvider.future);
      final track = _findById(tracks, item.id);
      if (track == null) return;
      await ref.read(musicControllerProvider).playTrack(track);
    case MediaMode.tv:
      final channels = await ref.read(iptvChannelsProvider.future);
      final channel = _findById(channels, item.id);
      if (channel == null) return;
      await ref.read(iptvStreamingServiceProvider).playChannel(channel);
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

class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection({
    required this.section,
    required this.discovery,
    required this.onSelected,
    required this.onLoadMore,
  });

  final MediaSection section;
  final AsyncValue<DiscoveryState> discovery;
  final ValueChanged<UnifiedMediaContent> onSelected;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final title = section == MediaSection.music
        ? 'Browse Music'
        : 'Browse Live TV';
    return discovery.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: section == MediaSection.music
            ? ContentCarousel.skeleton(title: title)
            : ContentGrid.skeleton(title: title),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Card(
          child: ListTile(
            title: Text(title),
            subtitle: Text('Unable to load discovery right now: $error'),
          ),
        ),
      ),
      data: (state) {
        final items = switch (section) {
          MediaSection.music => state.visibleItems.take(8).toList(),
          MediaSection.tv => state.visibleItems.take(4).toList(),
        };
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            section == MediaSection.music
                ? ContentCarousel(
                    title: title,
                    items: items,
                    onSelected: onSelected,
                  )
                : ContentGrid(
                    title: title,
                    items: items,
                    onSelected: onSelected,
                  ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load more'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
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
