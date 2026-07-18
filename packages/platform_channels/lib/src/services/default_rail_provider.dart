import '../models/iptv_channel.dart';
import '../models/rail_definition.dart';

/// v1 rail set. The intelligence layer will later supply definitions;
/// this catalog is the Media Engine default.
class DefaultRailCatalog {
  const DefaultRailCatalog._();

  static List<RailDefinition> definitions() => const [
        RailDefinition(
          id: 'top-india',
          title: 'Top India',
          subtitle: 'Ranked by popularity',
          query: RailQuery(),
          priority: 0,
        ),
        RailDefinition(
          id: 'favorites',
          title: 'Favorites',
          subtitle: 'Your saved channels',
          query: RailQuery(favoritesOnly: true),
          priority: 10,
        ),
        RailDefinition(
          id: 'live-sports',
          title: 'Live Sports',
          subtitle: 'Cricket, football and more',
          query: RailQuery(category: ChannelCategory.sports, liveOnly: true),
          priority: 20,
        ),
        RailDefinition(
          id: 'hindi-news',
          title: 'Hindi News',
          subtitle: 'Breaking news and analysis',
          query: RailQuery(category: ChannelCategory.news, language: 'hi'),
          priority: 30,
        ),
        RailDefinition(
          id: 'movies-on-now',
          title: 'Movies On Now',
          subtitle: 'Playing right now',
          query: RailQuery(category: ChannelCategory.movies),
          priority: 40,
        ),
        RailDefinition(
          id: 'recently-added',
          title: 'Recently Added',
          query: RailQuery(),
          priority: 50,
        ),
      ];
}

/// Popularity-scored rail builder: favorites + watch history + provider
/// order, degrading to provider order alone when signals are absent.
/// Later replaced by regional popularity / trending / AI ranking behind
/// the same [RailProvider] interface — zero UI change.
class DefaultRailProvider implements RailProvider {
  DefaultRailProvider({
    required List<IPTVChannel> channels,
    this.favoriteIds = const {},
    this.watchCounts = const {},
  }) : _channels = channels;

  final List<IPTVChannel> _channels;
  final Set<String> favoriteIds;
  final Map<String, int> watchCounts;

  static const _favoriteWeight = 1000000;
  static const _watchWeight = 1000;

  int _score(IPTVChannel ch, int providerIndex) {
    final favorite = favoriteIds.contains(ch.id) ? _favoriteWeight : 0;
    final watched = (watchCounts[ch.id] ?? 0) * _watchWeight;
    // Provider order: earlier = higher. Bounded below _watchWeight so one
    // watch always outranks any provider position.
    final order = (_channels.length - providerIndex).clamp(0, _watchWeight - 1);
    return favorite + watched + order;
  }

  @override
  Future<List<IPTVChannel>> buildRail(RailDefinition rail) async {
    Iterable<IPTVChannel> pool = _channels.where(rail.query.matches);
    if (rail.query.favoritesOnly) {
      pool = pool.where((ch) => favoriteIds.contains(ch.id));
    }
    // liveOnly: IPTV live channels are the default content type; VOD
    // filtering is applied upstream. Kept as a declared intent for the
    // intelligence layer.
    final indexed = pool.toList();
    final providerIndex = <String, int>{
      for (var i = 0; i < _channels.length; i++) _channels[i].id: i,
    };
    indexed.sort((x, y) => _score(y, providerIndex[y.id] ?? 0)
        .compareTo(_score(x, providerIndex[x.id] ?? 0)));
    return indexed.take(rail.maxItems).toList();
  }

  /// Builds every rail, sorted by [RailDefinition.priority]; rails with
  /// [RailVisibility.whenNonEmpty] and no channels are dropped, and
  /// [RailVisibility.hidden] rails are skipped entirely.
  Future<List<RailResult>> buildAll(List<RailDefinition> definitions) async {
    final sorted = [...definitions]
      ..sort((x, y) => x.priority.compareTo(y.priority));
    final results = <RailResult>[];
    for (final def in sorted) {
      if (def.visibility == RailVisibility.hidden) continue;
      final channels = await buildRail(def);
      if (channels.isEmpty && def.visibility == RailVisibility.whenNonEmpty) {
        continue;
      }
      results.add(RailResult(definition: def, channels: channels));
    }
    return results;
  }
}
