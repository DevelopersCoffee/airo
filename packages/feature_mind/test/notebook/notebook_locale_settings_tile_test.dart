import 'package:feature_mind/src/notebook/presentation/notebook_locale_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('defaults to English and persists Hindi', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: NotebookLocaleSettingsTile())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notebook_locale_settings_tile')),
      findsOneWidget,
    );
    expect(find.text('English'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('notebook_locale_settings_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi · हिन्दी').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mind_notebook_ui_locale'), 'hi');
  });
}
