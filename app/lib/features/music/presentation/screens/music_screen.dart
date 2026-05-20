import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/music_provider.dart';
import '../../application/providers/music_tracks_provider.dart';
import '../../domain/services/music_service.dart';
import '../../../../shared/widgets/responsive_center.dart';

/// Music player screen with Spotify Top 20 India
class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerStateProvider);
    final musicTracks = ref.watch(musicTracksProvider);
    final musicController = ref.watch(musicControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beats'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // ignore: unused_result
              ref.refresh(musicTracksProvider);
            },
          ),
        ],
      ),
      body: musicTracks.when(
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
                    onPressed: () {
                      // ignore: unused_result
                      ref.refresh(musicTracksProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return playerState.when(
            data: (state) =>
                _buildPlayerUI(context, ref, state, tracks, musicController),
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
                onPressed: () {
                  // ignore: unused_result
                  ref.refresh(musicTracksProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
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
    return ResponsiveCenter(
      maxWidth: ResponsiveBreakpoints.textMaxWidth,
      child: SingleChildScrollView(
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
                    // Album art with aspect ratio
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
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
    final colorScheme = Theme.of(context).colorScheme;
    final playerPanel = _NowPlayingPanel(
      state: state,
      tracks: tracks,
      musicController: musicController,
      formatDuration: _formatDuration,
    );
    final queue = _TrackQueue(
      state: state,
      tracks: tracks,
      musicController: musicController,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: ResponsiveCenter(
        maxWidth: ResponsiveBreakpoints.dashboardMaxWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 840) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 420, child: playerPanel),
                  const SizedBox(width: 18),
                  Expanded(child: queue),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                playerPanel,
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: queue,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({
    required this.state,
    required this.tracks,
    required this.musicController,
    required this.formatDuration,
  });

  final MusicPlayerState state;
  final List<MusicTrack> tracks;
  final MusicController musicController;
  final String Function(Duration duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.34),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.42),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: state.currentTrack?.albumArt != null
                  ? Image.network(
                      state.currentTrack!.albumArt!,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.music_note,
                      size: 64,
                      color: colorScheme.primary.withValues(alpha: 0.62),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            state.currentTrack?.title ?? 'No track playing',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            state.currentTrack?.artist ?? 'Select any track to start',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary.withValues(alpha: 0.62),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
                    Text(formatDuration(state.position)),
                    Text(formatDuration(state.duration)),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: state.currentIndex > 0
                    ? () => musicController.previous()
                    : null,
              ),
              IconButton.filled(
                icon: Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 28,
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
    );
  }
}

class _TrackQueue extends StatelessWidget {
  const _TrackQueue({
    required this.state,
    required this.tracks,
    required this.musicController,
  });

  final MusicPlayerState state;
  final List<MusicTrack> tracks;
  final MusicController musicController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text('TOP 20 INDIA', style: theme.textTheme.titleLarge),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tracks.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: colorScheme.outlineVariant),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrentTrack = state.currentTrack?.id == track.id;

            return ListTile(
              dense: true,
              leading: SizedBox(
                width: 44,
                height: 44,
                child: track.albumArt != null
                    ? Image.network(track.albumArt!, fit: BoxFit.cover)
                    : Container(
                        color: colorScheme.surface.withValues(alpha: 0.5),
                        child: Icon(
                          Icons.music_note,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrentTrack ? FontWeight.w700 : null,
                ),
              ),
              subtitle: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isCurrentTrack
                  ? Icon(
                      state.isPlaying ? Icons.volume_up : Icons.pause,
                      color: colorScheme.primary,
                    )
                  : null,
              onTap: () => musicController.playTrack(track),
            );
          },
        ),
      ],
    );
  }
}
