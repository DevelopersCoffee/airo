import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
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
    CompactEpgRepository? epgRepository,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
        if (epgRepository != null)
          compactEpgRepositoryProvider.overrideWithValue(epgRepository),
      ],
    );
    return container;
  }

  test(
    'guideEpgWindowProvider queries using the raw channel id when no override is set',
    () async {
      // Anchored to real "now" (not a fixed calendar date): guideWindowStartProvider
      // floors the actual wall-clock time, so a hardcoded fixture time would only
      // fall inside the query window when the suite happened to run at that
      // moment.
      final now = DateTime.now().toUtc();
      final inner = InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: [
            CompactEpgEntry(
              channelId: 'channel-1',
              channelName: 'Example Channel',
              current: CompactEpgProgram(
                programId: 'p1',
                title: 'Now Showing',
                startsAt: now.subtract(const Duration(minutes: 5)),
                endsAt: now.add(const Duration(minutes: 25)),
              ),
            ),
          ],
          generatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          source: CompactEpgSliceSource.localCache,
        ),
      );
      final container = buildContainer(epgRepository: inner);
      addTearDown(container.dispose);

      final window = await container.read(guideEpgWindowProvider.future);

      expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
    },
  );

  test(
    'guideEpgWindowProvider queries using the override EPG id, remaps result to the channel id',
    () async {
      final now = DateTime.now().toUtc();
      final inner = InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: [
            CompactEpgEntry(
              channelId: 'overridden.epg.id',
              channelName: 'Example Channel (EPG)',
              current: CompactEpgProgram(
                programId: 'p1',
                title: 'Now Showing',
                startsAt: now.subtract(const Duration(minutes: 5)),
                endsAt: now.add(const Duration(minutes: 25)),
              ),
            ),
          ],
          generatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          source: CompactEpgSliceSource.localCache,
        ),
      );
      final container = buildContainer(epgRepository: inner);
      addTearDown(container.dispose);

      final overrideStore = container.read(
        epgChannelMatchOverrideStoreProvider,
      );
      await overrideStore.setOverride(
        channelId: 'channel-1',
        epgChannelId: 'overridden.epg.id',
      );

      final window = await container.read(guideEpgWindowProvider.future);

      // Result is keyed back to the ORIGINAL channel id, not the EPG id.
      expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
      expect(window.entryForChannel('overridden.epg.id'), isNull);
    },
  );

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

  test(
    'guideEpgWindowProvider does not query EPG for channels in a hidden group (CV-021)',
    () async {
      const other = IPTVChannel(
        id: 'channel-2',
        name: 'Second Channel',
        streamUrl: 'https://example.com/2.m3u8',
        group: 'Sports',
      );
      final now = DateTime.now().toUtc();
      final inner = InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: [
            CompactEpgEntry(
              channelId: 'channel-1',
              channelName: 'Example Channel',
              current: CompactEpgProgram(
                programId: 'p1',
                title: 'Now Showing',
                startsAt: now.subtract(const Duration(minutes: 5)),
                endsAt: now.add(const Duration(minutes: 25)),
              ),
            ),
            CompactEpgEntry(
              channelId: 'channel-2',
              channelName: 'Second Channel',
              current: CompactEpgProgram(
                programId: 'p2',
                title: 'Match Highlights',
                startsAt: now.subtract(const Duration(minutes: 5)),
                endsAt: now.add(const Duration(minutes: 25)),
              ),
            ),
          ],
          generatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          source: CompactEpgSliceSource.localCache,
        ),
      );
      final container = buildContainer(
        channels: const [channel, other],
        epgRepository: inner,
      );
      addTearDown(container.dispose);

      await container.read(hiddenGroupsStorageProvider).hideGroup('Sports');
      container.invalidate(hiddenGroupIdsProvider);

      final window = await container.read(guideEpgWindowProvider.future);

      expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
      expect(window.entryForChannel('channel-2'), isNull);
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
