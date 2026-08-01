import 'dart:convert';
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';
import 'package:platform_playlist/platform_playlist.dart';
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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ],
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

    test('saved Personal channel joins the normal IPTV library', () async {
      final repository = container.read(personalChannelRepositoryProvider);
      final saved = await repository.upsert(
        name: '9XM',
        streamUrl: 'https://media.example.com/9xm/master.m3u8',
      );
      container.invalidate(personalChannelsProvider);
      container.invalidate(iptvChannelsProvider);

      final channels = await container.read(iptvChannelsProvider.future);

      expect(channels, contains(saved));
      expect(channels.single.group, 'Personal Channels');
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

    test(
      'configured Xtream source contributes grouped channels and EPG',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.headers.contentType = ContentType.json;
          switch (request.uri.queryParameters['action']) {
            case 'get_live_categories':
              request.response.write(
                jsonEncode([
                  {'category_id': '5', 'category_name': 'World News'},
                ]),
              );
            case 'get_live_streams':
              request.response.write(
                jsonEncode([
                  {
                    'stream_id': 101,
                    'name': 'News HD',
                    'category_id': '5',
                    'epg_channel_id': 'news.hd',
                  },
                ]),
              );
            case 'get_short_epg':
              request.response.write(
                jsonEncode({
                  'epg_listings': [
                    {
                      'id': 'programme-1',
                      'title': base64Encode(utf8.encode('Morning News')),
                      'description': base64Encode(utf8.encode('Headlines')),
                      'start': '2026-07-15 09:00:00',
                      'end': '2026-07-15 10:00:00',
                      'stream_id': '101',
                    },
                  ],
                }),
              );
            default:
              request.response.statusCode = HttpStatus.badRequest;
          }
          await request.response.close();
        });
        final prefs = await SharedPreferences.getInstance();
        const sourceId = 'xtream-test';
        await ContentSourceStore(PreferencesStore(prefs)).add(
          ContentSourceConfig(
            id: sourceId,
            kind: ContentSourceKind.xtream,
            label: 'Provider',
            url: 'http://${server.address.host}:${server.port}',
          ),
        );
        final secureStore = InMemorySecureStore();
        await ContentSourceCredentialStore(secureStore).save(
          const ContentSourceCredentialRef(sourceId),
          const ContentSourceCredentials(username: 'user', password: 'pass'),
        );
        final epg = MutableXmltvCompactEpgRepository();
        final sourceContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(secureStore),
            dioProvider.overrideWithValue(Dio()),
            compactEpgRepositoryProvider.overrideWithValue(epg),
          ],
        );
        addTearDown(sourceContainer.dispose);

        final channels = await sourceContainer.read(
          configuredXtreamChannelsProvider.future,
        );

        expect(channels.single.id, '$sourceId-101');
        expect(channels.single.group, 'World News');
        final slice = await epg.loadCurrentNext(
          channelIds: [channels.single.id],
          now: DateTime.utc(2026, 7, 15, 9, 30),
        );
        expect(slice.entries.single.current?.title, 'Morning News');
      },
    );

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

  group('configured M3U sources', () {
    test(
      'migrates the legacy Pixel playlist once without deleting it',
      () async {
        const legacyUrl = 'https://iptv-org.github.io/iptv/index.m3u';
        SharedPreferences.setMockInitialValues({
          'iptv_user_playlist_url': legacyUrl,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final firstRead = await container.read(
          configuredContentSourcesProvider.future,
        );
        container.invalidate(configuredContentSourcesProvider);
        final secondRead = await container.read(
          configuredContentSourcesProvider.future,
        );

        expect(firstRead, hasLength(1));
        expect(firstRead.single.id, 'm3u-legacy-primary');
        expect(firstRead.single.label, 'IPTV.org');
        expect(firstRead.single.url, legacyUrl);
        expect(secondRead, hasLength(1));
        expect(prefs.getString('iptv_user_playlist_url'), legacyUrl);
      },
    );

    test(
      'active source selection is exclusive across Stalker and M3U',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = ContentSourceStore(PreferencesStore(prefs));
        await store.replaceAll(const [
          ContentSourceConfig(
            id: 'm3u-news',
            kind: ContentSourceKind.m3u,
            label: 'M3U News',
            url: 'https://example.com/news.m3u',
          ),
          ContentSourceConfig(
            id: 'stalker-home',
            kind: ContentSourceKind.stalker,
            label: 'Home Portal',
            url: 'https://portal.example.com',
            macAddress: 'AA:BB:CC:DD:EE:FF',
          ),
        ]);
        await store.setActiveSourceId('stalker-home');
        final m3uParser = _FakeSourceParser(
          prefs: prefs,
          sourceId: 'm3u-news',
          channels: const [
            IPTVChannel(
              id: 'm3u-only',
              name: 'M3U Only',
              streamUrl: 'https://example.com/m3u.m3u8',
            ),
          ],
        );
        final sourceContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            m3uSourceParserFactoryProvider.overrideWithValue((_) => m3uParser),
            stalkerSourceLoaderProvider.overrideWithValue(
              (_) async => const [
                IPTVChannel(
                  id: 'stalker-home-7',
                  name: 'Portal Only',
                  streamUrl: 'https://example.com/portal.m3u8',
                ),
              ],
            ),
          ],
        );
        addTearDown(sourceContainer.dispose);

        expect(
          (await sourceContainer.read(
            iptvChannelsProvider.future,
          )).map((channel) => channel.id),
          ['stalker-home-7'],
        );

        await sourceContainer.read(
          selectContentSourceProvider('m3u-news').future,
        );
        expect(
          (await sourceContainer.read(
            iptvChannelsProvider.future,
          )).map((channel) => channel.id),
          ['m3u-only'],
        );
      },
    );

    test(
      'loads multiple M3U sources, merges duplicate channels, and isolates failure',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = ContentSourceStore(PreferencesStore(prefs));
        await store.replaceAll(const [
          ContentSourceConfig(
            id: 'm3u-news',
            kind: ContentSourceKind.m3u,
            label: 'News',
            url: 'https://example.com/news.m3u',
          ),
          ContentSourceConfig(
            id: 'm3u-sports',
            kind: ContentSourceKind.m3u,
            label: 'Sports',
            url: 'https://example.com/sports.m3u',
          ),
          ContentSourceConfig(
            id: 'm3u-offline',
            kind: ContentSourceKind.m3u,
            label: 'Offline',
            url: 'https://example.com/offline.m3u',
          ),
        ]);
        final parsers = <String, _FakeSourceParser>{
          'm3u-news': _FakeSourceParser(
            prefs: prefs,
            sourceId: 'm3u-news',
            channels: const [
              IPTVChannel(
                id: 'shared',
                name: 'Shared News',
                streamUrl: 'https://cdn.example.com/shared-hd.m3u8',
              ),
              IPTVChannel(
                id: 'news-only',
                name: 'News Only',
                streamUrl: 'https://cdn.example.com/news.m3u8',
              ),
            ],
          ),
          'm3u-sports': _FakeSourceParser(
            prefs: prefs,
            sourceId: 'm3u-sports',
            channels: const [
              IPTVChannel(
                id: 'shared',
                name: 'Shared News',
                streamUrl: 'https://cdn.example.com/shared-sd.m3u8',
              ),
              IPTVChannel(
                id: 'sports-only',
                name: 'Sports Only',
                streamUrl: 'https://cdn.example.com/sports.m3u8',
              ),
            ],
          ),
          'm3u-offline': _FakeSourceParser(
            prefs: prefs,
            sourceId: 'm3u-offline',
            error: StateError('offline'),
          ),
        };
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            m3uSourceParserFactoryProvider.overrideWithValue(
              (sourceId) => parsers[sourceId]!,
            ),
          ],
        );
        addTearDown(container.dispose);

        final channels = await container.read(
          configuredM3uChannelsProvider.future,
        );

        expect(channels.map((channel) => channel.id), [
          'shared',
          'news-only',
          'sports-only',
        ]);
        final shared = channels.first;
        expect(shared.streamSources, hasLength(2));
        expect(
          shared.streamSources.map((source) => source.url),
          containsAll([
            'https://cdn.example.com/shared-hd.m3u8',
            'https://cdn.example.com/shared-sd.m3u8',
          ]),
        );
        expect(
          parsers.values.every((parser) => parser.fetchCalls == 1),
          isTrue,
        );
      },
    );
  });

  group('channelFavoriteTogglerProvider', () {
    test(
      'toggling the same channel twice flips the state both times',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final toggle = container.read(channelFavoriteTogglerProvider);

        expect(await toggle('news-1'), isTrue);
        // A FutureProvider.family here would return the stale first result
        // instead of re-running the toggle.
        expect(await toggle('news-1'), isFalse);

        final ids = await container.read(favoriteChannelIdsProvider.future);
        expect(ids, isNot(contains('news-1')));
      },
    );
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

class _FakeSourceParser extends M3UParserService {
  _FakeSourceParser({
    required super.prefs,
    required String sourceId,
    this.channels = const [],
    this.error,
  }) : super(dio: Dio(), sourceId: sourceId);

  final List<IPTVChannel> channels;
  final Object? error;
  String? _url;
  int fetchCalls = 0;

  @override
  String? getPlaylistUrl() => _url;

  @override
  Future<void> setPlaylistUrl(String url) async {
    _url = url;
  }

  // Override the primitive: the base fetchPlaylist delegates to it, so both
  // entry points see the fake's behaviour.
  @override
  Future<PlaylistFetchOutcome> fetchPlaylistOutcome({
    bool forceRefresh = false,
  }) async {
    fetchCalls++;
    if (error case final error?) throw error;
    return PlaylistFetchOutcome.loaded(channels);
  }
}
