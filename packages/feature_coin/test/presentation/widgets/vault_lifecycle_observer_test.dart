// ignore_for_file: depend_on_referenced_packages

import 'package:core_data/core_data.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

void main() {
  testWidgets('going to background locks an unlocked vault', (tester) async {
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemorySecureStorage(),
      authenticate: () async => true,
      isAvailable: () async => true,
    );
    final container = ProviderContainer(
      overrides: [vaultKeyManagerProvider.overrideWithValue(keyManager)],
    );
    addTearDown(container.dispose);
    await container.read(vaultSessionProvider.notifier).unlock();
    expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultLifecycleObserver(child: Scaffold()),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(vaultSessionProvider), isA<VaultLocked>());
  });
}
