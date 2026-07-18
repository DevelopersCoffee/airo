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
