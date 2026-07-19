import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../widgets/iptv_icon_placeholder.dart';

/// Mobile screen listing the user's favorited channels — the mobile
/// counterpart to [TvFavoritesScreen], with a tap-to-unfavorite trailing
/// icon replacing TV's D-pad secondary action. See CV item 4 / issue #826.
class MobileFavoritesScreen extends ConsumerWidget {
  const MobileFavoritesScreen({required this.onChannelSelected, super.key});

  /// Invoked after a favorited channel starts playing, so the caller can
  /// pop back to the now-playing screen (matches [IptvGuideScreen]'s
  /// `onChannelSelected` pattern).
  final VoidCallback onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteChannelsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load favorites: $error')),
        data: (channels) {
          if (channels.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border, size: 64, color: colorScheme.primary),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: channels.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final channel = channels[index];

              return ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: IptvIconPlaceholder.channel(
                      isAudioOnly: channel.isAudioOnly,
                    ),
                  ),
                ),
                title: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  channel.group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.favorite, color: colorScheme.error),
                  tooltip: 'Remove from favorites',
                  onPressed: () =>
                      ref.read(toggleChannelFavoriteProvider(channel.id)),
                ),
                onTap: () {
                  ref.read(iptvStreamingServiceProvider).playChannel(channel);
                  ref.read(addToRecentlyWatchedProvider(channel));
                  onChannelSelected();
                },
              );
            },
          );
        },
      ),
    );
  }
}
