import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Found on the rig Pixel 9: after adding an unreachable playlist source the
/// screen went back to the "Add your playlist" empty state — the same view a
/// user with no sources at all sees. No spinner, no error, no retry, while the
/// source sat saved in the sources sheet.
///
/// Per-source failures must stay survivable (a dead source cannot take its
/// siblings down), but a total failure has to reach the UI as an error so the
/// existing retry affordance renders.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ContentSourceConfig source(String id) => ContentSourceConfig(
    id: id,
    kind: ContentSourceKind.m3u,
    label: id,
    url: 'https://example.com/$id.m3u',
  );

  test('every configured M3U source failing surfaces an error instead of an '
      'empty channel list', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        m3uSourceParserFactoryProvider.overrideWithValue(
          (sourceId) => _FakeSourceParser(
            prefs: prefs,
            sourceId: sourceId,
            error: StateError('connection refused'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(contentSourceStoreProvider).replaceAll([
      source('m3u-dead-one'),
      source('m3u-dead-two'),
    ]);
    container.invalidate(configuredContentSourcesProvider);

    await expectLater(
      container.read(configuredM3uChannelsProvider.future),
      throwsA(isA<PlaylistSourcesUnavailableException>()),
    );
  });

  test(
    'a source that still loads keeps the failing sibling non-fatal',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          m3uSourceParserFactoryProvider.overrideWithValue(
            (sourceId) => sourceId == 'm3u-live'
                ? _FakeSourceParser(
                    prefs: prefs,
                    sourceId: sourceId,
                    channels: const [
                      IPTVChannel(
                        id: 'live-1',
                        name: 'Live One',
                        streamUrl: 'https://cdn.example.com/live-1.m3u8',
                      ),
                    ],
                  )
                : _FakeSourceParser(
                    prefs: prefs,
                    sourceId: sourceId,
                    error: StateError('connection refused'),
                  ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentSourceStoreProvider).replaceAll([
        source('m3u-live'),
        source('m3u-dead'),
      ]);
      container.invalidate(configuredContentSourcesProvider);

      final channels = await container.read(
        configuredM3uChannelsProvider.future,
      );

      expect(channels.map((channel) => channel.id), ['live-1']);
    },
  );

  test('iptvChannelsProvider reports the failure when no other library has '
      'channels', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        configuredM3uChannelsProvider.overrideWith(
          (ref) async => throw const PlaylistSourcesUnavailableException(2),
        ),
        configuredXtreamChannelsProvider.overrideWith(
          (ref) async => const <IPTVChannel>[],
        ),
        m3uParserProvider.overrideWithValue(
          _FakeSourceParser(prefs: prefs, sourceId: 'legacy'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(iptvChannelsProvider.future),
      throwsA(isA<PlaylistSourcesUnavailableException>()),
    );
  });

  test(
    'iptvChannelsProvider keeps serving channels from a surviving library',
    () async {
      const survivor = IPTVChannel(
        id: 'xtream-1',
        name: 'Xtream One',
        streamUrl: 'https://cdn.example.com/xtream-1.m3u8',
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          configuredM3uChannelsProvider.overrideWith(
            (ref) async => throw const PlaylistSourcesUnavailableException(1),
          ),
          configuredXtreamChannelsProvider.overrideWith(
            (ref) async => const <IPTVChannel>[survivor],
          ),
          m3uParserProvider.overrideWithValue(
            _FakeSourceParser(prefs: prefs, sourceId: 'legacy'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final channels = await container.read(iptvChannelsProvider.future);

      expect(channels.map((channel) => channel.id), ['xtream-1']);
    },
  );

  test('a source that reports itself unavailable without throwing still counts '
      'as a failure', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        m3uSourceParserFactoryProvider.overrideWithValue(
          (sourceId) =>
              _UnavailableSourceParser(prefs: prefs, sourceId: sourceId),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(contentSourceStoreProvider).replaceAll([
      source('m3u-unreachable'),
    ]);
    container.invalidate(configuredContentSourcesProvider);

    await expectLater(
      container.read(configuredM3uChannelsProvider.future),
      throwsA(isA<PlaylistSourcesUnavailableException>()),
    );
  });

  test(
    'every configured Xtream source failing surfaces an error instead of an '
    'empty channel list',
    () async {
      // Bind then immediately close so the client gets connection-refused --
      // deterministic failure without keeping a live server around.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close(force: true);

      const sourceId = 'xtream-dead';
      await ContentSourceStore(PreferencesStore(prefs)).add(
        ContentSourceConfig(
          id: sourceId,
          kind: ContentSourceKind.xtream,
          label: 'Dead Provider',
          url: 'http://127.0.0.1:$port',
        ),
      );
      final secureStore = InMemorySecureStore();
      await ContentSourceCredentialStore(secureStore).save(
        const ContentSourceCredentialRef(sourceId),
        const ContentSourceCredentials(username: 'user', password: 'pass'),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(secureStore),
          dioProvider.overrideWithValue(Dio()),
          compactEpgRepositoryProvider.overrideWithValue(
            const EmptyCompactEpgRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(configuredXtreamChannelsProvider.future),
        throwsA(isA<PlaylistSourcesUnavailableException>()),
      );
    },
  );

  test(
    'every configured Stalker source failing surfaces an error instead of an '
    'empty channel list',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          stalkerSourceLoaderProvider.overrideWithValue(
            (config) async => throw StateError('portal down'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentSourceStoreProvider).replaceAll([
        ContentSourceConfig(
          id: 'stalker-dead',
          kind: ContentSourceKind.stalker,
          label: 'Dead Portal',
          url: 'http://portal.example.com',
          macAddress: '00:1A:79:00:00:00',
        ),
      ]);
      container.invalidate(configuredContentSourcesProvider);

      await expectLater(
        container.read(configuredStalkerChannelsProvider.future),
        throwsA(isA<PlaylistSourcesUnavailableException>()),
      );
    },
  );

  test(
    'iptvChannelsProvider reports the failure when Xtream is the only '
    'configured source and it is entirely unreachable',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          configuredM3uChannelsProvider.overrideWith(
            (ref) async => const <IPTVChannel>[],
          ),
          configuredXtreamChannelsProvider.overrideWith(
            (ref) async => throw const PlaylistSourcesUnavailableException(1),
          ),
          m3uParserProvider.overrideWithValue(
            _FakeSourceParser(prefs: prefs, sourceId: 'legacy'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(iptvChannelsProvider.future),
        throwsA(isA<PlaylistSourcesUnavailableException>()),
      );
    },
  );

  testWidgets('retrying after a failure re-runs the source loaders instead of '
      'replaying the cached error', (tester) async {
    var fetchAttempts = 0;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        m3uSourceParserFactoryProvider.overrideWithValue(
          (sourceId) => _CountingSourceParser(
            prefs: prefs,
            sourceId: sourceId,
            onFetch: () => fetchAttempts++,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(contentSourceStoreProvider).replaceAll([
      source('m3u-dead'),
    ]);
    container.invalidate(configuredContentSourcesProvider);

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              final channels = ref.watch(iptvChannelsProvider);
              return Text(
                channels.hasError ? 'error' : 'pending',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fetchAttempts, 1);
    expect(find.text('error'), findsOneWidget);

    // The naive retry: invalidating only the merged provider replays the
    // dependency's cached error without touching the source.
    widgetRef.invalidate(iptvChannelsProvider);
    await tester.pumpAndSettle();
    expect(
      fetchAttempts,
      1,
      reason: 'documents why Retry cannot just refresh iptvChannelsProvider',
    );

    invalidateChannelLibraries(widgetRef);
    await tester.pumpAndSettle();

    expect(
      fetchAttempts,
      2,
      reason: 'Retry must actually hit the source again',
    );
  });

  testWidgets(
    'a dead source is fetched once, not re-driven by every dependent that '
    'retries on the propagated error',
    (tester) async {
      var fetchAttempts = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          m3uSourceParserFactoryProvider.overrideWithValue(
            (sourceId) => _CountingSourceParser(
              prefs: prefs,
              sourceId: sourceId,
              onFetch: () => fetchAttempts++,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentSourceStoreProvider).replaceAll([
        source('m3u-dead'),
      ]);
      container.invalidate(configuredContentSourcesProvider);

      // The channel screen watches the rails alongside the channels; rails
      // await iptvChannelsProvider and so inherit its failure.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(railsProvider);
                final channels = ref.watch(iptvChannelsProvider);
                return Text(
                  channels.hasError ? 'error' : 'pending',
                  textDirection: TextDirection.ltr,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);

      // Let every retry timer in the chain fire.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        fetchAttempts,
        1,
        reason:
            'an unreachable source must be contacted once per user-initiated '
            'load, not hammered because dependents retry the error',
      );
    },
  );

  testWidgets(
    'a consumer of the favorites list does not re-drive the dead source '
    'either',
    (tester) async {
      var fetchAttempts = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          favoriteChannelIdsProvider.overrideWith((ref) async => const {'x'}),
          m3uSourceParserFactoryProvider.overrideWithValue(
            (sourceId) => _CountingSourceParser(
              prefs: prefs,
              sourceId: sourceId,
              onFetch: () => fetchAttempts++,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentSourceStoreProvider).replaceAll([
        source('m3u-dead'),
      ]);
      container.invalidate(configuredContentSourcesProvider);

      // The Favorites tab watches this and nothing else channel-shaped.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final favorites = ref.watch(favoriteChannelsProvider);
                return Text(
                  favorites.hasError ? 'error' : 'pending',
                  textDirection: TextDirection.ltr,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        fetchAttempts,
        1,
        reason:
            'favorites inherits the channel failure; retrying it re-contacts '
            'the dead source just like the rails did',
      );
    },
  );

  test('the failure message names no source URL', () {
    expect(
      const PlaylistSourcesUnavailableException(3).toString(),
      isNot(contains('http')),
    );
  });
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

  @override
  String? getPlaylistUrl() => _url;

  @override
  Future<void> setPlaylistUrl(String url) async {
    _url = url;
  }

  @override
  Future<PlaylistFetchOutcome> fetchPlaylistOutcome({
    bool forceRefresh = false,
  }) async {
    if (error case final error?) throw error;
    return PlaylistFetchOutcome.loaded(channels);
  }
}

/// Mirrors the real parser, which reports an unreachable source through the
/// outcome instead of throwing.
class _UnavailableSourceParser extends M3UParserService {
  _UnavailableSourceParser({required super.prefs, required String sourceId})
    : super(dio: Dio(), sourceId: sourceId);

  String? _url;

  @override
  String? getPlaylistUrl() => _url;

  @override
  Future<void> setPlaylistUrl(String url) async {
    _url = url;
  }

  @override
  Future<PlaylistFetchOutcome> fetchPlaylistOutcome({
    bool forceRefresh = false,
  }) async => const PlaylistFetchOutcome.unavailable();
}

/// Counts fetch attempts so a retry can be told apart from a replayed error.
class _CountingSourceParser extends M3UParserService {
  _CountingSourceParser({
    required super.prefs,
    required String sourceId,
    required this.onFetch,
  }) : super(dio: Dio(), sourceId: sourceId);

  final void Function() onFetch;
  String? _url;

  @override
  String? getPlaylistUrl() => _url;

  @override
  Future<void> setPlaylistUrl(String url) async {
    _url = url;
  }

  @override
  Future<PlaylistFetchOutcome> fetchPlaylistOutcome({
    bool forceRefresh = false,
  }) async {
    onFetch();
    return const PlaylistFetchOutcome.unavailable();
  }
}
