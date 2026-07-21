// ignore_for_file: depend_on_referenced_packages

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

void main() {
  VaultKeyManager keyManager({
    bool authenticate = true,
    bool available = true,
  }) => VaultKeyManager.forTesting(
    secureStorage: InMemorySecureStorage(),
    authenticate: () async => authenticate,
    isAvailable: () async => available,
  );

  Widget harness(Widget child, VaultKeyManager keyManager) => ProviderScope(
    overrides: [vaultKeyManagerProvider.overrideWithValue(keyManager)],
    child: MaterialApp(home: child),
  );

  testWidgets('lock screen offers a biometric unlock button', (tester) async {
    await tester.pumpWidget(harness(const VaultLockScreen(), keyManager()));

    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsOneWidget);

    await tester.tap(find.text('Unlock with biometrics'));
    await tester.pumpAndSettle();
  });

  testWidgets('failed unlock from the lock screen lands on auth error', (
    tester,
  ) async {
    final manager = keyManager(authenticate: false);
    final container = ProviderContainer(
      overrides: [vaultKeyManagerProvider.overrideWithValue(manager)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultLockScreen()),
      ),
    );
    await tester.tap(find.text('Unlock with biometrics'));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultAuthError>());
  });

  testWidgets('unavailable view explains biometrics are required', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const VaultUnavailableView(), keyManager()),
    );

    expect(find.text('Biometrics required'), findsOneWidget);
    expect(find.textContaining('system settings'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsNothing);
  });

  testWidgets('auth error view shows the failure and retries', (tester) async {
    final manager = keyManager(available: false);
    final container = ProviderContainer(
      overrides: [vaultKeyManagerProvider.overrideWithValue(manager)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultAuthErrorView(
            failure: AuthFailure(message: 'Biometric authentication failed'),
          ),
        ),
      ),
    );

    expect(find.text('Biometric authentication failed'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultUnavailable>());
  });
}
