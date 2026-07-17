import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:feature_iptv/presentation/widgets/xmltv_source_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  testWidgets('shows "no source configured" when nothing is saved', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No XMLTV source configured'), findsOneWidget);
  });

  testWidgets('shows the saved source URL and last-refreshed state', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(xmltvSourceStoreProvider).save(
      XmltvSourceConfig(
        url: 'https://example.com/guide.xml',
        lastRefreshedAt: DateTime.utc(2026, 7, 17, 10),
      ),
    );
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Current source:'), findsOneWidget);
  });

  testWidgets('shows the last error when refresh failed', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(xmltvSourceStoreProvider).save(
      const XmltvSourceConfig(url: 'https://example.com/guide.xml', lastError: 'Connection timed out'),
    );
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Connection timed out'), findsOneWidget);
  });

  testWidgets('Remove source button clears the saved config', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(xmltvSourceStoreProvider).save(
      const XmltvSourceConfig(url: 'https://example.com/guide.xml'),
    );
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Remove source'));
    await tester.pump();

    final config = await container.read(xmltvSourceStoreProvider).load();
    expect(config, isNull);
  });
}
