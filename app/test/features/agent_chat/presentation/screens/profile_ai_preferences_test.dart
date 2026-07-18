import 'package:airo_app/core/providers/app_theme_provider.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/profile_screen.dart';
import 'package:airo_app/features/settings/application/ai_storage_dashboard.dart';
import 'package:feature_iptv/feature_iptv.dart';
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
          aiStorageDashboardProvider.overrideWith((ref) async {
            return const AIStorageDashboardSummary(
              categories: [
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.installedModels,
                  label: 'Installed models',
                  bytes: 512 * 1024 * 1024,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.meetingStorage,
                  label: 'Meeting storage',
                  bytes: 0,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.embeddingStorage,
                  label: 'Embedding storage',
                  bytes: 0,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.databaseSize,
                  label: 'Database size',
                  bytes: 0,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.audioCache,
                  label: 'Audio cache',
                  bytes: 0,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.availableSpace,
                  label: 'Available space',
                  bytes: 2 * 1024 * 1024 * 1024,
                ),
              ],
            );
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

  testWidgets('profile storage dashboard shows all local storage categories', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppThemeNotifier.withPreferences(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeProvider.overrideWith((ref) => notifier),
          sharedPreferencesProvider.overrideWithValue(prefs),
          aiStorageDashboardProvider.overrideWith((ref) async {
            return const AIStorageDashboardSummary(
              categories: [
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.installedModels,
                  label: 'Installed models',
                  bytes: 512 * 1024 * 1024,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.meetingStorage,
                  label: 'Meeting storage',
                  bytes: 24 * 1024 * 1024,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.embeddingStorage,
                  label: 'Embedding storage',
                  bytes: 4 * 1024 * 1024,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.databaseSize,
                  label: 'Database size',
                  bytes: 8 * 1024 * 1024,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.audioCache,
                  label: 'Audio cache',
                  bytes: 16 * 1024 * 1024,
                ),
                AIStorageDashboardCategory(
                  kind: AIStorageCategoryKind.availableSpace,
                  label: 'Available space',
                  bytes: 2 * 1024 * 1024 * 1024,
                ),
              ],
            );
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Storage'));
    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();

    expect(find.text('Installed models'), findsOneWidget);
    expect(find.text('Meeting storage'), findsOneWidget);
    expect(find.text('Embedding storage'), findsOneWidget);
    expect(find.text('Database size'), findsOneWidget);
    expect(find.text('Audio cache'), findsOneWidget);
    expect(find.text('Available space'), findsOneWidget);
    expect(find.text('512.0 MB'), findsOneWidget);
    expect(find.text('2.0 GB'), findsOneWidget);
  });
}
