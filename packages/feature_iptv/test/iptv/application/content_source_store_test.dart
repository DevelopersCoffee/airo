import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/content_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ContentSourceStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = ContentSourceStore(PreferencesStore(prefs));
  });

  test('getAll returns empty list when nothing configured', () async {
    expect(await store.getAll(), isEmpty);
  });

  test('add then getAll round-trips an M3U config', () async {
    const config = ContentSourceConfig(
      id: 'm3u-1',
      kind: ContentSourceKind.m3u,
      label: 'My Playlist',
      url: 'https://example.com/playlist.m3u',
    );

    await store.add(config);
    final all = await store.getAll();

    expect(all, [config]);
  });

  test(
    'add then getAll round-trips a Stalker config with macAddress',
    () async {
      const config = ContentSourceConfig(
        id: 'stalker-1',
        kind: ContentSourceKind.stalker,
        label: 'My Stalker Portal',
        url: 'https://stalker.example.com',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      await store.add(config);
      final all = await store.getAll();

      expect(all.single.macAddress, 'AA:BB:CC:DD:EE:FF');
    },
  );

  test('add appends, does not replace, distinct ids', () async {
    const first = ContentSourceConfig(
      id: 'a',
      kind: ContentSourceKind.m3u,
      label: 'A',
      url: 'https://a.example.com',
    );
    const second = ContentSourceConfig(
      id: 'b',
      kind: ContentSourceKind.m3u,
      label: 'B',
      url: 'https://b.example.com',
    );

    await store.add(first);
    await store.add(second);
    final all = await store.getAll();

    expect(all.map((c) => c.id), ['a', 'b']);
  });

  test('remove deletes only the targeted config', () async {
    const first = ContentSourceConfig(
      id: 'a',
      kind: ContentSourceKind.m3u,
      label: 'A',
      url: 'https://a.example.com',
    );
    const second = ContentSourceConfig(
      id: 'b',
      kind: ContentSourceKind.m3u,
      label: 'B',
      url: 'https://b.example.com',
    );
    await store.add(first);
    await store.add(second);

    await store.remove('a');
    final all = await store.getAll();

    expect(all.map((c) => c.id), ['b']);
  });

  test(
    'ContentSourceConfig.toContentSource builds the right subtype for m3u',
    () {
      const config = ContentSourceConfig(
        id: 'm3u-1',
        kind: ContentSourceKind.m3u,
        label: 'My Playlist',
        url: 'https://example.com/playlist.m3u',
      );

      final source = config.toContentSource();

      expect(source, isA<M3uContentSource>());
      expect(
        (source as M3uContentSource).playlistUrl,
        'https://example.com/playlist.m3u',
      );
    },
  );

  test(
    'ContentSourceConfig.toContentSource builds StalkerContentSource with macAddress',
    () {
      const config = ContentSourceConfig(
        id: 'stalker-1',
        kind: ContentSourceKind.stalker,
        label: 'My Stalker Portal',
        url: 'https://stalker.example.com',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final source = config.toContentSource();

      expect(source, isA<StalkerContentSource>());
      expect((source as StalkerContentSource).macAddress, 'AA:BB:CC:DD:EE:FF');
    },
  );

  test(
    'ContentSourceConfig.toContentSource builds XtreamContentSource with a credentialRef keyed on the config id',
    () {
      const config = ContentSourceConfig(
        id: 'xtream-1',
        kind: ContentSourceKind.xtream,
        label: 'My Xtream',
        url: 'https://xtream.example.com',
      );

      final source = config.toContentSource();

      expect(source, isA<XtreamContentSource>());
      expect(
        (source as XtreamContentSource).credentialRef,
        const ContentSourceCredentialRef('xtream-1'),
      );
    },
  );
}
