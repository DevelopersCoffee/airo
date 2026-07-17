import 'package:airo_app/core/providers/app_theme_provider.dart';
import 'package:airo_app/features/settings/presentation/tv/tv_theme_section.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('lists all four theme names', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: TvThemeSection())),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (final id in AppThemeId.values) {
      expect(find.text(AppTheme.byId(id).name), findsOneWidget);
    }
  });

  testWidgets('selecting a theme persists it via appThemeProvider', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppThemeNotifier.withPreferences(prefs);
    final container = ProviderContainer(
      overrides: [appThemeProvider.overrideWith((ref) => notifier)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvThemeSection())),
      ),
    );
    await tester.pump();
    await tester.pump();

    final targetId = AppThemeId.values.firstWhere(
      (id) => id != container.read(appThemeProvider),
    );
    await tester.tap(find.text(AppTheme.byId(targetId).name));
    await tester.pump();

    expect(container.read(appThemeProvider), targetId);
    expect(prefs.getString(AppThemeNotifier.storageKey), targetId.storageValue);
  });
}
