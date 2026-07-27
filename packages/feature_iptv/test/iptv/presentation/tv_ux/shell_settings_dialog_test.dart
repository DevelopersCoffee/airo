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

    await tester.tap(find.byKey(const ValueKey('airo-tv-row-toggle-stats')));
    await tester.pump();

    expect(
      container
          .read(controlRowVisibilityProvider)
          .isVisible(AiroTvControlRow.stats),
      isFalse,
    );
    expect(preferences.getBool('iptv_row_stats_visible'), isFalse);
    expect(
      find.byKey(const ValueKey('airo-tv-shell-settings-done')),
      findsOneWidget,
    );
  });
}
