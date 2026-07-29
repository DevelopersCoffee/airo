import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/feature_iptv.dart';
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

  test(
    'every configured M3U source failing surfaces an error instead of an '
    'empty channel list',
    () async {
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
      await container
          .read(contentSourceStoreProvider)
          .replaceAll([source('m3u-dead-one'), source('m3u-dead-two')]);
      container.invalidate(configuredContentSourcesProvider);

      await expectLater(
        container.read(configuredM3uChannelsProvider.future),
        throwsA(isA<PlaylistSourcesUnavailableException>()),
      );
    },
  );

  test('a source that still loads keeps the failing sibling non-fatal', () async {
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

    final channels = await container.read(configuredM3uChannelsProvider.future);

    expect(channels.map((channel) => channel.id), ['live-1']);
  });

  test(
    'iptvChannelsProvider reports the failure when no other library has '
    'channels',
    () async {
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
    },
  );

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

  test(
    'a source that reports itself unavailable without throwing still counts '
    'as a failure',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          m3uSourceParserFactoryProvider.overrideWithValue(
            (sourceId) => _UnavailableSourceParser(prefs: prefs, sourceId: sourceId),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(contentSourceStoreProvider)
          .replaceAll([source('m3u-unreachable')]);
      container.invalidate(configuredContentSourcesProvider);

      await expectLater(
        container.read(configuredM3uChannelsProvider.future),
        throwsA(isA<PlaylistSourcesUnavailableException>()),
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
