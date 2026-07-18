import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

/// A favorite whose old channel no longer exists by id in a re-imported
/// provider list, and whose best match is only a name-based (medium-
/// confidence) one -- must be confirmed by the user rather than silently
/// remapped (CV-017).
class FavoriteReviewCandidate {
  const FavoriteReviewCandidate({
    required this.oldChannel,
    required this.candidate,
  });

  final IPTVChannel oldChannel;
  final IPTVChannel candidate;
}

class FavoriteReimportResult {
  const FavoriteReimportResult({
    required this.remappedFavoriteIds,
    required this.needsReview,
  });

  /// The new set of favorited channel ids: unchanged ids that still exist,
  /// plus high-confidence (tvg-id) remaps. Favorites with no match at all
  /// are dropped rather than carried forward under a stale id.
  final Set<String> remappedFavoriteIds;

  /// Favorites whose only candidate match is name-based and needs explicit
  /// user confirmation before being applied.
  final List<FavoriteReviewCandidate> needsReview;
}

/// Carries favorites over a provider re-import (CV-017's "Favorites can
/// point to canonical channel IDs and survive a provider re-import when a
/// confident match exists" acceptance criterion).
///
/// Delegates matching to [FavoriteChannelRemapper] (platform_playlist);
/// this class only decides what to do with each confidence tier for the
/// specific case of favorites.
class FavoriteReimportCoordinator {
  FavoriteReimportCoordinator({FavoriteChannelRemapper? remapper})
    : _remapper = remapper ?? FavoriteChannelRemapper();

  final FavoriteChannelRemapper _remapper;

  FavoriteReimportResult remapFavorites({
    required Set<String> favoriteChannelIds,
    required List<IPTVChannel> oldChannels,
    required List<IPTVChannel> newChannels,
  }) {
    final newChannelsById = {for (final c in newChannels) c.id: c};
    final oldChannelsById = {for (final c in oldChannels) c.id: c};

    final remapped = <String>{};
    final needsReview = <FavoriteReviewCandidate>[];

    for (final favoriteId in favoriteChannelIds) {
      if (newChannelsById.containsKey(favoriteId)) {
        remapped.add(favoriteId);
        continue;
      }

      final oldChannel = oldChannelsById[favoriteId];
      if (oldChannel == null) continue;

      final result = _remapper.findMatch(oldChannel, newChannels);
      if (result.channel == null) continue;

      if (result.needsReview) {
        needsReview.add(
          FavoriteReviewCandidate(
            oldChannel: oldChannel,
            candidate: result.channel!,
          ),
        );
      } else {
        remapped.add(result.channel!.id);
      }
    }

    return FavoriteReimportResult(
      remappedFavoriteIds: remapped,
      needsReview: needsReview,
    );
  }
}
