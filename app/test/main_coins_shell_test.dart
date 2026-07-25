import 'package:airo_app/core/coins/coin_vault_module.dart';
import 'package:airo_app/main_coins.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeScreenSecurity extends VaultScreenSecurity {
  _FakeScreenSecurity()
    : super(enableProtection: () async {}, disableProtection: () async {});

  @override
  Future<void> protect() async {}

  @override
  Future<void> unprotect() async {}
}

void main() {
  test('coins registry registers the vault module for ShellId.coins', () {
    final registry = buildCoinsModuleRegistry();

    expect(registry.shell, ShellId.coins);
    expect(registry.moduleIds, ['coin_vault']);
    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/money/vault'));
  });

  test('vault module ships to mobile and coins shells but never TV', () {
    final module = CoinVaultModule();

    expect(module.isEnabledForShell(ShellId.coins), isTrue);
    expect(module.isEnabledForShell(ShellId.mobile), isTrue);
    // packages/feature_coin/module.yaml ship policy: tv "Never Ship".
    expect(module.isEnabledForShell(ShellId.tv), isFalse);
    // Contract stays shell-count-agnostic: unknown shells default to off.
    expect(module.isEnabledForShell(const ShellId('watch')), isFalse);
  });

  testWidgets('coins shell boots into the vault gate from registry routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenSecurityProvider.overrideWithValue(_FakeScreenSecurity()),
        ],
        child: AiroCoinsApp(registry: buildCoinsModuleRegistry()),
      ),
    );
    await tester.pump();

    expect(find.byType(VaultGateScreen), findsOneWidget);
  });
}
