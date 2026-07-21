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
  late ProviderContainer container;

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
    container = ProviderContainer(
      overrides: [
        vaultRepositoriesProvider.overrideWith((ref) async => repos),
        vaultKeyManagerProvider.overrideWithValue(
          VaultKeyManager.forTesting(
            secureStorage: InMemorySecureStorage(),
            authenticate: () async => true,
            isAvailable: () async => true,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await vaultDb.close();
    });
    await container.read(vaultSessionProvider.notifier).unlock();
  });

  Future<void> pumpCreditCardForm(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          home: const Scaffold(body: CreditCardForm()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillCreditCardForm(
    WidgetTester tester, {
    required String last4,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nickname *'),
      'Main Card',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last 4 digits *'),
      last4,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expiry month *'),
      '8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expiry year *'),
      '2029',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Issuing bank *'),
      'ICICI Bank',
    );
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    await tester.pump();
  }

  Future<List<CreditCardSummary>> listCreditCardSummaries(
    WidgetTester tester,
  ) async {
    late List<CreditCardSummary> summaries;
    await tester.runAsync(() async {
      summaries = (await repos.creditCards.listAllSummaries()).value;
    });
    return summaries;
  }

  testWidgets('rejects a non-4-digit last4', (tester) async {
    await pumpCreditCardForm(tester);
    await fillCreditCardForm(tester, last4: '123');

    await tapSave(tester);
    await tester.pump();

    expect(find.text('Exactly 4 digits'), findsOneWidget);
    expect(await listCreditCardSummaries(tester), isEmpty);
  });

  testWidgets('valid masked card saves without any full-PAN field', (
    tester,
  ) async {
    await pumpCreditCardForm(tester);

    expect(find.widgetWithText(TextFormField, 'Card number'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'CVV'), findsNothing);

    await fillCreditCardForm(tester, last4: '4321');

    await tapSave(tester);
    await tester.pumpAndSettle();

    final summaries = await listCreditCardSummaries(tester);
    expect(summaries.single.nickname, 'Main Card');
    expect(summaries.single.last4, '4321');
  });
}
