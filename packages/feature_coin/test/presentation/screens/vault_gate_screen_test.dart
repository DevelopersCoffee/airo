// ignore_for_file: depend_on_referenced_packages

import 'package:core_data/core_data.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    final cipher = FieldCipher();
    repos = VaultRepositories(
      bankAccounts: BankAccountRepository(
        database: vaultDb,
        fieldCipher: cipher,
      ),
      panCards: PanCardRepository(database: vaultDb, fieldCipher: cipher),
      creditCards: CreditCardRepository(database: vaultDb),
      secureDocuments: SecureDocumentRepository(
        database: vaultDb,
        fieldCipher: cipher,
      ),
    );
  });

  tearDown(() => vaultDb.close());

  ProviderContainer containerFor(VaultKeyManager keyManager) {
    final container = ProviderContainer(
      overrides: [
        vaultKeyManagerProvider.overrideWithValue(keyManager),
        vaultRepositoriesProvider.overrideWith((ref) async => repos),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int attempts = 200,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText())
        .nonNulls
        .join(', ');
    fail('Expected $finder to appear. Visible text: $visibleText');
  }

  testWidgets('gate auto-prompts and lands on the vault home when unlocked', (
    tester,
  ) async {
    final container = containerFor(
      VaultKeyManager.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async => true,
        isAvailable: () async => true,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultGateScreen()),
      ),
    );
    await pumpUntilFound(tester, find.text('Vault is empty'));

    expect(find.text('Secure Vault'), findsOneWidget);
    expect(find.text('Vault is empty'), findsOneWidget);

    container.read(vaultSessionProvider.notifier).lock();
    await tester.pump();
  });

  testWidgets('gate shows unavailable view on devices without biometrics', (
    tester,
  ) async {
    final container = containerFor(
      VaultKeyManager.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async => true,
        isAvailable: () async => false,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultGateScreen()),
      ),
    );
    await pumpUntilFound(tester, find.text('Biometrics required'));

    expect(find.text('Biometrics required'), findsOneWidget);
  });

  testWidgets('manual lock returns the gate to the lock screen', (
    tester,
  ) async {
    final container = containerFor(
      VaultKeyManager.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async => true,
        isAvailable: () async => true,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultGateScreen()),
      ),
    );
    await pumpUntilFound(tester, find.byTooltip('Lock vault'));

    await tester.tap(find.byTooltip('Lock vault'));
    await tester.pumpAndSettle();

    expect(find.text('Vault locked'), findsOneWidget);
  });
}
