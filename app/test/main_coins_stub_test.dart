import 'package:airo_app/main_coins.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coinsModuleRegistry is scoped to ShellId.coins with no modules '
      'registered', () {
    expect(coinsShellId, ShellId.coins);
    expect(coinsModuleRegistry.shell, ShellId.coins);
    expect(coinsModuleRegistry.moduleCount, 0);
    expect(coinsModuleRegistry.allRoutes, isEmpty);
  });

  testWidgets('AiroCoinsStubApp renders a placeholder with no legacy coins '
      'UI wired in', (tester) async {
    await tester.pumpWidget(const AiroCoinsStubApp());

    expect(find.byKey(const Key('airo-coins-stub')), findsOneWidget);
    expect(find.text('Airo Coins — coming soon'), findsOneWidget);
  });
}
