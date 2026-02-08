import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/music_provider.dart';
import '../../application/providers/music_tracks_provider.dart';
import '../../application/providers/beats_provider.dart';
import '../../domain/services/music_service.dart';
import '../../domain/models/beats_models.dart';
import '../widgets/beats_search_bar.dart';
import '../widgets/beats_search_results.dart';

/// Music player screen with Beats search and playback
class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerStateProvider);
    final musicTracks = ref.watch(musicTracksProvider);
    final musicController = ref.watch(musicControllerProvider);
    final beatsSearchState = ref.watch(beatsSearchStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beats'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(musicTracksProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Beats search bar
          const BeatsSearchBar(),

          // Show search results if searching, otherwise show player
          Expanded(
            child: beatsSearchState.state != BeatsSearchState.idle
                ? const SingleChildScrollView(child: BeatsSearchResults())
                : musicTracks.when(
                    data: (tracks) {
                      if (tracks.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.music_note,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text('No tracks available'),
                              const SizedBox(height: 8),
                              const Text(
                                'No tracks loaded',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.invalidate(musicTracksProvider);
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      return playerState.when(
                        data: (state) => _buildPlayerUI(
                          context,
                          ref,
                          state,
                          tracks,
                          musicController,
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, st) => Center(child: Text('Error: $err')),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, st) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading tracks: $err'),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(musicTracksProvider);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerUI(
    BuildContext context,
    WidgetRef ref,
    MusicPlayerState state,
    List<MusicTrack> tracks,
    MusicController musicController,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Now playing card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Album art
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: state.currentTrack?.albumArt != null
                        ? Image.network(
                            state.currentTrack!.albumArt!,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.music_note,
                            size: 64,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Track info
                  Text(
                    state.currentTrack?.title ?? 'No track playing',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.currentTrack?.artist ?? '—',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  if (state.currentTrack != null)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: state.duration.inMilliseconds > 0
                              ? state.position.inMilliseconds /
                                    state.duration.inMilliseconds
                              : 0,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(state.position),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              _formatDuration(state.duration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Player controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: state.currentIndex > 0
                            ? () => musicController.previous()
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          state.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 48,
                        ),
                        onPressed: () {
                          if (state.isPlaying) {
                            musicController.pause();
                          } else if (state.currentTrack != null) {
                            musicController.resume();
                          } else if (tracks.isNotEmpty) {
                            musicController.playTrack(tracks[0]);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: state.currentIndex < tracks.length - 1
                            ? () => musicController.next()
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Playlist section
          Text('Top 20 India', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tracks.length,
            separatorBuilder: (_, _) => const Divider(height: 0.5),
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrentTrack = state.currentTrack?.id == track.id;

              return ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: track.albumArt != null
                      ? Image.network(track.albumArt!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.music_note, size: 24),
                        ),
                ),
                title: Text(
                  track.title,
                  style: TextStyle(
                    fontWeight: isCurrentTrack
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCurrentTrack
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                ),
                subtitle: Text(track.artist),
                trailing: isCurrentTrack
                    ? Icon(
                        state.isPlaying ? Icons.volume_up : Icons.pause,
                        color: Theme.of(context).primaryColor,
                      )
                    : null,
                onTap: () => musicController.playTrack(track),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Music screen body content (without AppBar) for embedding in MediaHubScreen
class MusicScreenBody extends ConsumerWidget {
  const MusicScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerStateProvider);
    final musicTracks = ref.watch(musicTracksProvider);
    final musicController = ref.watch(musicControllerProvider);

    return musicTracks.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No tracks available'),
                const SizedBox(height: 8),
                const Text(
                  'No tracks loaded',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(musicTracksProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return playerState.when(
          data: (state) => _MusicPlayerUI(
            state: state,
            tracks: tracks,
            musicController: musicController,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading tracks: $err'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(musicTracksProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extracted music player UI widget
class _MusicPlayerUI extends StatelessWidget {
  const _MusicPlayerUI({
    required this.state,
    required this.tracks,
    required this.musicController,
  });

  final MusicPlayerState state;
  final List<MusicTrack> tracks;
  final MusicController musicController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Now playing card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Album art
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: state.currentTrack?.albumArt != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              state.currentTrack!.albumArt!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.music_note,
                            size: 64,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Track info
                  Text(
                    state.currentTrack?.title ?? 'No track playing',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.currentTrack?.artist ?? '—',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  if (state.currentTrack != null)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: state.duration.inMilliseconds > 0
                              ? state.position.inMilliseconds /
                                    state.duration.inMilliseconds
                              : 0,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(state.position),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              _formatDuration(state.duration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Player controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: state.currentIndex > 0
                            ? () => musicController.previous()
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          state.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 48,
                        ),
                        onPressed: () {
                          if (state.isPlaying) {
                            musicController.pause();
                          } else if (state.currentTrack != null) {
                            musicController.resume();
                          } else if (tracks.isNotEmpty) {
                            musicController.playTrack(tracks[0]);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: state.currentIndex < tracks.length - 1
                            ? () => musicController.next()
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Playlist section
          Text('Top 20 India', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const Divider(height: 0.5),
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrentTrack = state.currentTrack?.id == track.id;

              return ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: track.albumArt != null
                      ? Image.network(track.albumArt!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.music_note, size: 24),
                        ),
                ),
                title: Text(
                  track.title,
                  style: TextStyle(
                    fontWeight: isCurrentTrack
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCurrentTrack
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                ),
                subtitle: Text(track.artist),
                trailing: isCurrentTrack
                    ? Icon(
                        state.isPlaying ? Icons.volume_up : Icons.pause,
                        color: Theme.of(context).primaryColor,
                      )
                    : null,
                onTap: () => musicController.playTrack(track),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
