import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/data/credit_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/vault_entry_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late CreditCardRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = CreditCardRepository(database: vaultDb);
  });

  tearDown(() => vaultDb.close());

  CreditCardRecord record(
    String nickname, {
    String last4 = '4321',
    DateTime? createdAt,
  }) => CreditCardRecord(
    id: null,
    nickname: nickname,
    cardNetwork: CardNetwork.visa,
    last4: last4,
    expiryMonth: 8,
    expiryYear: 2029,
    issuingBank: 'ICICI Bank',
    createdAt: createdAt ?? DateTime(2026, 7, 20),
  );

  group('listAllSummaries', () {
    test('lists masked-only summaries ordered by nickname', () async {
      await repository.create(record('Zeta Card'));
      await repository.create(record('Alpha Card', last4: '1111'));

      final result = await repository.listAllSummaries();

      expect(result.isSuccess, isTrue);
      expect(result.value, [
        const CreditCardSummary(
          nickname: 'Alpha Card',
          cardNetwork: CardNetwork.visa,
          last4: '1111',
          expiryMonth: 8,
          expiryYear: 2029,
          issuingBank: 'ICICI Bank',
        ),
        const CreditCardSummary(
          nickname: 'Zeta Card',
          cardNetwork: CardNetwork.visa,
          last4: '4321',
          expiryMonth: 8,
          expiryYear: 2029,
          issuingBank: 'ICICI Bank',
        ),
      ]);
    });
  });

  group('update', () {
    test('persists changed masked fields', () async {
      final originalCreatedAt = DateTime(2026, 7, 20);
      final replacementCreatedAt = DateTime(2026, 7, 21);

      await repository.create(
        record('Main Card', createdAt: originalCreatedAt),
      );

      final updateResult = await repository.update(
        CreditCardRecord(
          id: null,
          nickname: 'Main Card',
          cardNetwork: CardNetwork.rupay,
          last4: '9876',
          expiryMonth: 1,
          expiryYear: 2030,
          issuingBank: 'SBI',
          createdAt: replacementCreatedAt,
        ),
      );

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('Main Card');
      expect(fetched.value?.last4, '9876');
      expect(fetched.value?.cardNetwork, CardNetwork.rupay);
      expect(fetched.value?.expiryMonth, 1);
      expect(fetched.value?.expiryYear, 2030);
      expect(fetched.value?.issuingBank, 'SBI');
      expect(fetched.value?.createdAt, originalCreatedAt);
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.update(record('Ghost'));

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('deleteByNickname', () {
    test('removes the record; unknown nickname fails', () async {
      await repository.create(record('Main Card'));

      expect(
        (await repository.deleteByNickname('Main Card')).isSuccess,
        isTrue,
      );
      expect((await repository.getByNickname('Main Card')).value, isNull);

      final missing = await repository.deleteByNickname('Main Card');
      expect(missing.isFailure, isTrue);
      expect(missing.failure, isA<NotFoundFailure>());
    });
  });
}
