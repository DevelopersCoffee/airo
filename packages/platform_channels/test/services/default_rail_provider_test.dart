// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const a = IPTVChannel(id: 'a', name: 'A', streamUrl: 'u');
  const b = IPTVChannel(id: 'b', name: 'B', streamUrl: 'u');
  const c = IPTVChannel(id: 'c', name: 'C', streamUrl: 'u');

  group('popularity ordering', () {
    test('favorites outrank watch history, which outranks provider order',
        () async {
      final provider = DefaultRailProvider(
        channels: const [a, b, c],
        favoriteIds: const {'c'},
        watchCounts: const {'b': 3},
      );
      final rail = await provider.buildRail(const RailDefinition(
        id: 'top', title: 'Top', query: RailQuery(), priority: 0,
      ));
      expect(rail.map((ch) => ch.id).toList(), ['c', 'b', 'a']);
    });

    test('falls back to provider order when no signals', () async {
      final provider = DefaultRailProvider(channels: const [a, b, c]);
      final rail = await provider.buildRail(const RailDefinition(
        id: 'top', title: 'Top', query: RailQuery(), priority: 0,
      ));
      expect(rail.map((ch) => ch.id).toList(), ['a', 'b', 'c']);
    });
  });

  group('buildAll', () {
    test('sorts by priority and drops empty whenNonEmpty rails', () async {
      final provider = DefaultRailProvider(channels: const [a]);
      final results = await provider.buildAll(const [
        RailDefinition(
          id: 'second', title: 'Second', query: RailQuery(), priority: 20,
        ),
        RailDefinition(
          id: 'first', title: 'First', query: RailQuery(), priority: 10,
        ),
        RailDefinition(
          id: 'empty',
          title: 'Empty',
          // favoritesOnly with no favorites → empty → dropped
          query: RailQuery(favoritesOnly: true),
          priority: 0,
        ),
      ]);
      expect(results.map((r) => r.definition.id).toList(),
          ['first', 'second']);
    });
  });

  test('DefaultRailCatalog exposes the v1 rail set', () {
    final ids = DefaultRailCatalog.definitions().map((d) => d.id).toList();
    expect(
      ids,
      containsAll(<String>[
        'top-india', 'live-sports', 'movies-on-now',
        'hindi-news', 'favorites', 'recently-added',
      ]),
    );
  });
}
