import 'package:airo_app/features/settings/presentation/tv/tv_source_management_section.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:platform_playlist/platform_playlist.dart';
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

    await tester.tap(find.text('Add Source'));
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

  testWidgets('adding an Xtream source persists credentials', (tester) async {
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

    await tester.tap(find.text('Add Source'));
    await tester.pump();

    // Pick Xtream from the kind picker.
    await tester.tap(find.byKey(const Key('source-kind-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xtream Codes').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Label'),
      'My Xtream',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Server URL'),
      'https://xtream.example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'user1');
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('My Xtream'), findsOneWidget);

    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources.single.kind, ContentSourceKind.xtream);
    final credential = await container
        .read(contentSourceCredentialStoreProvider)
        .read(ContentSourceCredentialRef(sources.single.id));
    expect(credential?.username, 'user1');
    expect(credential?.password, 'secret');
  });

  testWidgets('adding a Stalker source persists the MAC address', (
    tester,
  ) async {
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

    await tester.tap(find.text('Add Source'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('source-kind-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stalker Portal').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Portal');
    await tester.enterText(
      find.widgetWithText(TextField, 'Portal URL'),
      'https://stalker.example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'MAC Address'),
      'AA:BB:CC:DD:EE:FF',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources.single.kind, ContentSourceKind.stalker);
    expect(sources.single.macAddress, 'AA:BB:CC:DD:EE:FF');
  });

  testWidgets('source list shows capability flags per source', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(
      addXtreamContentSourceProvider((
        label: 'Xtream',
        url: 'https://xtream.example.com',
        username: 'u',
        password: 'p',
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

    // Xtream advertises EPG + VOD + catch-up capabilities.
    expect(find.text('EPG'), findsOneWidget);
    expect(find.text('VOD'), findsOneWidget);
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

  testWidgets('cancelling the confirmation dialog keeps the source', (
    tester,
  ) async {
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
    expect(find.text('Cancel'), findsWidgets);

    await tester.tap(find.text('Cancel').last);
    await tester.pump();
    await tester.pump();

    // Source is still present in the list and in the underlying provider.
    expect(find.text('My Playlist'), findsOneWidget);
    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources, hasLength(1));
    expect(sources.single.label, 'My Playlist');
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

      await tester.tap(find.text('Add Source'));
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

      await tester.tap(find.text('Add Source'));
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
