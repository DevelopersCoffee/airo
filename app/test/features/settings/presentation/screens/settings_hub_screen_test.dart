import 'package:airo_app/core/providers/app_theme_provider.dart';
import 'package:airo_app/features/settings/presentation/screens/settings_hub_screen.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
        ],
        child: const MaterialApp(home: SettingsHubScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders appearance, quick toggles, currency, and navigation '
      'tiles', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Bedtime Mode'), findsOneWidget);
    expect(find.text('Background Audio'), findsOneWidget);
    expect(find.text('Audio Ducking'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Audio Settings'), findsOneWidget);
    expect(find.text('Playback Settings'), findsOneWidget);
    expect(find.text('Playlist Source'), findsOneWidget);
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
  });

  testWidgets('tapping Playlist Source opens the playlist source sheet', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Playlist Source'));
    await tester.pumpAndSettle();

    expect(find.text('Playlist source'), findsOneWidget);
  });

  testWidgets('appearance picker saves selected theme', (tester) async {
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
        ],
        child: const MaterialApp(home: SettingsHubScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Airo Cyber'), findsOneWidget);
    expect(find.text('Airo Classic'), findsOneWidget);

    await tester.tap(find.text('Airo Classic'));
    await tester.pump();

    expect(notifier.state, AppThemeId.classic);
    expect(prefs.getString(AppThemeNotifier.storageKey), 'classic');
  });
}
