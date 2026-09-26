import 'package:platform_channels/platform_channels.dart';

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

/// Scores whether two [IPTVChannel]s represent the same channel.
///
/// The public Play matcher is identity-only: same `id` or same `streamUrl`.
/// tvg-id and normalized-name matching live in airo-pro as
/// [ProFeature.importIntelligence].
class CanonicalChannelMatcher {
  const CanonicalChannelMatcher();

  CanonicalChannelMatchResult match(IPTVChannel a, IPTVChannel b) {
    if (a.id == b.id) {
      return const CanonicalChannelMatchResult(
        confidence: ChannelMatchConfidence.high,
        reason: 'channel_id',
      );
    }
    if (a.streamUrl.isNotEmpty && a.streamUrl == b.streamUrl) {
      return const CanonicalChannelMatchResult(
        confidence: ChannelMatchConfidence.high,
        reason: 'stream_url',
      );
    }
    return const CanonicalChannelMatchResult(
      confidence: ChannelMatchConfidence.none,
      reason: 'no_match',
    );
  }
}
