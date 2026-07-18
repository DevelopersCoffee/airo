import 'package:feature_iptv/application/providers/local_iptv_search_providers.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const bbcNews = IPTVChannel(
    id: 'c1',
    name: 'BBC News',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
  );
  const cnn = IPTVChannel(
    id: 'c2',
    name: 'CNN International',
    streamUrl: 'https://example.com/c2.m3u8',
    group: 'News',
  );

  ProviderContainer buildContainer({
    List<IPTVChannel> channels = const [bbcNews, cnn],
    CompactEpgRepository? epgRepository,
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
        if (epgRepository != null)
          compactEpgRepositoryProvider.overrideWithValue(epgRepository),
      ],
    );
  }

  test('builds an index from channels with no favorites/recents/EPG', () async {
    final container = buildContainer(
      epgRepository: InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: const [],
          generatedAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          source: CompactEpgSliceSource.unavailable,
        ),
      ),
    );
    addTearDown(container.dispose);

    final index = await container.read(localIptvSearchIndexProvider.future);

    final results = index.search('BBC');
    expect(results, isNotEmpty);
    expect(results.first.channelId, 'c1');
  });

  test('favorited channels are reflected in search ranking', () async {
    final container = buildContainer(
      epgRepository: InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: const [],
          generatedAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          source: CompactEpgSliceSource.unavailable,
        ),
      ),
    );
    addTearDown(container.dispose);

    await container.read(favoriteChannelsStorageProvider).addFavorite('c2');
    container.invalidate(favoriteChannelIdsProvider);

    final index = await container.read(localIptvSearchIndexProvider.future);
    final result = index.search('CNN').firstWhere((r) => r.channelId == 'c2');

    expect(result.isFavorite, isTrue);
  });

  test('rebuilds when the underlying channel list changes', () async {
    final container = buildContainer(channels: const [bbcNews]);
    addTearDown(container.dispose);

    final firstIndex = await container.read(
      localIptvSearchIndexProvider.future,
    );
    expect(firstIndex.search('CNN'), isEmpty);
  });
}
