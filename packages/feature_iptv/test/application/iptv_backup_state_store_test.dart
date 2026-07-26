import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_favorites/platform_favorites.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late ContentSourceStore sources;
  late FavoriteChannelsStorage favorites;
  late XmltvSourceStore xmltv;
  late _FakeSettingsStore settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    final keyValues = PreferencesStore(preferences);
    sources = ContentSourceStore(keyValues);
    favorites = FavoriteChannelsStorage(preferences, store: keyValues);
    xmltv = XmltvSourceStore(keyValues);
    settings = _FakeSettingsStore({'captions': 'on'});
  });

  IptvBackupStateStore createStore() {
    return IptvBackupStateStore(
      contentSources: sources,
      favorites: favorites,
      xmltv: xmltv,
      settings: settings,
      resolveFavoriteChannels: (ids) async => [
        for (final id in ids)
          IPTVChannel(
            id: id,
            name: 'Channel $id',
            streamUrl: 'https://example.com/$id.m3u8',
            group: 'News',
          ),
      ],
    );
  }

  test('replaces and reads all backup domains with source metadata', () async {
    final store = createStore();
    final snapshot = AiroBackupSnapshot(
      playlistSources: const [
        AiroBackupSource(
          id: 'stalker-a',
          url: 'https://provider.example',
          label: 'Provider',
          metadata: {'kind': 'stalker', 'macAddress': '00:11:22:33:44:55'},
        ),
      ],
      favorites: const [
        AiroBackupFavorite(
          channelId: 'news-a',
          name: 'Channel news-a',
          url: 'https://example.com/news-a.m3u8',
          group: 'News',
        ),
      ],
      epgSources: const [
        AiroBackupSource(
          id: 'xmltv-primary',
          url: 'https://example.com/guide.xml',
          label: 'XMLTV guide',
          metadata: {'lastRefreshedAt': '2026-07-27T12:00:00.000Z'},
        ),
      ],
      settings: const {'captions': 'off'},
    );

    await store.replaceAtomically(snapshot);
    final restored = await store.read();

    expect(restored.toMap(), snapshot.toMap());
    expect((await sources.getAll()).single.kind, ContentSourceKind.stalker);
  });

  test('failed apply rolls every previously written domain back', () async {
    await sources.replaceAll(const [
      ContentSourceConfig(
        id: 'original',
        kind: ContentSourceKind.m3u,
        label: 'Original',
        url: 'https://example.com/original.m3u',
      ),
    ]);
    await favorites.replaceAll(const ['original-channel']);
    final store = createStore();
    final before = await store.read();
    settings.failNextReplace = true;
    final incoming = AiroBackupSnapshot(
      playlistSources: const [],
      favorites: const [],
      epgSources: const [],
      settings: const {'captions': 'off'},
    );

    await expectLater(
      store.replaceAtomically(incoming),
      throwsA(isA<StateError>()),
    );

    expect((await store.read()).toMap(), before.toMap());
  });

  test(
    'shared preferences settings store preserves types and rejects keys',
    () async {
      await preferences.setBool('caption_preference_enabled', true);
      await preferences.setString('video_aspect_ratio', 'cover');
      final store = SharedPreferencesIptvBackupSettingsStore(preferences);
      final saved = await store.read();

      await preferences.clear();
      await store.replace(saved);

      expect(preferences.getBool('caption_preference_enabled'), isTrue);
      expect(preferences.getString('video_aspect_ratio'), 'cover');
      await expectLater(
        store.replace(const {'not_an_iptv_setting': 'string:value'}),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('unsupported source kind is rejected without changing state', () async {
    await sources.replaceAll(const [
      ContentSourceConfig(
        id: 'original',
        kind: ContentSourceKind.m3u,
        label: 'Original',
        url: 'https://example.com/original.m3u',
      ),
    ]);
    final store = createStore();
    final before = await store.read();

    await expectLater(
      store.replaceAtomically(
        AiroBackupSnapshot(
          playlistSources: const [
            AiroBackupSource(
              id: 'future',
              url: 'https://example.com/future',
              label: 'Future',
              metadata: {'kind': 'future-provider'},
            ),
          ],
          favorites: const [],
          epgSources: const [],
          settings: const {},
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect((await store.read()).toMap(), before.toMap());
  });
}

class _FakeSettingsStore implements IptvBackupSettingsStore {
  _FakeSettingsStore(this.values);

  Map<String, String> values;
  bool failNextReplace = false;

  @override
  Future<Map<String, String>> read() async => Map.of(values);

  @override
  Future<void> replace(Map<String, String> settings) async {
    if (failNextReplace) {
      failNextReplace = false;
      throw StateError('injected_settings_failure');
    }
    values = Map.of(settings);
  }
}
