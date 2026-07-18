import 'package:equatable/equatable.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

/// CV-001 (#810): local, offline search over user-derived IPTV data only.
/// Never queries a remote provider, YouTube, Plex, Jellyfin, or DLNA.

enum LocalIptvSearchResultType { channel, program }

class LocalIptvSearchResult extends Equatable {
  const LocalIptvSearchResult({
    required this.type,
    required this.title,
    required this.channelId,
    required this.rank,
    this.subtitle,
    this.isFavorite = false,
    this.isRecent = false,
  });

  final LocalIptvSearchResultType type;
  final String title;
  final String? subtitle;
  final String channelId;

  /// Lower is better; used only for deterministic ordering in tests. Not a
  /// stable public score — sort order, not the number, is the contract.
  final int rank;

  final bool isFavorite;
  final bool isRecent;

  @override
  List<Object?> get props => [
    type,
    title,
    subtitle,
    channelId,
    rank,
    isFavorite,
    isRecent,
  ];
}

enum _MatchQuality { exact, prefix, substring }

/// Rebuildable local index over playlist channels, EPG program titles,
/// favorite channel ids, and recent channel ids (CV-006 AUTO-001).
///
/// Query-time cost is O(entries); this targets typical BYOC playlist sizes
/// (thousands, not millions of channels) rather than a trie/inverted index.
class LocalIptvSearchIndex {
  LocalIptvSearchIndex._(
    this._channels,
    this._programsByChannelId,
    this._favoriteChannelIds,
    this._recentRank,
  );

  factory LocalIptvSearchIndex.build({
    required List<IPTVChannel> channels,
    required Map<String, List<CompactEpgProgram>> programsByChannelId,
    required Set<String> favoriteChannelIds,
    required List<String> recentChannelIds,
  }) {
    final recentRank = <String, int>{
      for (var i = 0; i < recentChannelIds.length; i++) recentChannelIds[i]: i,
    };
    return LocalIptvSearchIndex._(
      List.unmodifiable(channels),
      Map.unmodifiable(programsByChannelId),
      Set.unmodifiable(favoriteChannelIds),
      Map.unmodifiable(recentRank),
    );
  }

  final List<IPTVChannel> _channels;
  final Map<String, List<CompactEpgProgram>> _programsByChannelId;
  final Set<String> _favoriteChannelIds;
  final Map<String, int> _recentRank;

  List<LocalIptvSearchResult> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final results = <_ScoredResult>[];

    for (final channel in _channels) {
      final nameQuality = _matchQuality(channel.name, normalized);
      final groupQuality = _matchQuality(channel.group, normalized);
      final quality = _better(nameQuality, groupQuality);
      if (quality == null) continue;

      results.add(
        _ScoredResult(
          LocalIptvSearchResult(
            type: LocalIptvSearchResultType.channel,
            title: channel.name,
            subtitle: channel.group,
            channelId: channel.id,
            rank: 0,
            isFavorite: _favoriteChannelIds.contains(channel.id),
            isRecent: _recentRank.containsKey(channel.id),
          ),
          quality,
          _recentRank[channel.id],
        ),
      );
    }

    _programsByChannelId.forEach((channelId, programs) {
      for (final program in programs) {
        final quality = _matchQuality(program.title, normalized);
        if (quality == null) continue;
        results.add(
          _ScoredResult(
            LocalIptvSearchResult(
              type: LocalIptvSearchResultType.program,
              title: program.title,
              subtitle: program.subtitle,
              channelId: channelId,
              rank: 0,
              isFavorite: _favoriteChannelIds.contains(channelId),
              isRecent: _recentRank.containsKey(channelId),
            ),
            quality,
            _recentRank[channelId],
          ),
        );
      }
    });

    results.sort(_compare);

    return [
      for (var i = 0; i < results.length; i++) _withRank(results[i].result, i),
    ];
  }

  LocalIptvSearchResult _withRank(LocalIptvSearchResult result, int rank) {
    return LocalIptvSearchResult(
      type: result.type,
      title: result.title,
      subtitle: result.subtitle,
      channelId: result.channelId,
      rank: rank,
      isFavorite: result.isFavorite,
      isRecent: result.isRecent,
    );
  }

  int _compare(_ScoredResult a, _ScoredResult b) {
    final qualityCompare = a.quality.index.compareTo(b.quality.index);
    if (qualityCompare != 0) return qualityCompare;

    final favoriteCompare = _boolRank(
      b.result.isFavorite,
    ).compareTo(_boolRank(a.result.isFavorite));
    if (favoriteCompare != 0) return favoriteCompare;

    final aRecent = a.recentRank;
    final bRecent = b.recentRank;
    if (aRecent != null || bRecent != null) {
      if (aRecent == null) return 1;
      if (bRecent == null) return -1;
      final recentCompare = aRecent.compareTo(bRecent);
      if (recentCompare != 0) return recentCompare;
    }

    final typeCompare = a.result.type.index.compareTo(b.result.type.index);
    if (typeCompare != 0) return typeCompare;

    return a.result.title.compareTo(b.result.title);
  }

  int _boolRank(bool value) => value ? 1 : 0;

  _MatchQuality? _matchQuality(String haystack, String normalizedQuery) {
    final normalizedHaystack = haystack.trim().toLowerCase();
    if (normalizedHaystack == normalizedQuery) return _MatchQuality.exact;
    if (normalizedHaystack.startsWith(normalizedQuery)) {
      return _MatchQuality.prefix;
    }
    if (normalizedHaystack.contains(normalizedQuery)) {
      return _MatchQuality.substring;
    }
    return null;
  }

  _MatchQuality? _better(_MatchQuality? a, _MatchQuality? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.index <= b.index ? a : b;
  }
}

class _ScoredResult {
  const _ScoredResult(this.result, this.quality, this.recentRank);

  final LocalIptvSearchResult result;
  final _MatchQuality quality;
  final int? recentRank;
}
