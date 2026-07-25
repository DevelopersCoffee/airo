import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../../application/providers/iptv_providers.dart';
import '../../widgets/channel_logo.dart';

class ChannelInfoBar extends ConsumerWidget {
  const ChannelInfoBar({super.key, this.channel, this.onPlaylistSourceTap});

  final IPTVChannel? channel;

  /// Opens the playlist-source sheet. Wired on TV where the phone app bar
  /// (the usual home of this action) is suppressed; null hides the button.
  final VoidCallback? onPlaylistSourceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = channel?.name ?? 'Choose a channel';
    final isFavorite = channel != null
        ? ref.watch(isChannelFavoriteProvider(channel!.id))
        : false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChannelLogo(
            logoUrl: channel?.effectiveLogoUrl,
            channelName: name,
            size: 32,
            isAudioOnly: channel?.isAudioOnly ?? false,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          const Chip(label: Text('LIVE')),
          if (onPlaylistSourceTap != null)
            TvFocusable(
              semanticLabel: 'Playlist source',
              onSelect: onPlaylistSourceTap,
              child: IconButton(
                onPressed: onPlaylistSourceTap,
                tooltip: 'Playlist source',
                icon: const Icon(Icons.link),
              ),
            ),
          TvFocusable(
            semanticLabel: isFavorite ? 'Remove from favorites' : 'Favorite',
            enabled: channel != null,
            onSelect: channel == null
                ? null
                : () => _toggleFavorite(context, ref, channel!),
            child: IconButton(
              onPressed: channel == null
                  ? null
                  : () => _toggleFavorite(context, ref, channel!),
              tooltip: isFavorite ? 'Remove from favorites' : 'Favorite',
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            ),
          ),
          TvFocusable(
            semanticLabel: 'Share',
            enabled: channel != null,
            onSelect: channel == null
                ? null
                : () => _copyShareDetails(context, channel!),
            child: IconButton(
              onPressed: channel == null
                  ? null
                  : () => _copyShareDetails(context, channel!),
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    IPTVChannel selectedChannel,
  ) async {
    try {
      final isNowFavorite = await ref.read(channelFavoriteTogglerProvider)(
        selectedChannel.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite
                  ? '${selectedChannel.name} added to favorites'
                  : '${selectedChannel.name} removed from favorites',
            ),
          ),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not update favorites.')),
        );
    }
  }

  Future<void> _copyShareDetails(
    BuildContext context,
    IPTVChannel selectedChannel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(
        ClipboardData(
          text: '${selectedChannel.name}\n${selectedChannel.streamUrl}',
        ),
      );
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${selectedChannel.name} copied to clipboard'),
          ),
        );
    } catch (_) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not copy channel details.')),
        );
    }
  }
}
