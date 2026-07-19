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
      ];
}

/// Popularity-scored rail builder using tiered comparison: favorites strictly
/// outrank watch history, which strictly outranks provider order. Signals are
/// independent; watch count cannot boost a non-favorite to outrank a favorite.
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

  int _compare(IPTVChannel a, IPTVChannel b, Map<String, int> providerIndex) {
    final favA = favoriteIds.contains(a.id) ? 1 : 0;
    final favB = favoriteIds.contains(b.id) ? 1 : 0;
    if (favA != favB) return favB - favA;
    final watchA = watchCounts[a.id] ?? 0;
    final watchB = watchCounts[b.id] ?? 0;
    if (watchA != watchB) return watchB - watchA;
    return (providerIndex[a.id] ?? 0).compareTo(providerIndex[b.id] ?? 0);
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
    indexed.sort((x, y) => _compare(x, y, providerIndex));
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
