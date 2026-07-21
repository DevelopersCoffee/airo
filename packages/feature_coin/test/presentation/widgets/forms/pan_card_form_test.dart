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

  Future<void> pumpPanForm(WidgetTester tester, {int? recordId}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          home: Scaffold(body: PanCardForm(recordId: recordId)),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> fillValidPanForm(
    WidgetTester tester, {
    String name = 'Jane Doe',
    String pan = 'ABCDE1234F',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name on card *'),
      name,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'PAN *'), pan);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    await tester.pump();
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

  Future<List<PanCardSummary>> listPanSummaries(WidgetTester tester) async {
    late List<PanCardSummary> summaries;
    await tester.runAsync(() async {
      summaries = (await repos.panCards.listAllSummaries()).value;
    });
    return summaries;
  }

  Future<int> seedPanCard({List<int>? cardImageBlob}) async {
    final id = await container.read(vaultSessionProvider.notifier).withKey<int>(
      (key) async {
        return (await repos.panCards.create(
          PanCardRecord(
            id: null,
            panNumber: 'ABCDE1234F',
            nameOnCard: 'Jane Doe',
            fathersName: 'John Doe',
            cardImageBlob: cardImageBlob,
          ),
          key,
        )).value;
      },
    );
    return id!;
  }

  Future<PanCardRecord?> getPanCard(int id) async {
    return container
        .read(vaultSessionProvider.notifier)
        .withKey<PanCardRecord?>((key) async {
          return (await repos.panCards.getById(id, key)).value;
        });
  }

  String panNumberText(WidgetTester tester) {
    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'PAN *'),
    );
    return field.controller!.text;
  }

  testWidgets('invalid PAN shows an inline error and saves nothing', (
    tester,
  ) async {
    await pumpPanForm(tester);
    await fillValidPanForm(tester, pan: 'NOTAPAN');

    await tapSave(tester);
    await tester.pump();

    expect(find.textContaining('Invalid PAN'), findsOneWidget);
    expect(await listPanSummaries(tester), isEmpty);
  });

  testWidgets('valid form creates the PAN card', (tester) async {
    await pumpPanForm(tester);
    await fillValidPanForm(tester);

    await tapSave(tester);
    await settleFormAsync(
      tester,
      until: () => find.widgetWithText(FilledButton, 'Save').evaluate().isEmpty,
    );

    final summaries = await listPanSummaries(tester);
    expect(summaries.single.nameOnCard, 'Jane Doe');
  });

  testWidgets('edit mode updates by row id and preserves card image blob', (
    tester,
  ) async {
    final id = (await tester.runAsync(
      () => seedPanCard(cardImageBlob: [0, 127, 128, 255]),
    ))!;
    await pumpPanForm(tester, recordId: id);
    await settleFormAsync(
      tester,
      until: () =>
          find.widgetWithText(TextFormField, 'PAN *').evaluate().isNotEmpty,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name on card *'),
      'Jane A Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'PAN *'),
      'PQRST6789L',
    );
    await tapSave(tester);
    await settleFormAsync(tester);

    late PanCardRecord? fetched;
    await tester.runAsync(() async {
      fetched = await getPanCard(id);
    });
    expect(fetched?.nameOnCard, 'Jane A Doe');
    expect(fetched?.panNumber, 'PQRST6789L');
    expect(fetched?.cardImageBlob, [0, 127, 128, 255]);
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('edit mode clears sensitive PAN when vault locks', (
    tester,
  ) async {
    final id = (await tester.runAsync(seedPanCard))!;
    await pumpPanForm(tester, recordId: id);
    await settleFormAsync(
      tester,
      until: () =>
          find.widgetWithText(TextFormField, 'PAN *').evaluate().isNotEmpty,
    );

    expect(panNumberText(tester), 'ABCDE1234F');

    container.read(vaultSessionProvider.notifier).lock();
    await tester.pump();

    expect(find.text('Vault is locked - unlock and try again'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'PAN *'), findsNothing);
  });

  testWidgets('locked save fails closed and clears the PAN field', (
    tester,
  ) async {
    await pumpPanForm(tester);
    await fillValidPanForm(tester);

    container.read(vaultSessionProvider.notifier).lock();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'PAN *'),
      'PQRST6789L',
    );
    await tapSave(tester);
    await tester.pump();

    expect(find.text('Vault is locked - unlock and try again'), findsOneWidget);
    expect(panNumberText(tester), isEmpty);
    expect(await listPanSummaries(tester), isEmpty);
  });
}
