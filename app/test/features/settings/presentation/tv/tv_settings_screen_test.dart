import 'package:airo_app/features/settings/presentation/tv/tv_settings_screen.dart';
import 'package:airo_app/features/settings/presentation/widgets/app_info_tile.dart';
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

  Future<void> pumpScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ],
        child: const MaterialApp(home: TvSettingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'renders every section name and shows Theme selected by default',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Playback'), findsOneWidget);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);

      // Accessibility was a rail stop whose detail pane only ever said
      // "Coming soon". On a D-pad rail that is a focus stop leading nowhere,
      // so the entry is gone rather than parked.
      expect(find.text('Accessibility'), findsNothing);

      expect(
        find.byKey(const ValueKey('tv_settings_section_theme')),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping a section name switches the detail pane', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Sources'));
    await tester.pump();

    // With Tasks 4-6's real content not yet built, this task's own stub
    // panes are distinguishable by a key — adjust this assertion once the
    // real Sources section widget exists in Task 6 (its own test covers
    // the real content; this test only proves the shell's navigation).
    expect(
      find.byKey(const ValueKey('tv_settings_section_sources')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv_settings_section_theme')),
      findsNothing,
    );
  });

  testWidgets('resolves the Sources pane through the composition provider', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          tvSourceManagementSectionBuilderProvider.overrideWithValue(
            ({key}) => SizedBox(
              key: key,
              child: const Text('Product source management'),
            ),
          ),
        ],
        child: const MaterialApp(home: TvSettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sources'));
    await tester.pump();

    expect(find.text('Product source management'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv_settings_section_sources')),
      findsOneWidget,
    );
    expect(find.byType(TvSourceManagementSection), findsNothing);
  });

  testWidgets(
    'the cross-app rail entry shows build info, not unpublished apps',
    (tester) async {
      await pumpScreen(tester);

      // No sibling listing is live yet (every `isPublished*` flag in
      // `siblingApps` is still a placeholder), so promoting them would mean
      // three inert "Coming soon" cards under a "More Airo Apps" heading.
      // The entry keeps its other job — the build-version tile support
      // triages against — and is named for what it actually shows.
      expect(find.text('More Airo Apps'), findsNothing);

      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.text('Airo Coins'), findsNothing);
      expect(find.text('Airo Mind'), findsNothing);
      expect(find.text('Airo TV'), findsNothing);
      // AppInfoTile renders empty until its platform channel answers, which
      // it never does under flutter_test — assert it is mounted, and let
      // app/test/core/tv_stub_version_test.dart pin the value it shows.
      expect(
        find.byKey(const ValueKey('tv_settings_section_airo_apps')),
        findsOneWidget,
      );
      expect(find.byType(AppInfoTile), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tv_settings_section_theme')),
        findsNothing,
      );
    },
  );
}
