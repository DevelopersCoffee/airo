import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/beats_provider.dart';
import '../../domain/models/beats_models.dart';

/// Widget to display Beats search results
class BeatsSearchResults extends ConsumerWidget {
  const BeatsSearchResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(beatsSearchStateProvider);
    final beatsController = ref.watch(beatsControllerProvider);

    return switch (searchState.state) {
      BeatsSearchState.idle => const SizedBox.shrink(),
      BeatsSearchState.searching ||
      BeatsSearchState.resolving => _buildLoading(searchState),
      BeatsSearchState.success => _buildResults(
        context,
        searchState,
        beatsController,
      ),
      BeatsSearchState.error => _buildError(context, ref, searchState),
    };
  }

  Widget _buildLoading(BeatsSearchUiState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            state.state == BeatsSearchState.resolving
                ? 'Resolving URL...'
                : 'Searching...',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    BeatsSearchUiState state,
    BeatsController controller,
  ) {
    if (state.results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No results for "${state.query}"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final track = state.results[index];
        return _BeatsTrackTile(
          track: track,
          onPlay: () => controller.playTrack(track),
          onAddToQueue: () => controller.addToQueue(track),
        );
      },
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    BeatsSearchUiState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            state.errorMessage ?? 'Something went wrong',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              ref.read(beatsSearchStateProvider.notifier).clear();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Individual track tile in search results
class _BeatsTrackTile extends StatelessWidget {
  final BeatsTrack track;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;

  const _BeatsTrackTile({
    required this.track,
    required this.onPlay,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track.thumbnailUrl != null
            ? Image.network(
                track.thumbnailUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          _buildSourceIcon(track.source),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${track.artist} • ${track.durationFormatted}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            color: theme.colorScheme.primary,
            onPressed: onPlay,
            tooltip: 'Play now',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onAddToQueue,
            tooltip: 'Add to queue',
          ),
        ],
      ),
      onTap: onPlay,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, color: Colors.grey),
    );
  }

  Widget _buildSourceIcon(BeatsSource source) {
    final IconData icon;
    final Color color;

    switch (source) {
      case BeatsSource.youtube:
        icon = Icons.play_circle_filled;
        color = Colors.red;
      case BeatsSource.soundcloud:
        icon = Icons.cloud;
        color = Colors.orange;
      default:
        icon = Icons.music_note;
        color = Colors.grey;
    }

    return Icon(icon, size: 14, color: color);
  }
}
