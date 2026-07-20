import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/data/credit_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late CreditCardRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = CreditCardRepository(database: vaultDb);
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('create then getByNickname roundtrips a masked credit card', () async {
    final record = CreditCardRecord(
      id: null,
      nickname: 'HDFC Regalia',
      cardNetwork: CardNetwork.visa,
      last4: '4242',
      expiryMonth: 12,
      expiryYear: 2028,
      issuingBank: 'HDFC Bank',
      createdAt: DateTime(2026, 7, 19),
    );

    final createResult = await repository.create(record);
    expect(createResult.isSuccess, isTrue);

    final fetched = await repository.getByNickname('HDFC Regalia');

    expect(fetched.value?.last4, '4242');
    expect(fetched.value?.cardNetwork, CardNetwork.visa);
  });

  test('creating a second card with the same nickname fails', () async {
    final record = CreditCardRecord(
      id: null,
      nickname: 'Shared Card',
      cardNetwork: CardNetwork.mastercard,
      last4: '1111',
      expiryMonth: 1,
      expiryYear: 2027,
      issuingBank: 'ICICI Bank',
      createdAt: DateTime(2026, 7, 19),
    );

    await repository.create(record);
    final result = await repository.create(record);

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ValidationFailure>());
  });
}
