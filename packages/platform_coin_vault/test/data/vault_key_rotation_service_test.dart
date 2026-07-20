import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/crypto/vault_key_manager.dart';
import 'package:platform_coin_vault/src/data/bank_account_repository.dart';
import 'package:platform_coin_vault/src/data/pan_card_repository.dart';
import 'package:platform_coin_vault/src/data/secure_document_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/data/vault_key_rotation_service.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late InMemorySecureStorage secureStorage;
  late VaultKeyManager keyManager;
  late FieldCipher fieldCipher;
  late VaultKeyRotationService rotationService;
  late BankAccountRepository bankAccounts;
  late PanCardRepository panCards;
  late SecureDocumentRepository secureDocuments;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    secureStorage = InMemorySecureStorage();
    keyManager = VaultKeyManager.forTesting(
      secureStorage: secureStorage,
      authenticate: () async => true,
    );
    fieldCipher = FieldCipher();
    rotationService = VaultKeyRotationService(
      database: vaultDb,
      keyManager: keyManager,
      fieldCipher: fieldCipher,
    );
    bankAccounts = BankAccountRepository(database: vaultDb, fieldCipher: fieldCipher);
    panCards = PanCardRepository(database: vaultDb, fieldCipher: fieldCipher);
    secureDocuments = SecureDocumentRepository(database: vaultDb, fieldCipher: fieldCipher);
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('rotateKeyWithReencryption re-encrypts existing data so it remains readable under the new key', () async {
    final oldKey = (await keyManager.getDatabaseKey()).value;

    await bankAccounts.create(
      BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
        notes: 'primary account',
      ),
      oldKey,
    );
    final panResult = await panCards.create(
      PanCardRecord(id: null, panNumber: 'ABCDE1234F', nameOnCard: 'Jane Doe'),
      oldKey,
    );
    await secureDocuments.create(
      SecureDocumentRecord(
        id: null,
        nickname: 'Form 16 FY24-25',
        category: DocumentCategory.incomeProof,
        notes: 'Employer TDS certificate',
        createdAt: DateTime(2026, 7, 19),
      ),
      oldKey,
    );

    final rotateResult = await rotationService.rotateKeyWithReencryption();
    expect(rotateResult.isSuccess, isTrue);

    final newKey = (await keyManager.getDatabaseKey()).value;
    expect(newKey, isNot(equals(oldKey)));

    final fetchedBank = await bankAccounts.getByNickname('HDFC Salary', newKey);
    final fetchedPan = await panCards.getById(panResult.value, newKey);
    final fetchedDocument = await secureDocuments.getByNickname('Form 16 FY24-25', newKey);

    expect(fetchedBank.value?.accountNumber, '1234567890');
    expect(fetchedBank.value?.notes, 'primary account');
    expect(fetchedPan.value?.panNumber, 'ABCDE1234F');
    expect(fetchedDocument.value?.notes, 'Employer TDS certificate');
  });

  test('data is no longer decryptable under the old key after rotation', () async {
    final oldKey = (await keyManager.getDatabaseKey()).value;

    await bankAccounts.create(
      BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      ),
      oldKey,
    );

    await rotationService.rotateKeyWithReencryption();

    final fetchedWithOldKey = await bankAccounts.getByNickname('HDFC Salary', oldKey);

    expect(fetchedWithOldKey.isFailure, isTrue);
  });

  test(
    'rotateKeyWithReencryption requires exactly one successful authenticate() call, '
    'not two, so a denied second prompt can never brick the vault',
    () async {
      var authCallCount = 0;
      final countingKeyManager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async {
          authCallCount++;
          return true;
        },
      );
      final countingRotationService = VaultKeyRotationService(
        database: vaultDb,
        keyManager: countingKeyManager,
        fieldCipher: fieldCipher,
      );

      final oldKey = (await countingKeyManager.getDatabaseKey()).value;
      authCallCount = 0; // reset after the setup auth above

      await bankAccounts.create(
        BankAccountRecord(
          id: null,
          nickname: 'HDFC Salary',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '1234567890',
          ifscCode: 'HDFC0001234',
          accountType: 'savings',
        ),
        oldKey,
      );

      final rotateResult = await countingRotationService.rotateKeyWithReencryption();

      expect(rotateResult.isSuccess, isTrue);
      expect(
        authCallCount,
        1,
        reason:
            'rotation must authenticate exactly once for the whole operation — a '
            'second re-auth before persisting the new key is what previously let a '
            'denied prompt brick the vault after data was already re-encrypted',
      );
    },
  );

  test(
    '_encryptedColumnsByTable stays in sync with every actual *_enc column in the schema',
    () async {
      // Drift guard: if a future encrypted column is added to a repository
      // but not registered here, rotateKeyWithReencryption() would silently
      // skip re-encrypting it, permanently orphaning that column once the new
      // key is committed. This enumerates the real schema (following the
      // sqlite_master introspection pattern used in vault_database_test.dart)
      // and asserts it exactly matches the rotation service's registry.
      final actualEncColumnsByTable = <String, Set<String>>{};
      for (final table in [
        VaultTables.bankAccounts,
        VaultTables.panCards,
        VaultTables.secureDocuments,
      ]) {
        final columns = await vaultDb.db.rawQuery('PRAGMA table_info($table)');
        actualEncColumnsByTable[table] = columns
            .map((row) => row['name'] as String)
            .where((name) => name.endsWith('_enc'))
            .toSet();
      }

      final registeredEncColumnsByTable = encryptedColumnsByTableForTesting.map(
        (table, columns) => MapEntry(table, columns.toSet()),
      );

      expect(
        registeredEncColumnsByTable,
        actualEncColumnsByTable,
        reason:
            'every *_enc column in the schema must be registered in '
            '_encryptedColumnsByTable or key rotation will silently skip it',
      );
    },
  );
}
