import 'package:airo_app/features/settings/presentation/tv/tv_source_management_section.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
    );
  }

  testWidgets('shows empty state when nothing is configured', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TvSourceManagementSection()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No sources configured'), findsOneWidget);
  });

  testWidgets('adding an M3U source shows it in the list', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TvSourceManagementSection()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Add M3U Source'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Label'),
      'My Playlist',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Playlist URL'),
      'https://example.com/playlist.m3u',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('My Playlist'), findsOneWidget);
  });

  testWidgets('removing a source requires confirmation', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(
      addM3uContentSourceProvider((
        label: 'My Playlist',
        url: 'https://example.com/playlist.m3u',
      )).future,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TvSourceManagementSection()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    // Confirmation dialog shown, source not yet removed.
    expect(find.text('My Playlist'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump();

    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources, isEmpty);
  });

  testWidgets(
    'shows a validation error and does not persist when the URL is empty',
    (tester) async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TvSourceManagementSection()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Add M3U Source'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Label'),
        'My Playlist',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Enter a playlist URL.'), findsOneWidget);

      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );
      expect(sources, isEmpty);
    },
  );

  testWidgets(
    'shows a validation error and does not persist when the URL is malformed',
    (tester) async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TvSourceManagementSection()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Add M3U Source'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Label'),
        'My Playlist',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist URL'),
        'not-a-url',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(
        find.text('Enter a valid http:// or https:// URL.'),
        findsOneWidget,
      );

      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );
      expect(sources, isEmpty);
    },
  );
}
