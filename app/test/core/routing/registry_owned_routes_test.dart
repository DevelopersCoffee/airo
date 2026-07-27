import 'package:airo_app/core/routing/app_router.dart';
import 'package:airo_app/main.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry-owned named routes preserve mobile deep-link locations', () {
    final router = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
    );
    addTearDown(router.dispose);

    expect(
      router.namedLocation(
        'coin_vault_add',
        pathParameters: {'type': 'creditCard'},
      ),
      '/money/vault/add/creditCard',
    );
    expect(
      router.namedLocation(
        'iptv_player',
        queryParameters: {'channelId': 'news-1'},
      ),
      '/iptv/player?channelId=news-1',
    );
    expect(router.namedLocation('iptv'), '/iptv');
    expect(router.namedLocation('VOD'), '/vod');
  });

  test(
    'super-app router fails before startup when a required module is absent',
    () {
      final emptyRegistry = ModuleRegistry(shell: ShellId.mobile);

      expect(
        () => AppRouter.createRouter(moduleRegistry: emptyRegistry),
        throwsA(
          isA<ModuleCompositionException>().having(
            (error) => error.message,
            'message',
            contains('coin_vault'),
          ),
        ),
      );
    },
  );

  test('super-app router rejects a registry for another shell', () {
    final coinsRegistry = ModuleRegistry(shell: ShellId.coins);

    expect(
      () => AppRouter.createRouter(moduleRegistry: coinsRegistry),
      throwsArgumentError,
    );
  });
}
