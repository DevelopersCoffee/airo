import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/country_xmltv_guide_coordinator.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late XmltvSourceStore store;
  late List<String> calls;
  late CountryXmltvGuideCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = XmltvSourceStore(PreferencesStore(prefs));
    calls = <String>[];
    coordinator = CountryXmltvGuideCoordinator(
      sourceStore: store,
      refreshCountryShard: (country) async {
        calls.add(country);
      },
    );
  });

  test('null country does not fetch', () async {
    await coordinator.sync(country: null);
    expect(calls, isEmpty);
  });

  test('IN fetches once as country shard', () async {
    await coordinator.sync(country: 'IN');
    expect(calls, ['IN']);
  });

  test('user XMLTV skips country fetch', () async {
    await store.save(
      const XmltvSourceConfig(
        url: 'https://example.com/user.xml',
        kind: XmltvSourceKind.user,
      ),
    );
    await coordinator.sync(country: 'IN');
    expect(calls, isEmpty);
  });

  test('overlapping syncs land the later country', () async {
    final release = Completer<void>();
    coordinator = CountryXmltvGuideCoordinator(
      sourceStore: store,
      refreshCountryShard: (country) async {
        calls.add(country);
        if (country == 'IN') await release.future;
      },
    );
    final first = coordinator.sync(country: 'IN');
    await Future<void>.delayed(Duration.zero);
    final second = coordinator.sync(country: 'US');
    release.complete();
    await first;
    await second;
    expect(calls.last, 'US');
  });
}
