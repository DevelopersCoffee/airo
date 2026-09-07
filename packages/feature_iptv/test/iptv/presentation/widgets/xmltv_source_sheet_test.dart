import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer({
    List<Override> extraOverrides = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extraOverrides,
      ],
    );
  }

  testWidgets('shows "no source configured" when nothing is saved', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No XMLTV source configured'), findsOneWidget);
  });

  testWidgets('shows the saved source URL and last-refreshed state', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container
        .read(xmltvSourceStoreProvider)
        .save(
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

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Current source: https://example.com/guide.xml'),
      findsOneWidget,
    );
  });

  testWidgets('shows the last error when refresh failed', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container
        .read(xmltvSourceStoreProvider)
        .save(
          const XmltvSourceConfig(
            url: 'https://example.com/guide.xml',
            lastError: 'Connection timed out',
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

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection timed out'), findsOneWidget);
  });

  testWidgets('helper text tells users to paste XMLTV, not HTML', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    expect(find.textContaining('XMLTV URL or .xml.gz'), findsOneWidget);
  });

  testWidgets('Remove source button clears the saved config', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container
        .read(xmltvSourceStoreProvider)
        .save(const XmltvSourceConfig(url: 'https://example.com/guide.xml'));
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove source'));
    await tester.pump();

    final config = await container.read(xmltvSourceStoreProvider).load();
    expect(config, isNull);
  });

  testWidgets('lists catalog entries with counts and a country label', (
    tester,
  ) async {
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith(
          (ref) async => [
            EpgCatalogEntry(
              countryCode: 'IN',
              sourceId: 'epgshare01',
              programmeCount: 5000,
              channelCount: 120,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('India'), findsOneWidget);
    expect(find.textContaining('120'), findsOneWidget);
    expect(find.text('Use'), findsOneWidget);
  });

  testWidgets('search filters the catalog list by country', (tester) async {
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith(
          (ref) async => [
            EpgCatalogEntry(
              countryCode: 'IN',
              sourceId: 'epgshare01',
              programmeCount: 5000,
              channelCount: 120,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
            EpgCatalogEntry(
              countryCode: 'GB',
              sourceId: 'epg_pw',
              programmeCount: 3000,
              channelCount: 80,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'united king');
    await tester.pump();

    expect(find.textContaining('United Kingdom'), findsOneWidget);
    expect(find.textContaining('India'), findsNothing);
  });

  testWidgets('tapping Use refreshes the system guide for that country', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final fakeService = _RecordingRefreshService(
      sourceStore: XmltvSourceStore(PreferencesStore(prefs)),
    );
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith(
          (ref) async => [
            EpgCatalogEntry(
              countryCode: 'IN',
              sourceId: 'epgshare01',
              programmeCount: 5000,
              channelCount: 120,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
          ],
        ),
        xmltvSourceRefreshServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(fakeService.lastCountries, {'IN'});
  });

  testWidgets('custom URL paste box is collapsed under "Advanced"', (
    tester,
  ) async {
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.text('Advanced: custom URL'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'XMLTV URL'), findsNothing);

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'XMLTV URL'), findsOneWidget);
  });
}

class _RecordingRefreshService extends XmltvSourceRefreshService {
  _RecordingRefreshService({required XmltvSourceStore sourceStore})
    : super(
        dio: Dio(),
        sourceStore: sourceStore,
        repository: MutableXmltvCompactEpgRepository(),
        downloadDirectoryProvider: () async => Directory.systemTemp,
      );

  Set<String>? lastCountries;

  @override
  Future<void> refreshSystemGuidesForCountries({
    required String manifestUrl,
    required Set<String> countries,
  }) async {
    lastCountries = countries;
  }
}
