import 'dart:io';

import 'package:airo_app/core/coins/coins_standalone_groups_list_screen.dart';
import 'package:airo_app/core/coins/coins_standalone_home.dart';
import 'package:airo_app/core/coins/coins_standalone_identity.dart';
import 'package:airo_app/features/coins/application/providers/coins_identity_provider.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/domain/entities/group.dart';
import 'package:airo_app/main_coins.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(manifest, contains('android.nfc.action.NDEF_DISCOVERED'));
    expect(manifest, contains('android:path="/quick-capture"'));
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

    final container = ProviderContainer(
      overrides: module.providerOverridesFor(ShellId.coins),
    );
    addTearDown(container.dispose);
    expect(container.read(vaultRoutePrefixProvider), '/vault');
  });

  test('vault route prefix defaults to the super-app mount point', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(vaultRoutePrefixProvider), '/money/vault');
  });

  test('vault module ships to mobile and coins shells but never TV', () {
    final module = CoinVaultModule();

    expect(module.isEnabledForShell(ShellId.coins), isTrue);
    expect(module.isEnabledForShell(ShellId.mobile), isTrue);
    expect(module.isEnabledForShell(ShellId.tv), isFalse);
    expect(module.isEnabledForShell(const ShellId('watch')), isFalse);
  });

  test('coins shell uses a local-only identity override', () {
    final container = ProviderContainer(
      overrides: [
        coinsIdentityProvider.overrideWithValue(const LocalCoinsIdentity()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(coinsIdentityProvider).current, isNull);
  });

  testWidgets('coins shell boots into the splits and vault hub', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenSecurityProvider.overrideWithValue(_FakeScreenSecurity()),
        ],
        child: AiroCoinsApp(registry: buildCoinsModuleRegistry(), prefs: prefs),
      ),
    );
    await tester.pump();

    expect(find.byType(CoinsStandaloneHome), findsOneWidget);
    expect(find.text('Shared expenses'), findsOneWidget);
    expect(find.text('Secure vault'), findsOneWidget);
    expect(
      find.text('Groups, balances, and settle-up — works offline.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Bank accounts, cards, insurance, and tax documents — encrypted on device.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'hub opens standalone groups list when splits storage is available',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenSecurityProvider.overrideWithValue(_FakeScreenSecurity()),
            allGroupsProvider.overrideWith(
              (ref) => Stream<List<Group>>.value(const []),
            ),
          ],
          child: AiroCoinsApp(registry: buildCoinsModuleRegistry()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Shared expenses'));
      await tester.pumpAndSettle();

      expect(find.byType(CoinsStandaloneGroupsListScreen), findsOneWidget);
    },
  );
}
