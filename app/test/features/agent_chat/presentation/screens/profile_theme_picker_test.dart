import 'package:airo_app/core/providers/app_theme_provider.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/profile_screen.dart';
import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import 'package:airo_app/features/settings/application/ai_preferences_settings.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('profile appearance picker saves selected theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppThemeNotifier.withPreferences(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appThemeProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Airo Cyber'), findsOneWidget);
    expect(find.text('Airo Classic'), findsOneWidget);

    await tester.tap(find.text('Airo Classic'));
    await tester.pump();

    expect(notifier.state, AppThemeId.classic);
    expect(prefs.getString(AppThemeNotifier.storageKey), 'classic');
  });

  testWidgets('profile shows AI preferences and persists fallback changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AIPreferencesSettingsNotifier.routingStrategyKey: 'cloudPreferred',
      AIPreferencesSettingsNotifier.autoFallbackKey: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppThemeNotifier.withPreferences(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeProvider.overrideWith((ref) => notifier),
          sharedPreferencesProvider.overrideWithValue(prefs),
          aiModelStorageUsageBytesProvider.overrideWith((ref) async {
            return 512 * 1024 * 1024;
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Model Preferences'), findsOneWidget);
    final subtitle = tester.widget<Text>(
      find.byKey(const Key('ai-routing-strategy-subtitle')),
    );
    expect(subtitle.data, 'Cloud preferred');
    expect(find.text('512.0 MB used'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('ai-auto-fallback-switch')),
    );
    await tester.tap(find.byKey(const Key('ai-auto-fallback-switch')));
    await tester.pumpAndSettle();

    expect(
      prefs.getBool(AIPreferencesSettingsNotifier.autoFallbackKey),
      isTrue,
    );
  });
}
