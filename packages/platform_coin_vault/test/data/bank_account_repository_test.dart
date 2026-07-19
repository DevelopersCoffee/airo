import 'dart:math';

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
    });

    test('getByNickname returns null for an unknown nickname', () async {
      final result = await repository.getByNickname('Nobody', keyBytes);

      expect(result.isSuccess, isTrue);
      expect(result.value, isNull);
    });
  });
}
