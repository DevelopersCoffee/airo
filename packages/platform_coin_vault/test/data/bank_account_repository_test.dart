import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/bank_account_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late BankAccountRepository repository;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = BankAccountRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  group('BankAccountRepository', () {
    test('create then getByNickname roundtrips the decrypted account number', () async {
      final record = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      final createResult = await repository.create(record, keyBytes);
      expect(createResult.isSuccess, isTrue);

      final fetched = await repository.getByNickname('HDFC Salary', keyBytes);

      expect(fetched.value?.accountNumber, '1234567890');
      expect(fetched.value?.nickname, 'HDFC Salary');
    });

    test('stored account_number_enc column is never plaintext', () async {
      final record = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      await repository.create(record, keyBytes);

      final rows = await vaultDb.db.query(VaultTables.bankAccounts);
      expect(rows.single['account_number_enc'], isNot('1234567890'));
    });

    test('creating a second account with the same nickname fails', () async {
      final first = BankAccountRecord(
        id: null,
        nickname: 'Shared Nick',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1111111111',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      final second = BankAccountRecord(
        id: null,
        nickname: 'Shared Nick',
        bankName: 'ICICI Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '2222222222',
        ifscCode: 'ICIC0005678',
        accountType: 'current',
      );

      await repository.create(first, keyBytes);
      final secondResult = await repository.create(second, keyBytes);

      expect(secondResult.isFailure, isTrue);
      expect(secondResult.failure, isA<ValidationFailure>());
    });

    test('ciphertext swapped between two rows of the same column fails to decrypt', () async {
      final first = BankAccountRecord(
        id: null,
        nickname: 'Row One',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1111111111',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      final second = BankAccountRecord(
        id: null,
        nickname: 'Row Two',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '2222222222',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      await repository.create(first, keyBytes);
      await repository.create(second, keyBytes);

      final firstRow = (await vaultDb.db.query(
        VaultTables.bankAccounts,
        where: 'nickname = ?',
        whereArgs: ['Row One'],
      )).single;
      final stolenCiphertext = firstRow['account_number_enc'];

      await vaultDb.db.update(
        VaultTables.bankAccounts,
        {'account_number_enc': stolenCiphertext},
        where: 'nickname = ?',
        whereArgs: ['Row Two'],
      );

      final tampered = await repository.getByNickname('Row Two', keyBytes);

      expect(tampered.isFailure, isTrue);
    });

    test('getByNickname returns null for an unknown nickname', () async {
      final result = await repository.getByNickname('Nobody', keyBytes);

      expect(result.isSuccess, isTrue);
      expect(result.value, isNull);
    });

    test(
      'create leaves no placeholder row behind when encryption throws mid-create',
      () async {
        final throwingRepository = BankAccountRepository(
          database: vaultDb,
          fieldCipher: _ThrowingFieldCipher(),
        );
        final record = BankAccountRecord(
          id: null,
          nickname: 'Doomed Account',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '1234567890',
          ifscCode: 'HDFC0001234',
          accountType: 'savings',
        );

        final result = await throwingRepository.create(record, keyBytes);
        expect(result.isFailure, isTrue);

        final rows = await vaultDb.db.query(VaultTables.bankAccounts);
        expect(
          rows,
          isEmpty,
          reason:
              'the insert-then-update sequence is now wrapped in a transaction, so '
              'an exception thrown by encryptField() must roll back the placeholder '
              'insert too, not leave a zombie row with empty-string ciphertext',
        );
      },
    );

    test(
      'creating a second account with a colliding nickname leaves row count at 1, not 2',
      () async {
        final first = BankAccountRecord(
          id: null,
          nickname: 'Collision Nick',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '1111111111',
          ifscCode: 'HDFC0001234',
          accountType: 'savings',
        );
        final second = BankAccountRecord(
          id: null,
          nickname: 'Collision Nick',
          bankName: 'ICICI Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '2222222222',
          ifscCode: 'ICIC0005678',
          accountType: 'current',
        );

        await repository.create(first, keyBytes);
        await repository.create(second, keyBytes);

        final rows = await vaultDb.db.query(
          VaultTables.bankAccounts,
          where: 'nickname = ?',
          whereArgs: ['Collision Nick'],
        );
        expect(rows, hasLength(1));
      },
    );
  });
}

/// Throws from [encryptField] to simulate an exception occurring between the
/// placeholder insert and the ciphertext update inside `create()`, proving
/// the surrounding transaction rolls back the placeholder insert too.
class _ThrowingFieldCipher extends FieldCipher {
  @override
  Future<String> encryptField(
    String plaintext,
    List<int> keyBytes, {
    required String context,
  }) {
    throw StateError('simulated encryption failure for atomicity test');
  }
}
