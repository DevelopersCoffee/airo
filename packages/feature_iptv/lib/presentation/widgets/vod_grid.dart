import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/vod_providers.dart';
import '../tv/iptv_tv.dart';

/// TV-optimized grid of VOD movies and series groups. A series group card
/// carries its first episode's [VodItem] in [onItemSelect] for now — full
/// per-episode selection (opening an episode list) is presentation-layer
/// work the screen (not this widget) composes on top, per this issue's
/// scope (no per-title detail page, see CV-019 non-goals).
///
/// Deliberately simpler than [TvChannelGrid]: no thumbnail preloading and
/// no D-pad channel-up/down debounce logic — VOD lists don't need Fire TV
/// channel-key handling and are typically much shorter than full channel
/// lists.
class VodGrid extends ConsumerWidget {
  const VodGrid({super.key, this.onItemSelect});

  final void Function(VodItem item)? onItemSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(filteredVodMoviesProvider);
    final seriesGroups = ref.watch(filteredVodSeriesGroupsProvider);
    final dimensions = ref.watch(tvDimensionsProvider(context));

    if (movies.isEmpty && seriesGroups.isEmpty) {
      return const Center(
        child: Text(
          'No movies or shows found',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    final tileCount = movies.length + seriesGroups.length;
    final padding =
        EdgeInsets.all(dimensions.gridSpacing) + dimensions.safeZone;

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount(context, dimensions),
        childAspectRatio:
            dimensions.channelCardWidth / dimensions.channelCardHeight,
        mainAxisSpacing: dimensions.gridSpacing,
        crossAxisSpacing: dimensions.gridSpacing,
      ),
      itemCount: tileCount,
      itemBuilder: (context, index) {
        if (index < movies.length) {
          final movie = movies[index];
          return _VodCard(
            key: ValueKey('vod_movie_card_${movie.id}'),
            title: movie.title,
            posterUrl: movie.posterUrl,
            dimensions: dimensions,
            autofocus: index == 0,
            onSelect: () => onItemSelect?.call(movie),
          );
        }
        final group = seriesGroups[index - movies.length];
        return _VodCard(
          key: ValueKey('vod_series_card_${group.seriesId}'),
          title: group.seriesTitle,
          posterUrl: group.episodes.first.posterUrl,
          dimensions: dimensions,
          autofocus: movies.isEmpty && index == movies.length,
          onSelect: () => onItemSelect?.call(group.episodes.first),
        );
      },
    );
  }

  int _crossAxisCount(BuildContext context, TvUiDimensions dimensions) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (dimensions.gridSpacing * 2);
    final cardWidth = dimensions.channelCardWidth + dimensions.gridSpacing;
    return (availableWidth / cardWidth).floor().clamp(3, 8);
  }
}

class _VodCard extends StatelessWidget {
  const _VodCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.dimensions,
    required this.autofocus,
    required this.onSelect,
  });

  final String title;
  final String? posterUrl;
  final TvUiDimensions dimensions;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TvFocusable(
        onSelect: onSelect,
        autofocus: autofocus,
        semanticLabel: title,
        semanticHint: 'Press OK to open',
        semanticButton: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(
              TvFocusConstants.focusBorderRadius,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.all(dimensions.cardPadding),
                  child: posterUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AiroNetworkImage(
                            url: posterUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.movie,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                          ),
                        )
                      : const Icon(
                          Icons.movie,
                          color: Colors.white54,
                          size: 48,
                        ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dimensions.cardPadding,
                  ),
                  child: Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * dimensions.textScaleFactor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
