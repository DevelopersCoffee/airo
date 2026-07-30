// ignore_for_file: depend_on_referenced_packages

import 'package:core_data/core_data.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

/// The vault journey past the biometric prompt.
///
/// Physical-device QA can drive the vault up to the system prompt and no
/// further: a real Pixel has no fingerprint-injection API, so the authenticated
/// screens cannot be reached from adb. `vault_session_test.dart` covers the
/// session state machine, and the existing gate tests cover the locked side;
/// these cover what the gate *renders* once authentication succeeds, which is
/// otherwise only ever seen by a human with a finger on the sensor.
class _CountingScreenSecurity extends VaultScreenSecurity {
  _CountingScreenSecurity()
    : super(enableProtection: () async {}, disableProtection: () async {});

  var protects = 0;
  var unprotects = 0;

  @override
  Future<void> protect() async => protects++;

  @override
  Future<void> unprotect() async => unprotects++;
}

void main() {
  VaultKeyManager keyManager({bool authenticate = true}) =>
      VaultKeyManager.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async => authenticate,
        isAvailable: () async => true,
      );

  Future<(ProviderContainer, _CountingScreenSecurity)> pumpGate(
    WidgetTester tester, {
    bool authenticate = true,
  }) async {
    final security = _CountingScreenSecurity();
    final container = ProviderContainer(
      overrides: [
        screenSecurityProvider.overrideWithValue(security),
        vaultKeyManagerProvider.overrideWithValue(
          keyManager(authenticate: authenticate),
        ),
      ],
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
    return (container, security);
  }

  testWidgets('a successful unlock drops the locked banner and keeps '
      'screen protection applied', (tester) async {
    final (container, security) = await pumpGate(tester);

    expect(find.textContaining('Locked.'), findsOneWidget);
    expect(security.protects, 1);

    await tester.tap(find.byKey(const ValueKey('vault_unlock_button')));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());
    expect(
      find.textContaining('Locked.'),
      findsNothing,
      reason:
          'the locked banner and its Unlock button belong to the locked '
          'state only',
    );
    expect(find.byKey(const ValueKey('vault_unlock_button')), findsNothing);
    expect(find.byKey(const ValueKey('vault-body')), findsOneWidget);
    expect(
      security.protects,
      1,
      reason:
          'FLAG_SECURE was applied when the vault opened and must stay on '
          'across the unlock, not be re-applied or dropped',
    );
    expect(security.unprotects, 0);

    // Unlocking arms the idle auto-lock timer; lock explicitly so the test
    // does not end with it pending.
    container.read(vaultSessionProvider.notifier).lock();
    await tester.pumpAndSettle();
  });

  testWidgets('locking again returns to the browsable locked state', (
    tester,
  ) async {
    final (container, security) = await pumpGate(tester);

    await tester.tap(find.byKey(const ValueKey('vault_unlock_button')));
    await tester.pumpAndSettle();
    expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

    container.read(vaultSessionProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    expect(find.textContaining('Locked.'), findsOneWidget);
    expect(find.byKey(const ValueKey('vault_unlock_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-body')),
      findsOneWidget,
      reason:
          'summaries stay browsable while locked -- relocking must not '
          'wall the feature off',
    );
    expect(security.unprotects, 0, reason: 'still on a vault route');
  });

  testWidgets('a failed authentication explains itself and stays browsable', (
    tester,
  ) async {
    final (container, _) = await pumpGate(tester, authenticate: false);

    await tester.tap(find.byKey(const ValueKey('vault_unlock_button')));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultAuthError>());
    expect(
      find.byKey(const ValueKey('vault-body')),
      findsOneWidget,
      reason: 'a failed unlock must not wall off the plaintext summaries',
    );
    expect(
      find.byKey(const ValueKey('vault_unlock_button')),
      findsOneWidget,
      reason: 'the user needs a way to try again',
    );
  });
}
