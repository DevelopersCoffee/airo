import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const movieChannel = IPTVChannel(
    id: 'm3u-1',
    name: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    category: ChannelCategory.movies,
  );
  const seriesChannel = IPTVChannel(
    id: 'm3u-2',
    name: 'Example Show S01E01',
    streamUrl: 'https://example.com/1.mp4',
    group: 'TV Series',
    category: ChannelCategory.all,
  );
  const liveChannel = IPTVChannel(
    id: 'm3u-3',
    name: 'Example News',
    streamUrl: 'https://example.com/news.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  );

  Future<ProviderContainer> buildContainer(List<IPTVChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
      ],
    );
  }

  test('vodItemsProvider extracts and groups VOD entries from iptvChannelsProvider', () async {
    final container = await buildContainer([movieChannel, seriesChannel, liveChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final items = container.read(vodItemsProvider);

    expect(items.map((i) => i.id), containsAll(['m3u-1', 'm3u-2']));
    expect(items.any((i) => i.id == 'm3u-3'), isFalse);
  });

  test('vodStandaloneMoviesProvider excludes grouped episodes', () async {
    final container = await buildContainer([movieChannel, seriesChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final movies = container.read(vodStandaloneMoviesProvider);

    expect(movies.map((i) => i.id), ['m3u-1']);
  });

  test('vodSeriesGroupsProvider groups the series episode', () async {
    final container = await buildContainer([movieChannel, seriesChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final groups = container.read(vodSeriesGroupsProvider);

    expect(groups, hasLength(1));
    expect(groups.single.seriesTitle, 'Example Show');
  });

  test('empty source yields empty vodItemsProvider (empty-state case)', () async {
    final container = await buildContainer([liveChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final items = container.read(vodItemsProvider);

    expect(items, isEmpty);
  });

  test('filteredVodMoviesProvider filters standalone movies by search query', () async {
    const anotherMovie = IPTVChannel(
      id: 'm3u-4',
      name: 'Second Feature',
      streamUrl: 'https://example.com/second.mp4',
      group: 'Movies',
      category: ChannelCategory.movies,
    );
    final container = await buildContainer([movieChannel, anotherMovie]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    container.read(vodSearchQueryProvider.notifier).state = 'second';
    final filtered = container.read(filteredVodMoviesProvider);

    expect(filtered.map((i) => i.id), ['m3u-4']);
  });

  test('addToVodWatchHistoryProvider then vodContinueWatchingProvider round-trips', () async {
    final container = await buildContainer([movieChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final item = container.read(vodItemsProvider).single;

    await container.read(addToVodWatchHistoryProvider(item).future);
    final history = await container.read(vodContinueWatchingProvider.future);

    expect(history.map((i) => i.id), [item.id]);
  });
}
