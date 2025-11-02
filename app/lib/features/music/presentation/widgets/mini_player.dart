import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../music/application/providers/music_provider.dart';
import '../../../music/domain/services/music_service.dart';

/// Mini player widget - persistent at bottom across all tabs
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerStateProvider);
    final musicController = ref.watch(musicControllerProvider);

    return playerState.when(
      data: (state) {
        if (state.currentTrack == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            context.go('/music');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Album art
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: state.currentTrack!.albumArt != null
                      ? Image.network(
                          state.currentTrack!.albumArt!,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.music_note, size: 24),
                ),
                const SizedBox(width: 12),

                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.currentTrack!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        state.currentTrack!.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Play/Pause button
                IconButton(
                  icon: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 24,
                  ),
                  onPressed: () {
                    if (state.isPlaying) {
                      musicController.pause();
                    } else {
                      musicController.resume();
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),

                // Next button
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 24),
                  onPressed: () => musicController.next(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

