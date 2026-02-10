import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/iptv_providers.dart';
import '../../domain/models/streaming_state.dart';

/// Mini player widget for IPTV background playback
/// Shows at bottom when:
/// - Playing audio-only channels (always visible)
/// - Playing any channel when user navigates away from Stream tab
class IPTVMiniPlayer extends ConsumerWidget {
  const IPTVMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamingState = ref.watch(streamingStateProvider);
    final currentTab = ref.watch(currentNavigationTabProvider);

    // Live tab is at index 2 (0=Coins, 1=Mind, 2=Live, 3=Arena, 4=Quest)
    const liveTabIndex = 2;
    final isOnLiveTab = currentTab == liveTabIndex;

    return streamingState.when(
      data: (state) {
        // Don't show if no channel is playing
        if (state.currentChannel == null) {
          return const SizedBox.shrink();
        }

        // Don't show if on Live tab (video player is visible there)
        // unless it's an audio-only channel
        if (isOnLiveTab && !state.currentChannel!.isAudioOnly) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            // Navigate to Live tab and update provider
            ref.read(currentNavigationTabProvider.notifier).state = 2;
            context.go('/live');
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
                // Channel logo
                Container(
                  width: 64,
                  height: 64,
                  color: Colors.black,
                  child: state.currentChannel!.logoUrl != null
                      ? Image.network(
                          state.currentChannel!.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                        )
                      : _buildDefaultIcon(),
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
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDefaultIcon() {
    return const Center(
      child: Icon(Icons.radio, color: Colors.white54, size: 32),
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
