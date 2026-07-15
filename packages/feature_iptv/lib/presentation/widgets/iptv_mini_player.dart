import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/iptv_providers.dart';
import "package:platform_player/platform_player.dart";
import 'channel_logo.dart';

/// Mini player widget for IPTV background playback
/// Shows at bottom when:
/// - Playing audio-only channels (always visible)
/// - Playing any channel when user navigates away from Stream tab
class IPTVMiniPlayer extends ConsumerWidget {
  const IPTVMiniPlayer({super.key, this.forceVisible = false});

  final bool forceVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamingState = ref.watch(streamingStateProvider);
    final currentTab = ref.watch(currentNavigationTabProvider);

    final isOnStreamTab = currentTab == AppNavigationTab.stream.index;

    return streamingState.when(
      data: (state) {
        // Don't show if no channel is playing
        if (state.currentChannel == null) {
          return const SizedBox.shrink();
        }

        // Don't show if on Stream tab (video player is visible there)
        // unless it's an audio-only channel
        if (isOnStreamTab && !forceVisible) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            ref.read(currentNavigationTabProvider.notifier).state =
                AppNavigationTab.stream.index;
            context.go('/iptv');
          },
          child: Container(
            height: 64,
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
                // Channel logo (decode-at-display-size)
                ChannelLogo(
                  logoUrl: state.currentChannel!.logoUrl,
                  channelName: state.currentChannel!.name,
                  size: 64,
                  borderRadius: 0,
                  isAudioOnly: state.currentChannel!.isAudioOnly,
                ),
                const SizedBox(width: 12),

                // Channel info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.currentChannel!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.radio, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            state.currentChannel!.group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Play/Pause button
                _PlayPauseButton(state: state),
                const SizedBox(width: 8),

                // Stop button
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () =>
                      ref.read(iptvStreamingServiceProvider).stop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Stop',
                ),
                const SizedBox(width: 16),
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

class _PlayPauseButton extends ConsumerWidget {
  final StreamingState state;

  const _PlayPauseButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(iptvStreamingServiceProvider);

    if (state.isBuffering || state.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return IconButton(
      icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
      onPressed: () {
        if (state.isPlaying) {
          service.pause();
        } else {
          service.resume();
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
