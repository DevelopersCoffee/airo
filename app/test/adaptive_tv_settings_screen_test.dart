import 'package:airo_app/core/app/tv_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_iptv/feature_iptv.dart';

void main() {
  Widget wrap(Size size) {
    SharedPreferences.setMockInitialValues({});
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(home: SizedBox());
        }
        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: const AdaptiveTvSettingsScreen(),
            ),
          ),
        );
      },
    );
  }

  testWidgets('phone-sized layout shows the settings hub with theme picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const Size(400, 850)));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Airo Classic'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is RadioListTile),
      findsWidgets,
      reason: 'theme options must be selectable on phones',
    );
  });

  testWidgets('TV-sized layout keeps the two-pane TV settings screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const Size(1280, 720)));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNothing);
    expect(
      find.byKey(const ValueKey('tv_settings_section_theme')),
      findsOneWidget,
    );
  });
}
