import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../../application/channel_share.dart';
import '../../../application/iptv_deep_link.dart';
import '../../../application/providers/channel_filters_provider.dart';
import '../../../application/providers/iptv_providers.dart';
import '../../widgets/channel_logo.dart';

class ChannelInfoBar extends ConsumerWidget {
  const ChannelInfoBar({
    super.key,
    this.channel,
    this.onHelpTap,
    this.onPlaylistSourceTap,
    this.onWaysToWatchTap,
    this.onScreenshotTap,
    this.showShareAction = true,
  });

  final IPTVChannel? channel;

  /// Opens Airo TV help when the video stage (and its overlay actions) is
  /// hidden by a grid-first TV layout. Null hides the button.
  final VoidCallback? onHelpTap;

  /// Whether sharing can actually reach somewhere the viewer can use.
  ///
  /// False on the ten-foot layout: `share_plus` is stubbed there, so
  /// [_copyShareDetails] always falls through to the clipboard — and a
  /// remote has nowhere to paste it. The button reported "share message
  /// copied" for a clipboard the user could never open.
  final bool showShareAction;

  /// Opens the playlist-source sheet. Wired on TV where the phone app bar
  /// (the usual home of this action) is suppressed; null hides the button.
  final VoidCallback? onPlaylistSourceTap;

  /// Opens the capability-aware fit/full/floating/Cast chooser.
  final VoidCallback? onWaysToWatchTap;

  /// Captures and shares only the current video frame when the host supports
  /// image delivery.
  final VoidCallback? onScreenshotTap;

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
          if (onHelpTap != null)
            TvFocusable(
              key: const ValueKey('airo-tv-shell-help-action'),
              semanticLabel: 'Midas Stream Help',
              onSelect: onHelpTap,
              child: IconButton(
                onPressed: onHelpTap,
                tooltip: 'Midas Stream Help',
                icon: const Icon(Icons.help_outline),
              ),
            ),
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
          if (showShareAction)
            TvFocusable(
              semanticLabel: 'Share',
              enabled: channel != null,
              onSelect: channel == null
                  ? null
                  : () => _copyShareDetails(context, ref, channel!),
              child: IconButton(
                onPressed: channel == null
                    ? null
                    : () => _copyShareDetails(context, ref, channel!),
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
              ),
            ),
          if (onScreenshotTap != null)
            TvFocusable(
              key: const ValueKey('channel-info-screenshot'),
              semanticLabel: 'Share video frame',
              enabled: channel != null,
              onSelect: channel == null ? null : onScreenshotTap,
              child: IconButton(
                onPressed: channel == null ? null : onScreenshotTap,
                tooltip: 'Share video frame',
                icon: const Icon(Icons.photo_camera_outlined),
              ),
            ),
          TvFocusable(
            key: const ValueKey('channel-info-ways-to-watch'),
            semanticLabel: 'Ways to Watch',
            enabled: channel != null && onWaysToWatchTap != null,
            onSelect: channel == null ? null : onWaysToWatchTap,
            child: IconButton(
              onPressed: channel == null ? null : onWaysToWatchTap,
              tooltip: 'Ways to Watch',
              icon: const Icon(Icons.monitor_outlined),
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
    WidgetRef ref,
    IPTVChannel selectedChannel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final filters = ref.read(channelFiltersProvider);
      final shareValidation = AiroPlaylistUrlPolicy.validateShareStreamUrl(
        selectedChannel.streamUrl,
      );
      final link = IptvDeepLinkIntent(
        channelId: selectedChannel.id,
        filters: filters,
        channelName: shareValidation.isAllowed ? selectedChannel.name : null,
        streamUrl: shareValidation.uri,
      ).toUri();
      final message = ref
          .read(channelShareMessageComposerProvider)
          .compose(
            channelName: selectedChannel.name,
            link: link,
            isPlayable: shareValidation.isAllowed,
          );
      final shared = await ref
          .read(channelShareGatewayProvider)
          .share(
            subject: 'Watch ${selectedChannel.name} in Airo',
            text: message,
          );
      if (!shared) {
        await Clipboard.setData(ClipboardData(text: message));
      }
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              shared
                  ? '${selectedChannel.name} ready to share'
                  : '${selectedChannel.name} share message copied',
            ),
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
