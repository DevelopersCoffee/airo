import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  ProviderContainer buildContainer({
    List<IPTVChannel> channels = const [channel],
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
      ],
    );
    return container;
  }

  test(
    'guideFilteredChannelsProvider filters by guideSearchQueryProvider, independent of channelSearchQueryProvider',
    () async {
      const other = IPTVChannel(
        id: 'channel-2',
        name: 'Second Channel',
        streamUrl: 'https://example.com/2.m3u8',
        group: 'Sports',
      );
      final container = buildContainer(channels: const [channel, other]);
      addTearDown(container.dispose);

      // channelSearchIndexProvider derives from iptvChannelsProvider's
      // AsyncValue; without awaiting it first, the index would still be
      // AsyncLoading and guideFilteredChannelsProvider would return [].
      await container.read(iptvChannelsProvider.future);

      container.read(guideSearchQueryProvider.notifier).state = 'second';
      final filtered = container.read(guideFilteredChannelsProvider);

      expect(filtered.map((c) => c.id), ['channel-2']);
      // The main screen's search query provider is untouched.
      expect(container.read(channelSearchQueryProvider), '');
    },
  );

  test('guide retains the global country and language scope', () async {
    const italian = IPTVChannel(
      id: 'channel-it',
      name: 'Italian Channel',
      streamUrl: 'https://example.com/italian.m3u8',
      group: 'News',
      country: 'IT',
      languages: ['it'],
    );
    final container = buildContainer(channels: const [channel, italian]);
    addTearDown(container.dispose);

    await container.read(iptvChannelsProvider.future);
    container.read(channelFiltersProvider.notifier).setCountry('IT');
    container.read(channelFiltersProvider.notifier).setLanguage('it');

    expect(
      container.read(guideFilteredChannelsProvider).map((item) => item.id),
      ['channel-it'],
    );
  });

  test(
    'guideFilteredChannelsProvider excludes channels in a hidden group (CV-021)',
    () async {
      const other = IPTVChannel(
        id: 'channel-2',
        name: 'Second Channel',
        streamUrl: 'https://example.com/2.m3u8',
        group: 'Sports',
      );
      final container = buildContainer(channels: const [channel, other]);
      addTearDown(container.dispose);

      await container.read(iptvChannelsProvider.future);
      await container.read(hiddenGroupsStorageProvider).hideGroup('Sports');
      container.invalidate(hiddenGroupIdsProvider);
      await container.read(hiddenGroupIdsProvider.future);

      final filtered = container.read(guideFilteredChannelsProvider);

      expect(filtered.map((c) => c.id), ['channel-1']);
    },
  );

  test('guideWindowStartProvider floors to the nearest 30 minutes', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final start = container.read(guideWindowStartProvider);

    expect(start.minute == 0 || start.minute == 30, isTrue);
    expect(start.second, 0);
  });
}
