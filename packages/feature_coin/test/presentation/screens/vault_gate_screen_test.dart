// ignore_for_file: depend_on_referenced_packages

import 'package:core_data/core_data.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

class FakeScreenSecurity extends VaultScreenSecurity {
  FakeScreenSecurity()
    : super(enableProtection: () async {}, disableProtection: () async {});

  var protects = 0;
  var unprotects = 0;

  @override
  Future<void> protect() async => protects++;

  @override
  Future<void> unprotect() async => unprotects++;
}

void main() {
  testWidgets('locked vault stays browsable behind screen protection', (
    tester,
  ) async {
    final security = FakeScreenSecurity();
    final container = ProviderContainer(
      overrides: [screenSecurityProvider.overrideWithValue(security)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultGateScreen(
            unlockedChild: Text('vault-body', key: ValueKey('vault-body')),
          ),
        ),
      ),
    );
    await tester.pump();

    // Progressive auth: browsing is allowed while locked, with an explicit
    // unlock affordance — no full-screen wall.
    expect(find.byKey(const ValueKey('vault-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('vault_unlock_button')), findsOneWidget);
    expect(find.textContaining('Locked.'), findsOneWidget);
    // FLAG_SECURE must still be applied the moment the vault opens, even
    // though nothing sensitive is on screen yet.
    expect(security.protects, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(security.unprotects, 1);
  });

  testWidgets('does not prompt for biometrics on open by default', (
    tester,
  ) async {
    var authCalls = 0;
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemorySecureStorage(),
      authenticate: () async {
        authCalls++;
        return true;
      },
      isAvailable: () async => true,
    );
    final container = ProviderContainer(
      overrides: [
        screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
        vaultKeyManagerProvider.overrideWithValue(keyManager),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultGateScreen()),
      ),
    );
    // Bounded pumps, not pumpAndSettle: the browsable vault body shows a
    // loading indicator that animates indefinitely without a database.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The whole point of progressive auth: opening the vault must not
    // demand a fingerprint before the user has asked for anything private.
    expect(authCalls, 0);
  });

  testWidgets('a prior auth failure still leaves the vault browsable', (
    tester,
  ) async {
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemorySecureStorage(),
      authenticate: () async => false,
      isAvailable: () async => true,
    );
    final container = ProviderContainer(
      overrides: [
        screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
        vaultKeyManagerProvider.overrideWithValue(keyManager),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultGateScreen(
            autoUnlock: true,
            unlockedChild: Text('vault-body', key: ValueKey('vault-body')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Regression: a failed unlock used to strand the user on an error
    // screen with no way back to their records.
    expect(find.byKey(const ValueKey('vault-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('vault_unlock_button')), findsOneWidget);
  });

  testWidgets('renders unavailable state when biometrics are not enrolled', (
    tester,
  ) async {
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemorySecureStorage(),
      authenticate: () async => true,
      isAvailable: () async => false,
    );
    final container = ProviderContainer(
      overrides: [vaultKeyManagerProvider.overrideWithValue(keyManager)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultGateScreen(autoUnlock: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biometrics unavailable'), findsOneWidget);
    expect(find.textContaining('Enroll biometrics'), findsOneWidget);
  });
}
