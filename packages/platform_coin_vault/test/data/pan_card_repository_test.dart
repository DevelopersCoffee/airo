import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/pan_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late PanCardRepository repository;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = PanCardRepository(database: vaultDb, fieldCipher: FieldCipher());
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('create then getById roundtrips the decrypted PAN number', () async {
    final record = PanCardRecord(
      id: null,
      panNumber: 'ABCDE1234F',
      nameOnCard: 'Jane Doe',
    );

    final createResult = await repository.create(record, keyBytes);
    expect(createResult.isSuccess, isTrue);

    final fetched = await repository.getById(createResult.value, keyBytes);

    expect(fetched.value?.panNumber, 'ABCDE1234F');
  });

  test('stored pan_number_enc column is never plaintext', () async {
    final record = PanCardRecord(id: null, panNumber: 'ABCDE1234F', nameOnCard: 'Jane Doe');
    final createResult = await repository.create(record, keyBytes);

    final rows = await vaultDb.db.query(VaultTables.panCards);
    expect(rows.single['pan_number_enc'], isNot('ABCDE1234F'));
    expect(createResult.isSuccess, isTrue);
  });

  test('cardImageBlob roundtrips through encryption, including bytes >= 128', () async {
    final blob = [0, 127, 128, 200, 255];
    final record = PanCardRecord(
      id: null,
      panNumber: 'ABCDE1234F',
      nameOnCard: 'Jane Doe',
      cardImageBlob: blob,
    );

    final createResult = await repository.create(record, keyBytes);
    final fetched = await repository.getById(createResult.value, keyBytes);

    expect(fetched.value?.cardImageBlob, blob);
  });
}
