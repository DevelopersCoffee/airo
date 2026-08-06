import 'package:core_app_shell/core_app_shell.dart';
import 'package:airo_app/features/settings/application/ai_storage_dashboard.dart';
import 'package:airo_app/features/settings/presentation/widgets/ai_preferences_section.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:airo_app/features/settings/application/ai_preferences_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('section shows AI preferences and persists fallback changes', (
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
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AIPreferencesSection()),
          ),
        ),
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

  testWidgets('storage dashboard shows all local storage categories', (
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
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AIPreferencesSection()),
          ),
        ),
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

  testWidgets('section saves an OpenAI-compatible remote model server', (
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
            return const AIStorageDashboardSummary(categories: []);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AIPreferencesSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('ai-remote-server-section')),
    );
    await tester.tap(find.byKey(const Key('ai-remote-server-section')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-remote-server-url')),
      'http://127.0.0.1:11434/v1',
    );
    await tester.enterText(
      find.byKey(const Key('ai-remote-server-model')),
      'qwen2.5:7b',
    );
    await tester.ensureVisible(find.text('Save server'));
    await tester.tap(find.text('Save server'));
    await tester.pumpAndSettle();

    expect(
      prefs.getString(AIPreferencesSettingsNotifier.remoteServerUrlKey),
      'http://127.0.0.1:11434/v1',
    );
    expect(
      prefs.getString(AIPreferencesSettingsNotifier.remoteServerModelKey),
      'qwen2.5:7b',
    );
    expect(find.text('Remote model server saved.'), findsOneWidget);
  });

  testWidgets('section shows persistent remote server diagnostics', (
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
            return const AIStorageDashboardSummary(categories: []);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AIPreferencesSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('ai-remote-server-section')),
    );
    await tester.tap(find.byKey(const Key('ai-remote-server-section')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-remote-server-url')),
      'http://127.0.0.1:11434',
    );
    await tester.enterText(
      find.byKey(const Key('ai-remote-server-model')),
      'qwen2.5:7b',
    );
    await tester.ensureVisible(find.byKey(const Key('ai-remote-server-test')));
    await tester.tap(find.byKey(const Key('ai-remote-server-test')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-remote-server-diagnostics')), findsOne);
    expect(find.text('Remote diagnostics: Needs attention'), findsOneWidget);
    expect(find.text('Endpoint: http://127.0.0.1:11434/v1'), findsOneWidget);
    expect(find.text('Requested model: qwen2.5:7b'), findsOneWidget);
    expect(find.text('Models reported: 0'), findsOneWidget);
    expect(
      find.text(
        'Next step: Confirm the server is running and reachable from this device.',
      ),
      findsOneWidget,
    );
  });
}
