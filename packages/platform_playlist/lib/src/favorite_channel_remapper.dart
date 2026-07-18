import 'package:platform_channels/platform_channels.dart';

import 'canonical_channel_matcher.dart';

/// Result of trying to carry a favorite over to a re-imported provider
/// channel list (CV-017).
class FavoriteRemapResult {
  const FavoriteRemapResult({required this.channel, required this.needsReview});

  /// The best candidate found, or null if nothing matched at all.
  final IPTVChannel? channel;

  /// True when [channel] is only a name-based match and must be confirmed
  /// by the user before the favorite is silently repointed at it.
  final bool needsReview;
}

/// Finds the best match for a favorited channel among a re-imported
/// provider's channel list, so favorites survive a provider re-import
/// (CV-017) when a confident match exists.
class FavoriteChannelRemapper {
  FavoriteChannelRemapper({CanonicalChannelMatcher? matcher})
    : _matcher = matcher ?? CanonicalChannelMatcher();

  final CanonicalChannelMatcher _matcher;

  /// Scores [favorite] against every channel in [candidates] and returns
  /// the highest-confidence match. A tvg-id match always wins over a
  /// normalized-name-only match, regardless of list order.
  FavoriteRemapResult findMatch(
    IPTVChannel favorite,
    List<IPTVChannel> candidates,
  ) {
    IPTVChannel? bestChannel;
    var bestConfidence = ChannelMatchConfidence.none;

    for (final candidate in candidates) {
      final result = _matcher.match(favorite, candidate);
      if (result.confidence.index > bestConfidence.index) {
        bestConfidence = result.confidence;
        bestChannel = candidate;
      }
    }

    return FavoriteRemapResult(
      channel: bestChannel,
      needsReview:
          bestConfidence == ChannelMatchConfidence.medium ||
          bestConfidence == ChannelMatchConfidence.low,
    );
  }
}
