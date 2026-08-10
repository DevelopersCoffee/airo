import 'package:core_app_shell/core_app_shell.dart';
import 'package:airo_app/features/settings/presentation/screens/settings_hub_screen.dart';
import 'package:core_data/core_data.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channels = [
    IPTVChannel(
      id: 'india-news',
      name: 'India News',
      streamUrl: 'https://example.test/india.m3u8',
      country: 'IN',
      languages: ['en'],
    ),
    IPTVChannel(
      id: 'italia-tv',
      name: 'Italia TV',
      streamUrl: 'https://example.test/italy.m3u8',
      country: 'IT',
      languages: ['it'],
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          iptvChannelsProvider.overrideWith((ref) async => channels),
        ],
        child: const MaterialApp(home: SettingsHubScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders appearance, back button, and real navigation tiles', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('IPTV'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Choose your visual theme'), findsOneWidget);
    expect(find.text('Airo Cyber'), findsNothing);
    expect(find.text('Airo Classic'), findsNothing);
    expect(find.text('Bedtime Mode'), findsNothing);
    expect(find.text('Background Audio'), findsNothing);
    expect(find.text('Audio Ducking'), findsNothing);
    expect(find.text('Currency'), findsNothing);
    expect(find.text('Audio Settings'), findsOneWidget);
    expect(find.text('Playback Settings'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Choose your default channel country'), findsOneWidget);
    expect(find.text('Playlist Source'), findsOneWidget);
    expect(find.text('EPG Guide Source'), findsOneWidget);
    expect(find.text('Picture-in-picture'), findsNothing);
    expect(find.text('More Airo Apps'), findsOneWidget);
    expect(find.text('Airo TV'), findsOneWidget);
    expect(find.text('Airo Coins'), findsOneWidget);
    expect(find.text('Airo Mind'), findsOneWidget);
    expect(find.text('Airo'), findsNothing);
  });

  testWidgets('a non-default shellId excludes itself, not mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          iptvChannelsProvider.overrideWith((ref) async => channels),
        ],
        child: const MaterialApp(home: SettingsHubScreen(shellId: ShellId.tv)),
      ),
    );
    await tester.pump();

    expect(find.text('Airo'), findsOneWidget);
    expect(find.text('Airo TV'), findsNothing);
  });

  testWidgets('country settings picker updates the global country filter', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇮🇹 Italy'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('🇮🇹 Italy'));
    final container = ProviderScope.containerOf(context);
    expect(container.read(channelFiltersProvider).country, 'IT');
    expect(
      container
          .read(channelCountryPromptProvider)
          .maybeWhen(data: (value) => value, orElse: () => null),
      isTrue,
    );
  });

  testWidgets('tapping Audio Settings pushes the audio settings screen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Audio Settings'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Audio Settings'), findsOneWidget);
  });

  testWidgets('tapping Playback Settings pushes the playback settings '
      'screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Playback Settings'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Playback Settings'), findsOneWidget);
    expect(find.text('Picture-in-picture'), findsOneWidget);
  });

  testWidgets('playback settings PiP toggle persists from the phone hub', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Playback Settings'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Picture-in-picture'));
    final container = ProviderScope.containerOf(context);
    expect(container.read(pictureInPicturePreferenceProvider), isTrue);

    await tester.tap(find.text('Picture-in-picture'));
    await tester.pump();

    expect(container.read(pictureInPicturePreferenceProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(PictureInPicturePreferenceNotifier.storageKey),
      isFalse,
    );
  });

  testWidgets('tapping Playlist Source opens the playlist source sheet', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Playlist Source'));
    await tester.pumpAndSettle();

    // Sentence case since c2ada89f replaced the sheet with
    // PlaylistSourceManagerSheet; the button label is the sheet's marker.
    expect(find.text('Add playlist source'), findsOneWidget);
  });

  testWidgets('tapping EPG Guide Source opens the XMLTV source sheet', (
    tester,
  ) async {
    // rc.3 phone parity fix: the Guide banner tells users to add an XMLTV
    // source "in Settings", but the phone settings hub had no entry point
    // for it (only the TV variant composed XmltvSourceSheet).
    await pumpScreen(tester);

    await tester.tap(find.text('EPG Guide Source'));
    await tester.pumpAndSettle();

    expect(find.text('XMLTV Guide Source'), findsOneWidget);
  });

  testWidgets('appearance section opens theme picker and saves selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefs = await SharedPreferences.getInstance();
    final notifier = AppThemeNotifier.withPreferences(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeProvider.overrideWith((ref) => notifier),
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          iptvChannelsProvider.overrideWith((ref) async => channels),
        ],
        child: const MaterialApp(home: SettingsHubScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Airo Cyber'), findsNothing);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Theme'), findsOneWidget);
    for (final theme in AiroTheme.themes) {
      expect(find.text(theme.name), findsOneWidget);
      expect(find.text(theme.description), findsOneWidget);
    }

    await tester.tap(find.text('Airo Classic'));
    await tester.pump();

    expect(notifier.state, AppThemeId.classic);
    expect(prefs.getString(AppThemeNotifier.storageKey), 'classic');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Airo Classic'), findsNothing);
  });
}
