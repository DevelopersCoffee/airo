import 'package:airo_app/features/coins/presentation/screens/coins_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../coins_currency_test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows smart-default hint until user picks a currency', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coinsCurrencyProviderTestOverride(prefs)],
        child: const MaterialApp(home: CoinsSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coins settings'), findsOneWidget);
    expect(find.textContaining('smart default'), findsOneWidget);
  });

}
