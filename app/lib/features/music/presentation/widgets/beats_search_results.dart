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
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            state.state == BeatsSearchState.resolving
                ? 'Resolving URL...'
                : 'Searching...',
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
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "${state.query}"',
              textAlign: TextAlign.center,
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
        return _TrackTile(
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
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            state.errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(beatsSearchStateProvider.notifier).search(state.query);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final BeatsTrack track;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;

  const _TrackTile({
    required this.track,
    required this.onPlay,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track.thumbnailUrl != null
            ? Image.network(
                track.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.play_arrow), onPressed: onPlay),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: onAddToQueue,
          ),
        ],
      ),
      onTap: onPlay,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey[300],
      child: const Icon(Icons.music_note),
    );
  }
}
