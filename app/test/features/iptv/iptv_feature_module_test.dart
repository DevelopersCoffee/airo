import 'package:airo_app/features/iptv/iptv_feature_module.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('IPTV module exposes mobile and TV route tables', () {
    final module = IptvFeatureModule();

    expect(module.id, 'iptv');
    expect(module.supportedShells, {ShellId.mobile, ShellId.tv});

    final mobileRoutes = module.routesFor(ShellId.mobile);
    expect(mobileRoutes.whereType<GoRoute>().map((route) => route.path), [
      '/iptv',
      '/iptv/player',
      '/vod',
    ]);

    final tvRoutes = module.routesFor(ShellId.tv);
    expect(tvRoutes.whereType<GoRoute>().map((route) => route.path), [
      '/iptv',
      '/iptv/player',
    ]);
  });
}
