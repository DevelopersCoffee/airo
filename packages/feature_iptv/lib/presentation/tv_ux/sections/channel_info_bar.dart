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
    this.autofocus = false,
    this.compact = false,
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

  /// Seeds D-pad focus here when this is the topmost visible ten-foot chrome
  /// row. Every [TvFocusable] below gets the same value: only the first one
  /// actually mounted claims it (Flutter's autofocus is a no-op once a scope
  /// already has a focused descendant), so this stays correct regardless of
  /// which optional icons are present.
  final bool autofocus;

  /// Renders the dense two-line editorial header (name, then category ·
  /// LIVE pill) used on the phone-width touch/cursor layout. False keeps
  /// the original single-line, larger-text treatment this row has always
  /// had on the ten-foot D-pad layout — shrinking that text to fit a
  /// second line would cut against 10ft legibility at TV viewing distance,
  /// and the D-pad flavor was never part of the editorial redesign request.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = channel?.name ?? 'Choose a channel';
    final isFavorite = channel != null
        ? ref.watch(isChannelFavoriteProvider(channel!.id))
        : false;
    final category = channel != null
        ? (categoryDisplayLabel(channel!.group) ?? channel!.group)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ChannelLogo(
            logoUrl: channel?.effectiveLogoUrl,
            channelName: name,
            size: compact ? 36 : 32,
            isAudioOnly: channel?.isAudioOnly ?? false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: compact
                ? _CompactHeader(
                    name: name,
                    category: category,
                    showMeta: channel != null,
                  )
                : Text(name, overflow: TextOverflow.ellipsis),
          ),
          if (!compact) const Chip(label: Text('LIVE')),
          if (onHelpTap != null)
            TvFocusable(
              autofocus: autofocus,
              key: const ValueKey('airo-tv-shell-help-action'),
              semanticLabel: 'Aika Stream Help',
              onSelect: onHelpTap,
              child: IconButton(
                onPressed: onHelpTap,
                tooltip: 'Aika Stream Help',
                icon: const Icon(Icons.help_outline),
              ),
            ),
          if (onPlaylistSourceTap != null)
            TvFocusable(
              autofocus: autofocus,
              semanticLabel: 'Playlist source',
              onSelect: onPlaylistSourceTap,
              child: IconButton(
                onPressed: onPlaylistSourceTap,
                tooltip: 'Playlist source',
                icon: const Icon(Icons.link),
              ),
            ),
          TvFocusable(
            autofocus: autofocus,
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
              autofocus: autofocus,
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
              autofocus: autofocus,
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
            autofocus: autofocus,
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

/// Two-line editorial header (name, then category · LIVE pill) used only
/// on the compact touch/cursor layout — see [ChannelInfoBar.compact].
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.name,
    required this.category,
    required this.showMeta,
  });

  final String name;
  final String? category;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 15,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (showMeta) ...[
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (category != null && category!.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    category!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 1.1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '·',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const AiroBadge(
                label: 'LIVE',
                variant: AiroBadgeVariant.live,
                size: AiroBadgeSize.sm,
                pulse: false,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
