import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import '../../application/providers/iptv_providers.dart';

/// Mini player widget for IPTV background playback
/// Shows at bottom when:
/// - Playing audio-only channels (always visible)
/// - Playing any channel when user navigates away from Stream tab
///
/// Netflix-style "now playing" bar (spec §5.5): a 58px bar with an art
/// tile (channel logo or 2-letter initials), name + category, a pulsing
/// red LIVE pill when the channel is actually live, a green Watch button
/// that returns to the full player, and a dismiss button that clears
/// now-playing. On phone this renders above the bottom NavigationBar
/// because it is the last child of the Scaffold `body` column, while the
/// NavigationBar occupies the separate `bottomNavigationBar` slot (see
/// `app/lib/core/app/app_shell.dart`) — the two never overlap.
class IPTVMiniPlayer extends ConsumerWidget {
  const IPTVMiniPlayer({super.key, this.forceVisible = false});

  final bool forceVisible;

  /// Bar height per spec §5.5.
  static const double barHeight = 58;

  /// Art tile size per spec §5.5.
  static const double artTileSize = 36;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamingState = ref.watch(streamingStateProvider);
    final currentTab = ref.watch(iptvNavigationTabProvider);

    final isOnStreamTab = currentTab == IptvNavigationTab.stream.index;

    return streamingState.when(
      data: (state) {
        final channel = state.currentChannel;

        // Don't show if no channel is playing
        if (channel == null) {
          return const SizedBox.shrink();
        }

        // Don't show if on Stream tab (video player is visible there)
        // unless it's an audio-only channel
        if (isOnStreamTab && !forceVisible) {
          return const SizedBox.shrink();
        }

        void goToPlayer() {
          ref.read(iptvNavigationTabProvider.notifier).state =
              IptvNavigationTab.stream.index;
        }

        return GestureDetector(
          key: const ValueKey('iptv-mini-player'),
          onTap: goToPlayer,
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                _MiniPlayerArtTile(channel: channel),
                const SizedBox(width: 10),

                // Channel info: name (bold) + category/group (muted)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        channel.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Red LIVE pill (pulsing dot + label), only while live.
                if (state.isLiveStream) ...[
                  const AiroBadge.live(
                    key: ValueKey('iptv-mini-player-live-pill'),
                  ),
                  const SizedBox(width: 8),
                ],

                // Green Watch button — returns to the full player.
                _WatchButton(onPressed: goToPlayer),
                const SizedBox(width: 4),

                // Dismiss button — stops playback and clears now-playing.
                IconButton(
                  key: const ValueKey('iptv-mini-player-dismiss'),
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () =>
                      ref.read(iptvStreamingServiceProvider).stop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Art tile: channel logo when available, otherwise 2-letter initials on a
/// stable per-channel color (spec §5.5: 36px square, radius 8).
class _MiniPlayerArtTile extends StatelessWidget {
  const _MiniPlayerArtTile({required this.channel});

  final IPTVChannel channel;

  @override
  Widget build(BuildContext context) {
    final hasLogo = channel.logoUrl != null && channel.logoUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: IPTVMiniPlayer.artTileSize,
        height: IPTVMiniPlayer.artTileSize,
        child: hasLogo
            ? AiroNetworkImage(
                url: channel.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _InitialsTile(name: channel.name),
              )
            : _InitialsTile(name: channel.name),
      ),
    );
  }
}

/// 2-letter initials on a colored background, derived deterministically
/// from the channel name so a given channel always gets the same color.
class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = (name.hashCode % 360).abs().toDouble();
    final bgColor = HSLColor.fromAHSL(1, hue, 0.35, 0.28).toColor();

    return Container(
      key: const ValueKey('iptv-mini-player-initials'),
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        _initialsFor(name),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  /// First letter of the first two words (e.g. "City News" -> "CN"), or the
  /// first two characters of a single-word name (e.g. "ESPN" -> "ES").
  static String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

/// Green "Watch" CTA that returns to the full player (spec §5.5).
class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('iptv-mini-player-watch'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.airoTvPrimary,
        foregroundColor: AppColors.airoTvOnPrimary,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: const Text(
        'Watch',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
