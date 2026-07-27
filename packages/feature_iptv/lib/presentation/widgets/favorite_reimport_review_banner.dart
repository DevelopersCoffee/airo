import 'package:core_ui/core_ui.dart';
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
class FavoriteReimportReviewBanner extends ConsumerStatefulWidget {
  const FavoriteReimportReviewBanner({super.key});

  @override
  ConsumerState<FavoriteReimportReviewBanner> createState() =>
      _FavoriteReimportReviewBannerState();
}

class _FavoriteReimportReviewBannerState
    extends ConsumerState<FavoriteReimportReviewBanner> {
  final FocusScopeNode _scopeNode = FocusScopeNode(
    debugLabel: 'favorite reimport review',
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final Map<String, FocusNode> _keepFocusNodes = {};
  final Map<String, FocusNode> _dismissFocusNodes = {};
  String? _focusedCandidateId;

  FocusNode _keepFocusNode(String id) => _keepFocusNodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'favorite review Keep'),
  );

  FocusNode _dismissFocusNode(String id) => _dismissFocusNodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'favorite review Dismiss'),
  );

  @override
  void dispose() {
    _scopeNode.dispose();
    for (final node in [
      ..._keepFocusNodes.values,
      ..._dismissFocusNodes.values,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(favoriteReimportReviewCandidatesProvider);
    if (candidates.isEmpty) {
      _focusedCandidateId = null;
      return const SizedBox.shrink();
    }

    final firstCandidateId = candidates.first.oldChannel.id;
    if (_focusedCandidateId != firstCandidateId) {
      _focusedCandidateId = firstCandidateId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _focusedCandidateId != firstCandidateId ||
            !_keepFocusNode(firstCandidateId).canRequestFocus) {
          return;
        }
        _keepFocusNode(firstCandidateId).requestFocus();
      });
    }

    final colorScheme = Theme.of(context).colorScheme;
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: FocusScope(
        node: _scopeNode,
        child: Container(
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
                      TvFocusable(
                        focusNode: _keepFocusNode(candidate.oldChannel.id),
                        semanticLabel: 'Keep as favorite',
                        onSelect: () => _accept(ref, candidate),
                        child: ExcludeFocus(
                          child: TextButton(
                            key: ValueKey(
                              'favorite-reimport-accept-${candidate.oldChannel.id}',
                            ),
                            onPressed: () => _accept(ref, candidate),
                            child: const Text('Keep'),
                          ),
                        ),
                      ),
                      TvFocusable(
                        focusNode: _dismissFocusNode(candidate.oldChannel.id),
                        semanticLabel: 'Dismiss',
                        onSelect: () => _dismiss(ref, candidate),
                        child: ExcludeFocus(
                          child: TextButton(
                            key: ValueKey(
                              'favorite-reimport-dismiss-${candidate.oldChannel.id}',
                            ),
                            onPressed: () => _dismiss(ref, candidate),
                            child: const Text('Dismiss'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
