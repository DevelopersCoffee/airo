import 'package:airo_app/features/coins/application/providers/coins_currency_provider.dart';
import 'package:airo_app/features/coins/presentation/screens/nfc_quick_expense_capture_screen.dart';
import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../coins_currency_test_overrides.dart';
import '../support/vault_test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'shows validation error for invalid amounts when vault is unlocked',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coinsCurrencyProviderTestOverride(prefs),
            coinsCurrencyFormatterProvider.overrideWithValue(
              CurrencyFormatter.fromCode('USD'),
            ),
            vaultSessionProvider.overrideWith(TestVaultSessionNotifier.new),
          ],
          child: const MaterialApp(home: NfcQuickExpenseCaptureScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('How much did you spend?'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount'), findsOneWidget);
    },
  );

  testWidgets('shows unlock placeholder while the vault is locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinsCurrencyProviderTestOverride(prefs),
          vaultSessionProvider.overrideWith(_LockedVaultSessionNotifier.new),
        ],
        child: const MaterialApp(home: NfcQuickExpenseCaptureScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Quick capture'), findsOneWidget);
    expect(find.text('Unlocking'), findsWidgets);
  });
}

class _LockedVaultSessionNotifier extends VaultSessionNotifier {
  @override
  VaultSessionState build() => const VaultLocked();
}
