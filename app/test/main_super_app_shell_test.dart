import 'package:airo_app/main.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('super-app production registry composes Coins, Mind and IPTV', () {
    final registry = buildMainModuleRegistry();

    expect(registry.shell, ShellId.mobile);
    expect(registry.moduleIds, ['coin_vault', 'mind', 'iptv']);
    expect(registry.isRegistered('coin_vault'), isTrue);
    expect(registry.isRegistered('mind'), isTrue);
    expect(registry.isRegistered('iptv'), isTrue);
  });

  test('super-app registry preserves module mount points', () {
    final registry = buildMainModuleRegistry();
    final paths = registry.allRoutes.whereType<GoRoute>().map(
      (route) => route.path,
    );

    expect(paths, [
      'vault',
      '/mind',
      '/wellbeing',
      '/iptv',
      '/iptv/player',
      '/vod',
    ]);
  });

  test('super-app registry keeps the vault prefix aligned with its route', () {
    final registry = buildMainModuleRegistry();
    final container = ProviderContainer(
      overrides: registry.allProviderOverrides,
    );
    addTearDown(container.dispose);

    expect(container.read(vaultRoutePrefixProvider), '/money/vault');
  });

  test(
    'super-app registry initializes without static cross-test state',
    () async {
      final first = buildMainModuleRegistry();
      final second = buildMainModuleRegistry();

      await first.initializeAll();
      await second.initializeAll();

      expect(first.moduleIds, second.moduleIds);
      expect(identical(first, second), isFalse);
    },
  );
}
