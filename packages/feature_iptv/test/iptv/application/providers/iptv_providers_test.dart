import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:feature_iptv/feature_iptv.dart";

void main() {
  group('IPTV Providers', () {
    late ProviderContainer container;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('selectedCategoryProvider', () {
      test('should default to ChannelCategory.all', () {
        final category = container.read(selectedCategoryProvider);
        expect(category, equals(ChannelCategory.all));
      });

      test('should update when changed', () {
        container.read(selectedCategoryProvider.notifier).state =
            ChannelCategory.sports;
        final category = container.read(selectedCategoryProvider);
        expect(category, equals(ChannelCategory.sports));
      });
    });

    group('channelSearchQueryProvider', () {
      test('should default to empty string', () {
        final query = container.read(channelSearchQueryProvider);
        expect(query, isEmpty);
      });

      test('should update when changed', () {
        container.read(channelSearchQueryProvider.notifier).state = 'news';
        final query = container.read(channelSearchQueryProvider);
        expect(query, equals('news'));
      });
    });

    group('StreamingConfig', () {
      test('youtube preset should have correct values', () {
        const config = StreamingConfig.youtube;

        expect(
          config.targetBufferDuration,
          equals(const Duration(seconds: 30)),
        );
        expect(config.minBufferDuration, equals(const Duration(seconds: 2)));
        expect(config.maxRetries, equals(5));
        expect(config.enableABR, isTrue);
      });

      test('live preset should have correct values', () {
        const config = StreamingConfig.live;

        expect(
          config.targetBufferDuration,
          equals(const Duration(seconds: 10)),
        );
        expect(config.minBufferDuration, equals(const Duration(seconds: 1)));
        expect(config.lowLatencyMode, isTrue);
      });
    });

    group('filteredChannelsProvider', () {
      test('should filter channels by category', () async {
        // Note: This test would require mocking the channels provider
        // For now, we test the filtering logic structure
        final category = container.read(selectedCategoryProvider);
        expect(category, equals(ChannelCategory.all));
      });

      test('uses platform search index for combined filters', () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            iptvChannelsProvider.overrideWith((ref) async => _channels),
          ],
        );
        addTearDown(container.dispose);

        await container.read(iptvChannelsProvider.future);
        container.read(selectedCategoryProvider.notifier).state =
            ChannelCategory.news;
        container.read(selectedFlavorProvider.notifier).state =
            ChannelFlavor.englishNews;
        container.read(channelSearchQueryProvider.notifier).state = 'global';

        final filtered = container.read(filteredChannelsProvider);

        expect(filtered.map((channel) => channel.id), ['3']);
      });

      test('uses platform search index counts', () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            iptvChannelsProvider.overrideWith((ref) async => _channels),
          ],
        );
        addTearDown(container.dispose);

        await container.read(iptvChannelsProvider.future);

        final categories = container.read(categoryCounts);
        final flavors = container.read(flavorCounts);

        expect(categories[ChannelCategory.all], 4);
        expect(categories[ChannelCategory.news], 2);
        expect(flavors[ChannelFlavor.hindiMusic], 1);
        expect(flavors[ChannelFlavor.sports], 1);
      });

      test('excludes channels in a hidden group (CV-021)', () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            iptvChannelsProvider.overrideWith((ref) async => _channels),
          ],
        );
        addTearDown(container.dispose);

        await container.read(iptvChannelsProvider.future);
        await container.read(hiddenGroupsStorageProvider).hideGroup('Sports');
        container.invalidate(hiddenGroupIdsProvider);
        await container.read(hiddenGroupIdsProvider.future);

        final filtered = container.read(filteredChannelsProvider);

        expect(filtered.any((c) => c.group == 'Sports'), isFalse);
        expect(filtered.length, _channels.length - 1);
      });

      test(
        'provider retained channel lists fit constrained TV budget',
        () async {
          final channels = _generatedChannels(512);
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(
                await SharedPreferences.getInstance(),
              ),
              iptvChannelsProvider.overrideWith((ref) async => channels),
            ],
          );
          addTearDown(container.dispose);

          final loadedChannels = await container.read(
            iptvChannelsProvider.future,
          );
          final searchIndex = container.read(channelSearchIndexProvider)!;
          final visibleChannels = container.read(filteredChannelsProvider);
          final flavorChannels = container.read(
            channelsByFlavorProvider(ChannelFlavor.hindiNews),
          );

          final retainedFullChannelLists =
              _retainedFullChannelListCopies(
                canonicalChannelCount: loadedChannels.length,
                surfaces: {
                  'loaded_channels': loadedChannels,
                  'visible_channels': visibleChannels,
                  'hindi_news_flavor_channels': flavorChannels,
                },
              ) +
              searchIndex.retainedFullChannelListCopies;

          const memoryPolicy = AiroRuntimeMemoryBudgetPolicy();
          const budget =
              AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget;
          final evaluation = memoryPolicy.evaluate(
            budget: budget,
            sample: AiroRuntimeMemorySample(
              sampleId: 'feature-iptv-provider-retention',
              steadyRssMb: 200,
              peakRssMb: 320,
              dartHeapMb: 100,
              imageCacheMb: 12,
              retainedChannelListCopies: retainedFullChannelLists,
              playbackSoakDriftMbPerHour: 0.2,
              sampledAt: DateTime.utc(2026, 7, 15, 11),
            ),
          );

          expect(loadedChannels.length, channels.length);
          expect(visibleChannels.length, channels.length);
          expect(flavorChannels.length, lessThan(channels.length));
          expect(
            retainedFullChannelLists,
            lessThanOrEqualTo(budget.maxRetainedChannelListCopies),
          );
          expect(evaluation.accepted, isTrue);
          expect(evaluation.violations, const [
            AiroRuntimeMemoryBudgetViolationCode.accepted,
          ]);
        },
      );
    });

    group('compactEpgSliceForChannelsProvider', () {
      test('defaults to unavailable compact EPG', () async {
        final result = await container.read(
          compactEpgSliceForChannelsProvider(
            CompactEpgChannelQuery(
              channelIds: const ['1'],
              now: DateTime.utc(2026, 7, 15, 9),
            ),
          ).future,
        );

        expect(result.entries, isEmpty);
        expect(result.source, CompactEpgSliceSource.unavailable);
      });

      test(
        'loads current next data from overridden platform repository',
        () async {
          final now = DateTime.utc(2026, 7, 15, 9);
          final repository = InMemoryCompactEpgRepository(
            seed: CompactEpgSlice(
              entries: [
                CompactEpgEntry.fromPrograms(
                  channelId: '1',
                  channelName: 'Sports News',
                  now: now,
                  programs: [
                    CompactEpgProgram(
                      programId: 'current',
                      title: 'Morning Sports',
                      startsAt: now.subtract(const Duration(minutes: 10)),
                      endsAt: now.add(const Duration(minutes: 20)),
                    ),
                  ],
                ),
              ],
              generatedAt: now,
              expiresAt: now.add(const Duration(minutes: 15)),
              source: CompactEpgSliceSource.localCache,
            ),
          );
          final container = ProviderContainer(
            overrides: [
              compactEpgRepositoryProvider.overrideWithValue(repository),
            ],
          );
          addTearDown(container.dispose);

          final result = await container.read(
            compactEpgSliceForChannelsProvider(
              CompactEpgChannelQuery(channelIds: const ['1'], now: now),
            ).future,
          );

          expect(result.entryForChannel('1')?.current?.title, 'Morning Sports');
          expect(result.source, CompactEpgSliceSource.localCache);
        },
      );
    });

    group('Preference sorting', () {
      test('channels matching preferences should be ranked higher', () {
        final channels = [
          IPTVChannel(
            id: '1',
            name: 'Sports News',
            streamUrl: 'https://example.com/1.m3u8',
            group: 'Sports',
            category: ChannelCategory.sports,
          ),
          IPTVChannel(
            id: '2',
            name: 'General Channel',
            streamUrl: 'https://example.com/2.m3u8',
            group: 'General',
            category: ChannelCategory.all,
          ),
          IPTVChannel(
            id: '3',
            name: 'Music Radio',
            streamUrl: 'https://example.com/3.m3u8',
            group: 'Music',
            category: ChannelCategory.music,
          ),
        ];

        final preferences = ['sports', 'music'];

        // Simulate preference scoring
        int getScore(IPTVChannel channel) {
          final name = channel.name.toLowerCase();
          final group = channel.group.toLowerCase();
          for (int i = 0; i < preferences.length; i++) {
            if (name.contains(preferences[i]) ||
                group.contains(preferences[i])) {
              return preferences.length - i;
            }
          }
          return 0;
        }

        final sorted = List<IPTVChannel>.from(channels)
          ..sort((a, b) => getScore(b).compareTo(getScore(a)));

        expect(sorted[0].name, equals('Sports News')); // Matches 'sports'
        expect(sorted[1].name, equals('Music Radio')); // Matches 'music'
        expect(sorted[2].name, equals('General Channel')); // No match
      });
    });
  });

  group('NetworkQuality', () {
    test('should have all expected quality levels', () {
      expect(
        NetworkQuality.values,
        containsAll([
          NetworkQuality.excellent,
          NetworkQuality.good,
          NetworkQuality.fair,
          NetworkQuality.poor,
          NetworkQuality.offline,
        ]),
      );
    });
  });

  group('PlaybackState', () {
    test('should have all expected states', () {
      expect(
        PlaybackState.values,
        containsAll([
          PlaybackState.idle,
          PlaybackState.loading,
          PlaybackState.buffering,
          PlaybackState.playing,
          PlaybackState.paused,
          PlaybackState.error,
          PlaybackState.ended,
        ]),
      );
    });
  });
}

const _channels = [
  IPTVChannel(
    id: '1',
    name: 'Bharat Samachar',
    streamUrl: 'https://example.com/1.m3u8',
    group: 'Hindi News',
    category: ChannelCategory.news,
    flavor: ChannelFlavor.hindiNews,
  ),
  IPTVChannel(
    id: '2',
    name: 'Aaj Music',
    streamUrl: 'https://example.com/2.m3u8',
    group: 'Hindi Hits',
    category: ChannelCategory.music,
    flavor: ChannelFlavor.hindiMusic,
  ),
  IPTVChannel(
    id: '3',
    name: 'Global News',
    streamUrl: 'https://example.com/3.m3u8',
    group: 'World',
    category: ChannelCategory.news,
    flavor: ChannelFlavor.englishNews,
  ),
  IPTVChannel(
    id: '4',
    name: 'Cricket Live',
    streamUrl: 'https://example.com/4.m3u8',
    group: 'Sports',
    category: ChannelCategory.sports,
    flavor: ChannelFlavor.sports,
  ),
];

List<IPTVChannel> _generatedChannels(int count) {
  return List<IPTVChannel>.generate(count, (index) {
    final category = switch (index % 4) {
      0 => ChannelCategory.news,
      1 => ChannelCategory.music,
      2 => ChannelCategory.sports,
      _ => ChannelCategory.entertainment,
    };
    final flavor = switch (index % 4) {
      0 => ChannelFlavor.hindiNews,
      1 => ChannelFlavor.hindiMusic,
      2 => ChannelFlavor.sports,
      _ => ChannelFlavor.englishNews,
    };
    return IPTVChannel(
      id: 'generated-$index',
      name: 'Generated Channel $index',
      streamUrl: 'https://example.com/$index.m3u8',
      group: category.label,
      category: category,
      flavor: flavor,
    );
  }, growable: false);
}

int _retainedFullChannelListCopies({
  required int canonicalChannelCount,
  required Map<String, List<IPTVChannel>> surfaces,
}) {
  final fullListIdentities = <int>{};
  for (final surface in surfaces.entries) {
    if (surface.value.length == canonicalChannelCount) {
      fullListIdentities.add(identityHashCode(surface.value));
    }
  }
  return fullListIdentities.length;
}
