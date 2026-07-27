import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late XmltvSourceStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = XmltvSourceStore(PreferencesStore(prefs));
  });

  test('load returns null when no source has been configured', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the config', () async {
    final config = XmltvSourceConfig(url: 'https://example.com/guide.xml');

    await store.save(config);
    final loaded = await store.load();

    expect(loaded?.url, 'https://example.com/guide.xml');
    expect(loaded?.lastRefreshedAt, isNull);
    expect(loaded?.lastError, isNull);
  });

  test('keeps ordered system and user sources independently', () async {
    await store.save(
      const XmltvSourceConfig(
        url: 'https://system.example/guide.xml.gz',
        kind: XmltvSourceKind.system,
        expectedSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    await store.save(
      const XmltvSourceConfig(url: 'https://user.example/guide.xml'),
    );

    final sources = await store.loadAll();

    expect(sources.map((source) => source.kind), [
      XmltvSourceKind.system,
      XmltvSourceKind.user,
    ]);
    expect((await store.load())?.url, 'https://user.example/guide.xml');
    expect(sources.first.expectedSha256, hasLength(64));
  });

  test('migrates the legacy single-source JSON without losing it', () async {
    SharedPreferences.setMockInitialValues({
      'xmltv_source_config': jsonEncode({
        'url': 'https://legacy.example/guide.xml',
        'lastRefreshedAt': '2026-07-17T12:00:00.000Z',
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final migratingStore = XmltvSourceStore(PreferencesStore(prefs));

    final sources = await migratingStore.loadAll();

    expect(sources.single.url, 'https://legacy.example/guide.xml');
    expect(sources.single.kind, XmltvSourceKind.user);
    expect(sources.single.lastRefreshedAt, DateTime.utc(2026, 7, 17, 12));
    expect(prefs.getString('xmltv_source_config'), isNull);
    expect(prefs.getString('xmltv_source_configs_v2'), isNotNull);
  });

  test(
    'recordRefreshSuccess sets lastRefreshedAt and clears lastError',
    () async {
      await store.save(
        const XmltvSourceConfig(
          url: 'https://example.com/guide.xml',
          lastError: 'timed out',
        ),
      );
      final refreshedAt = DateTime.utc(2026, 7, 17, 12);

      await store.recordRefreshSuccess(refreshedAt);
      final loaded = await store.load();

      expect(loaded?.lastRefreshedAt, refreshedAt);
      expect(loaded?.lastError, isNull);
    },
  );

  test(
    'recordRefreshError sets lastError, keeps prior lastRefreshedAt',
    () async {
      final refreshedAt = DateTime.utc(2026, 7, 17, 12);
      await store.save(
        XmltvSourceConfig(
          url: 'https://example.com/guide.xml',
          lastRefreshedAt: refreshedAt,
        ),
      );

      await store.recordRefreshError('connection reset');
      final loaded = await store.load();

      expect(loaded?.lastError, 'connection reset');
      expect(loaded?.lastRefreshedAt, refreshedAt);
    },
  );

  test('clear removes the configured source', () async {
    await store.save(
      const XmltvSourceConfig(url: 'https://example.com/guide.xml'),
    );

    await store.clear();

    expect(await store.load(), isNull);
  });

  test(
    'recordRefreshSuccess/Error is a no-op when no source is configured',
    () async {
      await store.recordRefreshSuccess(DateTime.utc(2026, 7, 17));

      expect(await store.load(), isNull);
    },
  );
}
