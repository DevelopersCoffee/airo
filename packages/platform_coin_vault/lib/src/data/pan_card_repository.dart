import 'package:core_domain/core_domain.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/pan_card_record.dart';
import 'vault_database.dart';

class PanCardRepository {
  PanCardRepository({required VaultDatabase database, required FieldCipher fieldCipher})
    : _database = database,
      _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(PanCardRecord record, List<int> keyBytes) async {
    try {
      late int id;
      await _database.db.transaction((txn) async {
        id = await txn.insert(VaultTables.panCards, {
          'pan_number_enc': '',
          'name_on_card': record.nameOnCard,
          'fathers_name': record.fathersName,
          'date_of_birth': record.dateOfBirth?.millisecondsSinceEpoch,
          'card_image_blob_enc': null,
          'created_at': record.createdAt.millisecondsSinceEpoch,
        });

        final panNumberEnc = await _fieldCipher.encryptField(
          record.panNumber,
          keyBytes,
          context: '${VaultTables.panCards}:pan_number_enc:$id',
        );
        final cardImageBlobEnc = record.cardImageBlob == null
            ? null
            : await _fieldCipher.encryptField(
                String.fromCharCodes(record.cardImageBlob!),
                keyBytes,
                context: '${VaultTables.panCards}:card_image_blob_enc:$id',
              );

        await txn.update(
          VaultTables.panCards,
          {'pan_number_enc': panNumberEnc, 'card_image_blob_enc': cardImageBlobEnc},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

      return Success(id);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create PAN card', cause: e));
    }
  }

  Future<Result<PanCardRecord?>> getById(int id, List<int> keyBytes) async {
    try {
      final rows = await _database.db.query(
        VaultTables.panCards,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      final panNumber = await _fieldCipher.decryptField(
        row['pan_number_enc'] as String,
        keyBytes,
        context: '${VaultTables.panCards}:pan_number_enc:$id',
      );
      final dob = row['date_of_birth'] as int?;
      final blobEnc = row['card_image_blob_enc'] as String?;

      return Success(PanCardRecord(
        id: row['id'] as int,
        panNumber: panNumber,
        nameOnCard: row['name_on_card'] as String,
        fathersName: row['fathers_name'] as String?,
        dateOfBirth: dob == null ? null : DateTime.fromMillisecondsSinceEpoch(dob),
        cardImageBlob: blobEnc == null
            ? null
            : (await _fieldCipher.decryptField(
                blobEnc,
                keyBytes,
                context: '${VaultTables.panCards}:card_image_blob_enc:$id',
              )).codeUnits,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read PAN card', cause: e));
    }
  }
}
