import 'package:platform_channels/platform_channels.dart';

import 'channel_name_normalizer.dart';

/// How confident [CanonicalChannelMatcher] is that two provider channels
/// are the same underlying channel (CV-017).
enum ChannelMatchConfidence {
  /// No signal suggests these are the same channel.
  none,

  /// Reserved for weaker signals than a normalized-name match (e.g. a
  /// partial/fuzzy name match) -- not produced by this slice yet.
  low,

  /// Normalized names agree, but nothing stronger (like tvg-id) confirms
  /// it. Per the issue's "flag low-confidence name-only matches for
  /// review" acceptance criterion, this must never be auto-merged.
  medium,

  /// A strong, structural identifier (tvg-id) agrees. Safe to auto-match.
  high,
}

class CanonicalChannelMatchResult {
  const CanonicalChannelMatchResult({
    required this.confidence,
    required this.reason,
  });

  final ChannelMatchConfidence confidence;

  /// Which signal produced [confidence]: `'tvg_id'`, `'normalized_name'`,
  /// or `'no_match'`.
  final String reason;
}

/// Scores whether two [IPTVChannel]s from (possibly different) providers
/// represent the same underlying canonical channel.
///
/// Deliberately conservative: only a matching tvg-id is [
/// ChannelMatchConfidence.high] (auto-match safe). A normalized-name-only
/// match is [ChannelMatchConfidence.medium] and must be surfaced for user
/// confirmation rather than silently merged, per CV-017's "uncertain
/// matches are not silently merged" acceptance criterion.
class CanonicalChannelMatcher {
  CanonicalChannelMatcher({ChannelNameNormalizer? normalizer})
    : _normalizer = normalizer ?? ChannelNameNormalizer();

  final ChannelNameNormalizer _normalizer;

  CanonicalChannelMatchResult match(IPTVChannel a, IPTVChannel b) {
    if (a.tvgId != null && a.tvgId == b.tvgId) {
      return const CanonicalChannelMatchResult(
        confidence: ChannelMatchConfidence.high,
        reason: 'tvg_id',
      );
    }

    final normalizedA = _normalizer.normalize(a.name);
    final normalizedB = _normalizer.normalize(b.name);
    if (normalizedA.isNotEmpty && normalizedA == normalizedB) {
      return const CanonicalChannelMatchResult(
        confidence: ChannelMatchConfidence.medium,
        reason: 'normalized_name',
      );
    }

    return const CanonicalChannelMatchResult(
      confidence: ChannelMatchConfidence.none,
      reason: 'no_match',
    );
  }
}
