// ignore_for_file: depend_on_referenced_packages

import 'package:airo_app/core/routing/app_router.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GoRouter> pumpVaultRoute(
    WidgetTester tester,
    String initialLocation,
  ) async {
    SharedPreferences.setMockInitialValues({'is_logged_in': true});
    final router = AppRouter.createRouter(initialLocation: initialLocation);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenSecurityProvider.overrideWithValue(
            VaultScreenSecurity(
              enableProtection: () async {},
              disableProtection: () async {},
            ),
          ),
          vaultKeyManagerProvider.overrideWithValue(
            VaultKeyManager.forTesting(
              secureStorage: InMemorySecureStorage(),
              authenticate: () async => true,
              isAvailable: () async => true,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    return router;
  }

  testWidgets('vault add route opens the selected record form', (tester) async {
    final router = await pumpVaultRoute(tester, '/money/vault/add/creditCard');

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/money/vault/add/creditCard',
    );
    expect(find.text('Add Card (masked)'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nickname *'), findsOneWidget);
  });

  testWidgets('vault edit route passes malformed PAN keys fail-closed', (
    tester,
  ) async {
    final router = await pumpVaultRoute(
      tester,
      '/money/vault/edit/panCard/not-a-number',
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/money/vault/edit/panCard/not-a-number',
    );
    expect(find.text('Edit PAN card'), findsOneWidget);
    expect(find.text('Invalid PAN record key'), findsOneWidget);
  });
}
