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

  Future<void> pumpBankForm(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          home: const Scaffold(body: BankAccountForm()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpBankEditForm(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          home: const Scaffold(body: BankAccountForm(nickname: 'HDFC Salary')),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> fillValidBankForm(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nickname *'),
      'HDFC Salary',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bank name *'),
      'HDFC Bank',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account holder name *'),
      'Jane Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account number *'),
      '1234567890',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'IFSC *'),
      'HDFC0001234',
    );
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    await tester.pump();
  }

  Future<List<BankAccountSummary>> listBankSummaries(
    WidgetTester tester,
  ) async {
    late List<BankAccountSummary> summaries;
    await tester.runAsync(() async {
      summaries = (await repos.bankAccounts.listAllSummaries()).value;
    });
    return summaries;
  }

  Future<void> waitForBankCount(WidgetTester tester, int expectedCount) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 50; i++) {
        final summaries = (await repos.bankAccounts.listAllSummaries()).value;
        if (summaries.length == expectedCount) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> seedBankAccount({String? customerId}) async {
    await container.read(vaultSessionProvider.notifier).withKey((key) async {
      await repos.bankAccounts.create(
        BankAccountRecord(
          id: null,
          nickname: 'HDFC Salary',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '1234567890',
          ifscCode: 'HDFC0001234',
          accountType: 'savings',
          customerId: customerId,
          notes: 'salary credit',
        ),
        key,
      );
    });
  }

  String bankAccountNumberText(WidgetTester tester) {
    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Account number *'),
    );
    return field.controller!.text;
  }

  Future<BankAccountRecord?> getBankAccount() async {
    return container
        .read(vaultSessionProvider.notifier)
        .withKey<BankAccountRecord?>((key) async {
          return (await repos.bankAccounts.getByNickname(
            'HDFC Salary',
            key,
          )).value;
        });
  }

  Future<void> settleFormAsync(
    WidgetTester tester, {
    bool Function()? until,
  }) async {
    Future<void> waitHostSide() async {
      for (var i = 0; i < 50; i++) {
        if (until?.call() ?? false) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    await tester.runAsync(waitHostSide);
    await tester.pump();
    if (until != null && !until()) {
      await tester.runAsync(waitHostSide);
      await tester.pump();
    }
  }

  testWidgets('invalid IFSC shows an inline error and saves nothing', (
    tester,
  ) async {
    await pumpBankForm(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nickname *'),
      'HDFC Salary',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bank name *'),
      'HDFC Bank',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account holder name *'),
      'Jane Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account number *'),
      '1234567890',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'IFSC *'),
      'NOT-AN-IFSC',
    );

    await tapSave(tester);
    await tester.pump();

    expect(find.textContaining('Invalid IFSC'), findsOneWidget);
    expect(await listBankSummaries(tester), isEmpty);
  });

  testWidgets('valid form creates the record', (tester) async {
    await pumpBankForm(tester);
    await fillValidBankForm(tester);

    await tapSave(tester);
    await waitForBankCount(tester, 1);

    final summaries = await listBankSummaries(tester);
    expect(summaries.single.nickname, 'HDFC Salary');
  });

  testWidgets('duplicate nickname surfaces an inline nickname error', (
    tester,
  ) async {
    await pumpBankForm(tester);
    await fillValidBankForm(tester);
    await tapSave(tester);
    await waitForBankCount(tester, 1);

    await pumpBankForm(tester);
    await fillValidBankForm(tester);
    await tapSave(tester);
    await settleFormAsync(
      tester,
      until: () => find.textContaining('already exists').evaluate().isNotEmpty,
    );

    expect(find.textContaining('already exists'), findsOneWidget);
  });

  testWidgets('edit mode clears sensitive account fields when vault locks', (
    tester,
  ) async {
    await tester.runAsync(seedBankAccount);
    await pumpBankEditForm(tester);
    await settleFormAsync(
      tester,
      until: () => find
          .widgetWithText(TextFormField, 'Account number *')
          .evaluate()
          .isNotEmpty,
    );

    expect(bankAccountNumberText(tester), '1234567890');

    container.read(vaultSessionProvider.notifier).lock();
    await tester.pump();

    expect(find.text('Vault is locked - unlock and try again'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Account number *'),
      findsNothing,
    );
  });

  testWidgets('edit mode preserves bank fields that are not rendered', (
    tester,
  ) async {
    await tester.runAsync(() => seedBankAccount(customerId: 'CUST-42'));
    await pumpBankEditForm(tester);
    await settleFormAsync(
      tester,
      until: () => find
          .widgetWithText(TextFormField, 'Account number *')
          .evaluate()
          .isNotEmpty,
    );

    await tapSave(tester);
    await settleFormAsync(tester);

    late BankAccountRecord? fetched;
    await tester.runAsync(() async {
      fetched = await getBankAccount();
    });
    expect(fetched?.customerId, 'CUST-42');
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('malformed PAN edit key renders a safe error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VaultRecordFormScreen(
          recordType: VaultRecordType.panCard,
          recordKey: 'not-an-id',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invalid PAN record key'), findsOneWidget);
  });
}
