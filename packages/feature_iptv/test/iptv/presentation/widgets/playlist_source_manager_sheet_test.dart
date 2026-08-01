import 'package:core_ui/core_ui.dart';
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> buildContainer({
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        m3uSourceParserFactoryProvider.overrideWithValue(
          (sourceId) => M3UParserService(
            dio: Dio(),
            prefs: prefs,
            sourceId: sourceId,
            cacheDirectoryProvider: () async => Directory.systemTemp,
            downloadDirectoryProvider: () async => Directory.systemTemp,
          ),
        ),
      ],
    );
  }

  Future<void> pumpManager(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PlaylistSourceManagerSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpTvManagerDialog(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: TvFocusable(
                    autofocus: true,
                    onSelect: () {
                      showPlaylistSourceSheet(context, ref);
                    },
                    child: const SizedBox(
                      width: 240,
                      height: 64,
                      child: Center(child: Text('Open playlist sources')),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the existing Pixel playlist as a named source', (
    tester,
  ) async {
    final container = await buildContainer(
      preferences: const {
        'iptv_user_playlist_url': 'https://iptv-org.github.io/iptv/index.m3u',
      },
    );
    addTearDown(container.dispose);

    await pumpManager(tester, container);

    expect(find.text('Playlist sources'), findsOneWidget);
    expect(find.text('1 playlist source'), findsOneWidget);
    expect(find.text('IPTV.org'), findsOneWidget);
    expect(find.text('iptv-org.github.io/iptv/index.m3u'), findsOneWidget);
  });

  testWidgets('adds a second IPTV.org playlist from a touch preset', (
    tester,
  ) async {
    final container = await buildContainer(
      preferences: const {
        'iptv_user_playlist_url': 'https://iptv-org.github.io/iptv/index.m3u',
      },
    );
    addTearDown(container.dispose);
    await pumpManager(tester, container);

    await tester.tap(find.byKey(const ValueKey('playlist-source-add-button')));
    await tester.pump();
    await tester.tap(find.text('By country'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('playlist-source-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('2 playlist sources'), findsOneWidget);
    expect(find.text('IPTV.org'), findsOneWidget);
    expect(find.text('IPTV.org · By country'), findsOneWidget);
    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources, hasLength(2));
  });

  testWidgets('validates malformed URLs before persistence', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpManager(tester, container);

    await tester.tap(find.byKey(const ValueKey('playlist-source-add-button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-source-label-field')),
      'Broken',
    );
    await tester.enterText(
      find.byKey(const ValueKey('playlist-source-url-field')),
      'not-a-url',
    );
    await tester.tap(find.byKey(const ValueKey('playlist-source-save-button')));
    await tester.pump();

    expect(
      find.text('Enter a valid http:// or https:// playlist URL.'),
      findsOneWidget,
    );
    expect(
      await container.read(configuredContentSourcesProvider.future),
      isEmpty,
    );
  });

  testWidgets('removes one playlist while keeping its sibling', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(
      addM3uContentSourceProvider((
        label: 'News',
        url: 'https://example.com/news.m3u',
      )).future,
    );
    await container.read(
      addM3uContentSourceProvider((
        label: 'Sports',
        url: 'https://example.com/sports.m3u',
      )).future,
    );
    await pumpManager(tester, container);

    await tester.tap(find.byTooltip('Remove News'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Other playlist sources and their channels will stay available.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pump();

    expect(find.widgetWithText(ListTile, 'News'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Sports'), findsOneWidget);
    await tester.pumpAndSettle();
    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources.map((source) => source.label), ['Sports']);
  });

  testWidgets('primary touch actions meet the 48 dp target', (tester) async {
    final container = await buildContainer(
      preferences: const {
        'iptv_user_playlist_url': 'https://iptv-org.github.io/iptv/index.m3u',
      },
    );
    addTearDown(container.dispose);
    await pumpManager(tester, container);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('playlist-source-add-button')))
          .height,
      greaterThanOrEqualTo(48),
    );
    final removeTarget = tester.getSize(find.byTooltip('Remove IPTV.org'));
    expect(removeTarget.width, greaterThanOrEqualTo(48));
    expect(removeTarget.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
    'TV dialog owns focus and CENTER opens the form and selects a preset',
    (tester) async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await pumpTvManagerDialog(tester, container);

      final addButton = find.byKey(
        const ValueKey('playlist-source-add-button'),
      );
      final addFocusable = tester.widget<TvFocusable>(
        find.ancestor(of: addButton, matching: find.byType(TvFocusable)),
      );
      expect(addFocusable.focusNode?.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(find.text('Add playlist'), findsOneWidget);
      final allChannelsChip = find.widgetWithText(ActionChip, 'All channels');
      final presetFocusable = tester.widget<TvFocusable>(
        find.ancestor(of: allChannelsChip, matching: find.byType(TvFocusable)),
      );
      expect(presetFocusable.focusNode?.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      final labelField = tester.widget<TextField>(
        find.byKey(const ValueKey('playlist-source-label-field')),
      );
      final urlField = tester.widget<TextField>(
        find.byKey(const ValueKey('playlist-source-url-field')),
      );
      expect(labelField.controller?.text, 'IPTV.org · All channels');
      expect(
        urlField.controller?.text,
        'https://iptv-org.github.io/iptv/index.m3u',
      );
      final saveButton = find.byKey(
        const ValueKey('playlist-source-save-button'),
      );
      final saveFocusable = tester.widget<TvFocusable>(
        find.ancestor(of: saveButton, matching: find.byType(TvFocusable)),
      );
      expect(saveFocusable.focusNode?.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('TV preset takes save focus back from a stale text field', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpTvManagerDialog(tester, container);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    final labelField = tester.widget<TextField>(
      find.byKey(const ValueKey('playlist-source-label-field')),
    );
    labelField.focusNode?.requestFocus();
    await tester.pump();
    expect(labelField.focusNode?.hasPrimaryFocus, isTrue);

    await tester.tap(find.widgetWithText(ActionChip, 'All channels'));
    await tester.pump(const Duration(milliseconds: 100));
    // Fire OS can restore the field after Flutter's immediate post-frame
    // requests. The delayed preset reassertion must still win.
    labelField.focusNode?.requestFocus();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final saveButton = find.byKey(
      const ValueKey('playlist-source-save-button'),
    );
    final saveFocusable = tester.widget<TvFocusable>(
      find.ancestor(of: saveButton, matching: find.byType(TvFocusable)),
    );
    expect(saveFocusable.focusNode?.hasPrimaryFocus, isTrue);
  });
}
