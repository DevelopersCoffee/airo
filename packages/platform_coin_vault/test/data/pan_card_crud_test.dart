import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/pan_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/vault_entry_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late PanCardRepository repository;
  late List<int> keyBytes;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = PanCardRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() => vaultDb.close());

  PanCardRecord record({
    int? id,
    String pan = 'ABCDE1234F',
    String name = 'JANE DOE',
    String? fathersName,
    DateTime? dateOfBirth,
    List<int>? cardImageBlob,
    DateTime? createdAt,
  }) => PanCardRecord(
    id: id,
    panNumber: pan,
    nameOnCard: name,
    fathersName: fathersName,
    dateOfBirth: dateOfBirth,
    cardImageBlob: cardImageBlob,
    createdAt: createdAt,
  );

  group('listAllSummaries', () {
    test('returns summaries with row ids, no keyBytes needed', () async {
      final zuluId = (await repository.create(
        record(name: 'ZULU KHAN'),
        keyBytes,
      )).value;
      final amitId = (await repository.create(
        record(name: 'AMIT SHAH', pan: 'FGHIJ5678K', fathersName: 'RAJ SHAH'),
        keyBytes,
      )).value;

      final result = await repository.listAllSummaries();

      expect(result.isSuccess, isTrue);
      expect(result.value, [
        PanCardSummary(
          id: amitId,
          nameOnCard: 'AMIT SHAH',
          fathersName: 'RAJ SHAH',
        ),
        PanCardSummary(id: zuluId, nameOnCard: 'ZULU KHAN'),
      ]);
      expect(result.value.every((s) => s.id > 0), isTrue);
    });
  });

  group('update', () {
    test('re-encrypts PAN and updates plain fields by id', () async {
      final created = await repository.create(record(), keyBytes);
      final id = created.value;

      final updateResult = await repository.update(
        record(id: id, pan: 'PQRST9876U', name: 'JANE M DOE'),
        keyBytes,
      );

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getById(id, keyBytes);
      expect(fetched.value?.panNumber, 'PQRST9876U');
      expect(fetched.value?.nameOnCard, 'JANE M DOE');
    });

    test('preserves created_at during update', () async {
      final originalCreatedAt = DateTime(2026, 1, 2, 3, 4, 5);
      final replacementCreatedAt = DateTime(2026, 6, 7, 8, 9, 10);
      final id = (await repository.create(
        record(createdAt: originalCreatedAt),
        keyBytes,
      )).value;

      final updateResult = await repository.update(
        record(
          id: id,
          pan: 'PQRST9876U',
          name: 'JANE M DOE',
          createdAt: replacementCreatedAt,
        ),
        keyBytes,
      );

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getById(id, keyBytes);
      expect(
        fetched.value?.createdAt.millisecondsSinceEpoch,
        originalCreatedAt.millisecondsSinceEpoch,
      );
    });

    test('fails with ValidationFailure when record id is null', () async {
      final result = await repository.update(record(), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
    });

    test('fails with NotFoundFailure for an unknown id', () async {
      final result = await repository.update(record(id: 424242), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });

    test('preserves the card image blob on update', () async {
      final imageBytes = List<int>.generate(16, (i) => i);
      final withImage = record(cardImageBlob: imageBytes);
      final id = (await repository.create(withImage, keyBytes)).value;
      final beforeRows = await vaultDb.db.query(
        VaultTables.panCards,
        columns: const ['card_image_blob_enc'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final beforeBlobEnc = beforeRows.single['card_image_blob_enc'];

      await repository.update(record(id: id), keyBytes);

      final afterRows = await vaultDb.db.query(
        VaultTables.panCards,
        columns: const ['card_image_blob_enc'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final fetched = await repository.getById(id, keyBytes);
      expect(fetched.value?.cardImageBlob, imageBytes);
      expect(afterRows.single['card_image_blob_enc'], beforeBlobEnc);
    });
  });

  group('deleteById', () {
    test('removes the record', () async {
      final id = (await repository.create(record(), keyBytes)).value;

      final deleteResult = await repository.deleteById(id);

      expect(deleteResult.isSuccess, isTrue);
      expect((await repository.getById(id, keyBytes)).value, isNull);
    });

    test('fails with NotFoundFailure for an unknown id', () async {
      final result = await repository.deleteById(424242);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });
}
