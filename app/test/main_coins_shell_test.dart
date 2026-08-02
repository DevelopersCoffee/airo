import 'dart:io';

import 'package:airo_app/core/coins/coins_standalone_home.dart';
import 'package:airo_app/features/coins/application/providers/expense_providers.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
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
  test('Coins Android manifest removes the base MainActivity launcher', () {
    final manifest = File(
      'android/app/src/coins/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('xmlns:tools='));
    expect(
      manifest,
      contains(
        RegExp(r'android:name="\.MainActivity"[\s\S]*?tools:node="remove"'),
      ),
    );
    expect(manifest, contains('android:name=".CoinsActivity"'));
  });

  test('coins registry registers the vault module for ShellId.coins', () {
    final registry = buildCoinsModuleRegistry();

    expect(registry.shell, ShellId.coins);
    expect(registry.moduleIds, ['coin_vault']);
    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/money/vault'));
  });

  test('vault module mounts routes and route-prefix override at basePath', () {
    final module = CoinVaultModule(basePath: '/vault');

    final paths = module
        .routesFor(ShellId.coins)
        .whereType<GoRoute>()
        .map((r) => r.path);
    expect(paths, contains('/vault'));

    // The module keeps feature_coin's internal add/edit navigation in sync
    // with the mount point by overriding vaultRoutePrefixProvider.
    final container = ProviderContainer(
      overrides: module.providerOverridesFor(ShellId.coins),
    );
    addTearDown(container.dispose);
    expect(container.read(vaultRoutePrefixProvider), '/vault');
  });

  test('vault route prefix defaults to the super-app mount point', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The super-app registers no override, so feature_coin's default must
    // stay its historical /money/vault mount (no-break rule).
    expect(container.read(vaultRoutePrefixProvider), '/money/vault');
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

  testWidgets('coins shell boots into the lean money summary home', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenSecurityProvider.overrideWithValue(_FakeScreenSecurity()),
          // Resolve the read path with an empty list so the boot test never
          // touches the native Drift database.
          recentExpensesProvider.overrideWith(
            (ref) => Future<List<Transaction>>.value(const []),
          ),
        ],
        child: AiroCoinsApp(registry: buildCoinsModuleRegistry()),
      ),
    );
    await tester.pump();

    expect(find.byType(CoinsStandaloneHome), findsOneWidget);
  });
}
