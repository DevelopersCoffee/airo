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
  testWidgets('renders locked state without exposing vault content', (
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
        child: const MaterialApp(home: VaultGateScreen(autoUnlock: false)),
      ),
    );
    await tester.pump();

    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('vault_unlock_button')), findsOneWidget);
    expect(security.protects, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(security.unprotects, 1);
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
        child: const MaterialApp(home: VaultGateScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biometrics unavailable'), findsOneWidget);
    expect(find.textContaining('Enroll biometrics'), findsOneWidget);
  });
}
