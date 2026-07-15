import 'dart:math' as math;

import '../models/iptv_channel.dart';

/// Bounds channel logo pre-cache bursts for TV grids and other dense surfaces.
///
/// The policy is intentionally transport-agnostic. Flutter `NetworkImage`
/// currently owns logo fetching in Airo TV, so this class limits the number of
/// image requests that UI code asks Flutter to start rather than configuring
/// per-host sockets or HTTP/2 adapters in feature code.
class AiroLogoBurstPolicy {
  const AiroLogoBurstPolicy({
    this.lookBehind = 4,
    this.lookAhead = 8,
    this.maxCandidates = 8,
    this.maxCandidatesPerHost = 2,
  });

  /// Number of channels before the focused item eligible for pre-cache.
  final int lookBehind;

  /// Number of channels from the focused item forward eligible for pre-cache.
  final int lookAhead;

  /// Maximum number of distinct logo URLs returned for one burst.
  final int maxCandidates;

  /// Maximum number of logo URLs returned for the same normalized host.
  final int maxCandidatesPerHost;

  AiroLogoBurstPolicy copyWith({
    int? lookBehind,
    int? lookAhead,
    int? maxCandidates,
    int? maxCandidatesPerHost,
  }) {
    return AiroLogoBurstPolicy(
      lookBehind: lookBehind ?? this.lookBehind,
      lookAhead: lookAhead ?? this.lookAhead,
      maxCandidates: maxCandidates ?? this.maxCandidates,
      maxCandidatesPerHost: maxCandidatesPerHost ?? this.maxCandidatesPerHost,
    );
  }

  /// Returns bounded, de-duplicated channels whose logos may be pre-cached.
  List<IPTVChannel> precacheCandidates(
    List<IPTVChannel> channels,
    int focusedIndex,
  ) {
    if (channels.isEmpty || maxCandidates <= 0 || maxCandidatesPerHost <= 0) {
      return const [];
    }

    final clampedFocus = focusedIndex.clamp(0, channels.length - 1).toInt();
    final startIndex = math
        .max(0, clampedFocus - math.max(0, lookBehind))
        .toInt();
    final endIndex = math
        .min(channels.length, clampedFocus + math.max(0, lookAhead))
        .toInt();
    final selected = <IPTVChannel>[];
    final seenUrls = <String>{};
    final hostCounts = <String, int>{};

    for (var i = startIndex; i < endIndex; i++) {
      final channel = channels[i];
      final logoUri = _normalizedLogoUri(channel.logoUrl);
      if (logoUri == null) {
        continue;
      }

      final url = logoUri.toString();
      if (!seenUrls.add(url)) {
        continue;
      }

      final host = logoUri.host.toLowerCase();
      final hostCount = hostCounts[host] ?? 0;
      if (hostCount >= maxCandidatesPerHost) {
        continue;
      }

      hostCounts[host] = hostCount + 1;
      selected.add(channel);

      if (selected.length >= maxCandidates) {
        break;
      }
    }

    return selected;
  }

  Uri? _normalizedLogoUri(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return null;
    }

    return uri;
  }
}
