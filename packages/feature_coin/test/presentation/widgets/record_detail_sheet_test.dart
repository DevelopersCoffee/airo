// ignore_for_file: depend_on_referenced_packages

import 'package:core_data/core_data.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages;
import 'package:mocktail/mocktail.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;
  late ProviderContainer container;
  late ClipboardService clipboardService;
  late MockLocalAuthentication localAuth;
  var clipboard = '';

  const summary = BankAccountSummary(
    nickname: 'HDFC Salary',
    bankName: 'HDFC Bank',
    accountHolderName: 'Jane Doe',
    ifscCode: 'HDFC0001234',
    accountType: 'savings',
  );

  setUpAll(() {
    sqfliteFfiInit();
    registerFallbackValue(const <AuthMessages>[]);
    registerFallbackValue(const AuthenticationOptions());
  });

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
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemorySecureStorage(),
      authenticate: () async => true,
      isAvailable: () async => true,
    );
    localAuth = MockLocalAuthentication();
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        authMessages: any(named: 'authMessages'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => true);
    clipboard = '';
    clipboardService = ClipboardService(
      setData: (data) async => clipboard = data.text ?? '',
      getData: () async => ClipboardData(text: clipboard),
    );
    container = ProviderContainer(
      overrides: [
        vaultRepositoriesProvider.overrideWith((ref) async => repos),
        vaultKeyManagerProvider.overrideWithValue(keyManager),
        localAuthenticationProvider.overrideWithValue(localAuth),
        clipboardServiceProvider.overrideWithValue(clipboardService),
      ],
    );
    addTearDown(() async {
      clipboardService.dispose();
      container.dispose();
      await vaultDb.close();
    });

    // Unlock first so seed data is encrypted under the session's real DEK.
    await container.read(vaultSessionProvider.notifier).unlock();
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
          notes: 'salary credit',
        ),
        key,
      );
    });
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await container.read(vaultSessionProvider.notifier).unlock();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: RecordDetailSheet(
              recordType: VaultRecordType.bankAccount,
              recordKey: 'HDFC Salary',
              summary: summary,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleVaultAsync(
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

  testWidgets('sensitive fields are masked by default', (tester) async {
    await pumpSheet(tester);

    expect(find.text('•••• •••• ••••'), findsOneWidget);
    expect(find.text('1234567890'), findsNothing);
    expect(find.text('HDFC Bank'), findsOneWidget);
  });

  testWidgets('tap-to-reveal decrypts and shows the account number', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Reveal Account number'));
    await settleVaultAsync(tester);

    expect(find.text('1234567890'), findsOneWidget);
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('copy stores the decrypted value via the clipboard service', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Copy Account number'));
    await settleVaultAsync(tester, until: () => clipboard == '1234567890');

    expect(clipboard, '1234567890');
    clipboardService.dispose();
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('locking clears any cached revealed sensitive values', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Reveal Account number'));
    await settleVaultAsync(tester);
    expect(find.text('1234567890'), findsOneWidget);

    container.read(vaultSessionProvider.notifier).lock();
    await tester.pump();

    expect(find.text('1234567890'), findsNothing);
    expect(find.text('•••• •••• ••••'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy Account number'));
    await settleVaultAsync(tester);

    expect(clipboard, isEmpty);
    expect(find.text('Vault is locked - unlock and try again'), findsOneWidget);
  });

  testWidgets('locking during reveal does not re-cache sensitive values', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Reveal Account number'));
    container.read(vaultSessionProvider.notifier).lock();
    await settleVaultAsync(tester);

    expect(find.text('1234567890'), findsNothing);
    expect(find.text('•••• •••• ••••'), findsOneWidget);
  });

  testWidgets('read failures are surfaced instead of silently doing nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await vaultDb.db.update(
        VaultTables.bankAccounts,
        {'account_number_enc': 'not-valid-ciphertext'},
        where: 'nickname = ?',
        whereArgs: ['HDFC Salary'],
      );
    });
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Reveal Account number'));
    await settleVaultAsync(tester);

    expect(find.text('1234567890'), findsNothing);
    expect(find.text('Failed to read bank account'), findsOneWidget);
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('malformed PAN keys fail safely', (tester) async {
    await container.read(vaultSessionProvider.notifier).unlock();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: RecordDetailSheet(
              recordType: VaultRecordType.panCard,
              recordKey: 'not-an-id',
              summary: PanCardSummary(id: 1, nameOnCard: 'Jane Doe'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reveal PAN'));
    await settleVaultAsync(tester);

    expect(find.text('Invalid PAN record key'), findsOneWidget);
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('delete confirms, re-authenticates, and removes the record', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Delete record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    var deleted = false;
    await tester.runAsync(() async {
      for (var i = 0; i < 50; i++) {
        final fetched = await repos.bankAccounts.listAllSummaries();
        deleted = !fetched.value.any(
          (account) => account.nickname == 'HDFC Salary',
        );
        if (deleted) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(deleted, isTrue);
    verify(
      () => localAuth.authenticate(
        localizedReason: 'Confirm deletion of this vault record',
        authMessages: any(named: 'authMessages'),
        options: any(named: 'options'),
      ),
    ).called(1);
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('delete fails closed when biometric confirmation is cancelled', (
    tester,
  ) async {
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        authMessages: any(named: 'authMessages'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => false);
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Delete record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not confirm deletion'), findsOneWidget);
    var stillPresent = false;
    await tester.runAsync(() async {
      final fetched = await repos.bankAccounts.listAllSummaries();
      stillPresent = fetched.value.any(
        (account) => account.nickname == 'HDFC Salary',
      );
    });
    expect(stillPresent, isTrue);
    container.read(vaultSessionProvider.notifier).lock();
  });

  testWidgets('delete fails closed when biometric confirmation throws', (
    tester,
  ) async {
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        authMessages: any(named: 'authMessages'),
        options: any(named: 'options'),
      ),
    ).thenThrow(PlatformException(code: 'auth_failed'));
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Delete record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not confirm deletion'), findsOneWidget);
    var stillPresent = false;
    await tester.runAsync(() async {
      final fetched = await repos.bankAccounts.listAllSummaries();
      stillPresent = fetched.value.any(
        (account) => account.nickname == 'HDFC Salary',
      );
    });
    expect(stillPresent, isTrue);
    container.read(vaultSessionProvider.notifier).lock();
  });
}
