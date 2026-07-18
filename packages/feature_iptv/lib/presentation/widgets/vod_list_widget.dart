import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/vod_providers.dart';

/// Phone-oriented VOD list: a search bar plus a scrollable list of movies
/// and series groups, mirroring `ChannelListWidget`'s layout pattern for
/// live channels.
class VodListWidget extends ConsumerWidget {
  const VodListWidget({super.key, this.onItemTap, this.onAddSubtitleTap});

  final void Function(VodItem item)? onItemTap;

  /// Optional "add external subtitle" action, rendered as a trailing icon
  /// button on each tile when provided. VOD-only per CV-031's scope — live
  /// channels never pass this callback.
  final void Function(VodItem item)? onAddSubtitleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(filteredVodMoviesProvider);
    final seriesGroups = ref.watch(filteredVodSeriesGroupsProvider);
    final searchQuery = ref.watch(vodSearchQueryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            height: 44,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search movies and shows',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            ref.read(vodSearchQueryProvider.notifier).state =
                                '',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
              onChanged: (value) =>
                  ref.read(vodSearchQueryProvider.notifier).state = value,
            ),
          ),
        ),
        if (movies.isEmpty && seriesGroups.isEmpty)
          const Expanded(child: _EmptyState())
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final movie in movies)
                  _VodListTile(
                    key: ValueKey('vod_movie_tile_${movie.id}'),
                    title: movie.title,
                    subtitle: null,
                    posterUrl: movie.posterUrl,
                    fallbackIcon: Icons.movie,
                    onTap: () => onItemTap?.call(movie),
                    onAddSubtitleTap: onAddSubtitleTap == null
                        ? null
                        : () => onAddSubtitleTap!(movie),
                    addSubtitleKey: ValueKey(
                      'vod-add-subtitle-button-${movie.id}',
                    ),
                  ),
                for (final group in seriesGroups)
                  _VodListTile(
                    key: ValueKey('vod_series_tile_${group.seriesId}'),
                    title: group.seriesTitle,
                    subtitle: '${group.episodes.length} episodes',
                    posterUrl: group.episodes.first.posterUrl,
                    fallbackIcon: Icons.video_library,
                    onTap: () => onItemTap?.call(group.episodes.first),
                    onAddSubtitleTap: onAddSubtitleTap == null
                        ? null
                        : () => onAddSubtitleTap!(group.episodes.first),
                    addSubtitleKey: ValueKey(
                      'vod-add-subtitle-button-${group.episodes.first.id}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_filter, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No movies or shows found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _VodListTile extends StatelessWidget {
  const _VodListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.posterUrl,
    required this.fallbackIcon,
    required this.onTap,
    this.onAddSubtitleTap,
    this.addSubtitleKey,
  });

  final String title;
  final String? subtitle;
  final String? posterUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final VoidCallback? onAddSubtitleTap;
  final Key? addSubtitleKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.42),
                      child: posterUrl != null
                          ? AiroNetworkImage(
                              url: posterUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(fallbackIcon, color: Colors.grey),
                            )
                          : Icon(fallbackIcon, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onAddSubtitleTap != null)
                    IconButton(
                      key: addSubtitleKey,
                      icon: const Icon(Icons.subtitles_outlined),
                      tooltip: 'Add subtitle URL',
                      onPressed: onAddSubtitleTap,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
