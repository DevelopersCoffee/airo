/// TV screen listing the user's favorited channels.
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../widgets/iptv_icon_placeholder.dart';

/// Lists channels the user has favorited on TV, with a way to unfavorite
/// and jump straight into playback. See CV-021 / issue #826.
class TvFavoritesScreen extends ConsumerWidget {
  const TvFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteChannelsProvider);
    final currentChannel = ref.watch(currentChannelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Favorites', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Press the menu/context key on a channel to add or remove it '
            'from favorites.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: favoritesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Could not load favorites: $error'),
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

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: channels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    final isPlaying = currentChannel?.id == channel.id;

                    return TvFocusable(
                      autofocus: index == 0,
                      onSelect: () {
                        ref
                            .read(iptvStreamingServiceProvider)
                            .playChannel(channel);
                        ref.read(addToRecentlyWatchedProvider(channel));
                      },
                      onSecondaryAction: () {
                        ref.read(toggleChannelFavoriteProvider(channel.id));
                      },
                      semanticLabel: channel.name,
                      semanticHint:
                          'Press OK to play this channel. Press menu to '
                          'remove from favorites.',
                      semanticButton: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.56,
                                )
                              : colorScheme.surface.withValues(alpha: 0.6),
                          border: Border.all(
                            color: isPlaying
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: IptvIconPlaceholder.channel(
                                  isAudioOnly: channel.isAudioOnly,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      channel.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      channel.group,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.star,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              if (isPlaying) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.equalizer,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
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
