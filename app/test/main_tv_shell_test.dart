import 'package:airo_app/features/iptv/iptv_feature_module.dart';
import 'package:airo_app/main_tv.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('TV production registry contains IPTV only', () {
    final registry = buildTvModuleRegistry();

    expect(registry.shell, ShellId.tv);
    expect(registry.moduleIds, ['iptv']);
    expect(registry.isRegistered('coin_vault'), isFalse);
  });

  test('IPTV module preserves stable routes for mobile and TV shells', () {
    final module = IptvFeatureModule();

    expect(module.isEnabledForShell(ShellId.mobile), isTrue);
    expect(module.isEnabledForShell(ShellId.tv), isTrue);
    expect(module.isEnabledForShell(ShellId.coins), isFalse);

    for (final shell in [ShellId.mobile, ShellId.tv]) {
      final routes = module.routesFor(shell).whereType<GoRoute>().toList();
      expect(routes.map((route) => (route.path, route.name)), [
        ('/iptv', 'iptv'),
        ('/iptv/player', 'iptv_player'),
      ]);
    }
  });

  test('TV deferred initialization uses the supplied registry', () async {
    final registry = buildTvModuleRegistry();
    final logs = <String>[];
    late void Function(Duration) callback;

    scheduleTvFeatureInitialization(
      moduleRegistry: registry,
      addPostFrameCallback: (scheduled) => callback = scheduled,
      log: logs.add,
    );
    callback(Duration.zero);
    await pumpEventQueue();

    expect(logs, contains('📦 Initialized features: iptv'));
  });
}
