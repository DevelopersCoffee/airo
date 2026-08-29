/// TV screen listing the user's favorited channels.
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../widgets/favorite_reimport_review_banner.dart';
import '../widgets/favorites_backup_menu.dart';
import '../widgets/iptv_icon_placeholder.dart';
import '../widgets/channel_load_error_view.dart';

/// Lists channels the user has favorited on TV, with a way to unfavorite
/// and jump straight into playback. See CV-021 / issue #826.
class TvFavoritesScreen extends ConsumerWidget {
  const TvFavoritesScreen({super.key, this.onChannelSelected});

  /// Invoked after a favorite starts playing, so a shell that paints this
  /// screen as an overlay on top of retained playback can dismiss itself
  /// and reveal the video. Null when the screen owns the whole route.
  final VoidCallback? onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteChannelsProvider);
    final currentChannel = ref.watch(currentChannelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // An opaque background is load-bearing, not decoration: TvShell stacks
    // this screen over the still-mounted live channel grid, so a bare Column
    // renders both layers' text on top of each other.
    return AiroResponsiveScaffold(
      overrideFormFactor: AiroFormFactor.tv,
      useResponsiveCenter: false,
      backgroundColor: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Favorites',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox.square(
                dimension: 32,
                child: FavoritesBackupMenu(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const FavoriteReimportReviewBanner(),
          Text(
            'Press the menu/context key on a channel to add or remove it '
            'from favorites.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: favoritesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ChannelLoadErrorView(
                message: 'Could not load favorites: $error',
                onRetry: () {
                  // Favorites can fail on its own stored list as well as on
                  // the channels it resolves against, so invalidate both.
                  invalidateChannelLibraries(ref);
                  ref.invalidate(favoriteChannelsProvider);
                },
              ),
              data: (channels) {
                if (channels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_border,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No favorite channels yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                }

                // Grid of channel tiles, matching the design handoff's
                // favorites layout (same card language as the browse rails).
                return GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 200 / 158,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    final isPlaying = currentChannel?.id == channel.id;

                    return TvFocusable(
                      autofocus: index == 0,
                      onSelect: () {
                        ref
                            .read(iptvStreamingServiceProvider)
                            .playChannel(channel);
                        onChannelSelected?.call();
                      },
                      onSecondaryAction: () {
                        ref.read(channelFavoriteTogglerProvider)(channel.id);
                      },
                      semanticLabel: channel.name,
                      semanticHint:
                          'Press OK to play this channel. Press menu to '
                          'remove from favorites.',
                      semanticButton: true,
                      borderRadius: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.56,
                                )
                              : colorScheme.surface,
                          border: Border.all(
                            color: isPlaying
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isPlaying ? 2 : 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(11),
                                    ),
                                    child: IptvIconPlaceholder.channel(
                                      isAudioOnly: channel.isAudioOnly,
                                    ),
                                  ),
                                  Positioned(
                                    top: 7,
                                    right: 7,
                                    child: Icon(
                                      Icons.favorite,
                                      color: colorScheme.error,
                                      size: 18,
                                      shadows: const [Shadow(blurRadius: 6)],
                                    ),
                                  ),
                                  if (isPlaying)
                                    Positioned(
                                      bottom: 7,
                                      right: 7,
                                      child: Icon(
                                        Icons.equalizer,
                                        color: colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    channel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    channel.group,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
