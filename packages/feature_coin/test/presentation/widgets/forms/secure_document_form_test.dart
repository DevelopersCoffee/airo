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

  Future<void> pumpSecureDocumentForm(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          home: const Scaffold(body: SecureDocumentForm()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    await tester.pump();
  }

  testWidgets('saves a document with category and custom fields', (
    tester,
  ) async {
    await pumpSecureDocumentForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nickname *'),
      'Form 16 FY25',
    );

    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Field name').first,
      'employer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Value').first,
      'Acme',
    );

    await tapSave(tester);
    await tester.pumpAndSettle();

    late List<SecureDocumentSummary> summaries;
    await tester.runAsync(() async {
      summaries = (await repos.secureDocuments.listAllSummaries()).value;
    });
    expect(summaries.single.nickname, 'Form 16 FY25');
    expect(summaries.single.category, DocumentCategory.incomeProof);

    late SecureDocumentRecord? record;
    await tester.runAsync(() async {
      record = await container
          .read(vaultSessionProvider.notifier)
          .withKey<SecureDocumentRecord?>((key) async {
            return (await repos.secureDocuments.getByNickname(
              'Form 16 FY25',
              key,
            )).value;
          });
    });
    expect(record?.customFields, {'employer': 'Acme'});
  });
}
