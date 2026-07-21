import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/bank_account_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';
import 'package:platform_coin_vault/src/domain/entities/vault_entry_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late BankAccountRepository repository;
  late List<int> keyBytes;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = BankAccountRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() => vaultDb.close());

  BankAccountRecord record(
    String nickname, {
    String accountNumber = '1234567890',
    DateTime? createdAt,
  }) => BankAccountRecord(
    id: null,
    nickname: nickname,
    bankName: 'HDFC Bank',
    accountHolderName: 'Jane Doe',
    accountNumber: accountNumber,
    ifscCode: 'HDFC0001234',
    accountType: 'savings',
    createdAt: createdAt,
  );

  group('listAllSummaries', () {
    test('returns an empty list when the vault has no accounts', () async {
      final result = await repository.listAllSummaries();
      expect(result.isSuccess, isTrue);
      expect(result.value, isEmpty);
    });

    test(
      'lists summaries ordered by nickname without needing keyBytes',
      () async {
        await repository.create(record('Zeta'), keyBytes);
        await repository.create(record('Alpha'), keyBytes);

        final result = await repository.listAllSummaries();

        expect(result.isSuccess, isTrue);
        expect(result.value, [
          const BankAccountSummary(
            nickname: 'Alpha',
            bankName: 'HDFC Bank',
            accountHolderName: 'Jane Doe',
            ifscCode: 'HDFC0001234',
            accountType: 'savings',
          ),
          const BankAccountSummary(
            nickname: 'Zeta',
            bankName: 'HDFC Bank',
            accountHolderName: 'Jane Doe',
            ifscCode: 'HDFC0001234',
            accountType: 'savings',
          ),
        ]);
      },
    );
  });

  group('update', () {
    test('re-encrypts and persists changed fields', () async {
      final originalCreatedAt = DateTime(2026, 1, 2, 3, 4, 5);
      final replacementCreatedAt = DateTime(2026, 6, 7, 8, 9, 10);
      await repository.create(
        record('HDFC Salary', createdAt: originalCreatedAt),
        keyBytes,
      );

      final updated = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '9998887776',
        ifscCode: 'HDFC0001234',
        accountType: 'current',
        notes: 'updated note',
        createdAt: replacementCreatedAt,
      );
      final updateResult = await repository.update(updated, keyBytes);

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('HDFC Salary', keyBytes);
      expect(fetched.value?.accountNumber, '9998887776');
      expect(fetched.value?.accountType, 'current');
      expect(fetched.value?.notes, 'updated note');
      expect(
        fetched.value?.createdAt.millisecondsSinceEpoch,
        originalCreatedAt.millisecondsSinceEpoch,
      );
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.update(record('Ghost'), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('deleteByNickname', () {
    test('removes the record', () async {
      await repository.create(record('HDFC Salary'), keyBytes);

      final deleteResult = await repository.deleteByNickname('HDFC Salary');

      expect(deleteResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('HDFC Salary', keyBytes);
      expect(fetched.value, isNull);
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.deleteByNickname('Ghost');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });
}
