import 'package:feature_iptv/application/providers/control_row_visibility_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/shell_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('toggles rows and closes with Done', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AiroTvShellSettingsDialog()),
        ),
      ),
    );

    // 'filter' rather than 'stats': stats now defaults hidden
    // (#compact-tv-chrome), which is exactly what a separate test already
    // covers — this test only needs a row that starts visible, to check
    // that toggling it off works and persists.
    await tester.tap(find.byKey(const ValueKey('airo-tv-row-toggle-filter')));
    await tester.pump();

    expect(
      container
          .read(controlRowVisibilityProvider)
          .isVisible(AiroTvControlRow.filter),
      isFalse,
    );
    expect(preferences.getBool('iptv_row_filter_visible'), isFalse);
    expect(
      find.byKey(const ValueKey('airo-tv-shell-settings-done')),
      findsOneWidget,
    );
  });

  Future<Widget> wrap(Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('no Channel row exists in the dialog', (tester) async {
    await tester.pumpWidget(await wrap(const AiroTvShellSettingsDialog()));
    expect(find.text('Channel'), findsNothing);
  });

  testWidgets(
    'Playlist source row is hidden when onPlaylistSourceTap is null',
    (tester) async {
      await tester.pumpWidget(await wrap(const AiroTvShellSettingsDialog()));
      expect(find.text('Playlist source'), findsNothing);
    },
  );

  testWidgets(
    'Playlist source row appears and calls onPlaylistSourceTap when provided',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        await wrap(
          AiroTvShellSettingsDialog(onPlaylistSourceTap: () => tapped = true),
        ),
      );
      expect(find.text('Playlist source'), findsOneWidget);
      await tester.tap(find.text('Playlist source'));
      await tester.pump();
      expect(tapped, isTrue);
    },
  );

  testWidgets('Guide URL row is hidden when onGuideSourceTap is null', (
    tester,
  ) async {
    await tester.pumpWidget(await wrap(const AiroTvShellSettingsDialog()));
    expect(find.text('Guide URL'), findsNothing);
  });

  testWidgets(
    'Guide URL row appears and calls onGuideSourceTap when provided',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        await wrap(
          AiroTvShellSettingsDialog(onGuideSourceTap: () => tapped = true),
        ),
      );
      expect(find.text('Guide URL'), findsOneWidget);
      await tester.tap(find.text('Guide URL'));
      await tester.pump();
      expect(tapped, isTrue);
    },
  );
}
