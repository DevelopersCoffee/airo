import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../../domain/favorite_reimport_coordinator.dart';

/// Surfaces CV-017's name-only favorite matches from the most recent
/// playlist re-import for explicit user confirmation -- per the issue's
/// "uncertain matches are not silently merged" acceptance criterion, these
/// are never applied automatically (see [applyFavoriteRemapOnReimport]).
///
/// Renders nothing when [favoriteReimportReviewCandidatesProvider] is empty.
class FavoriteReimportReviewBanner extends ConsumerWidget {
  const FavoriteReimportReviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(favoriteReimportReviewCandidatesProvider);
    if (candidates.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final candidate in candidates)
            Padding(
              key: ValueKey(
                'favorite-reimport-review-${candidate.oldChannel.id}',
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '"${candidate.oldChannel.name}" looks like '
                      '"${candidate.candidate.name}" now. Keep as favorite?',
                    ),
                  ),
                  TextButton(
                    key: ValueKey(
                      'favorite-reimport-accept-${candidate.oldChannel.id}',
                    ),
                    onPressed: () => _accept(ref, candidate),
                    child: const Text('Keep'),
                  ),
                  TextButton(
                    key: ValueKey(
                      'favorite-reimport-dismiss-${candidate.oldChannel.id}',
                    ),
                    onPressed: () => _dismiss(ref, candidate),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _accept(WidgetRef ref, FavoriteReviewCandidate candidate) async {
    final storage = ref.read(favoriteChannelsStorageProvider);
    // Sequenced, not fired concurrently: both are independent read-modify-
    // write calls against the same underlying id set, so running them
    // concurrently risks the second overwriting the first's write with a
    // stale read.
    await storage.addFavorite(candidate.candidate.id);
    await storage.removeFavorite(candidate.oldChannel.id);
    ref.invalidate(favoriteChannelIdsProvider);
    _dismiss(ref, candidate);
  }

  void _dismiss(WidgetRef ref, FavoriteReviewCandidate candidate) {
    ref
        .read(favoriteReimportReviewCandidatesProvider.notifier)
        .update(
          (state) => state
              .where((c) => c.oldChannel.id != candidate.oldChannel.id)
              .toList(),
        );
  }
}
