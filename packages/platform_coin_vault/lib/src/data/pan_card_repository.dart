import 'package:core_domain/core_domain.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/pan_card_record.dart';
import '../domain/entities/vault_entry_summary.dart';
import 'vault_database.dart';

class PanCardRepository {
  PanCardRepository({
    required VaultDatabase database,
    required FieldCipher fieldCipher,
  }) : _database = database,
       _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(PanCardRecord record, List<int> keyBytes) async {
    try {
      final panNumberEnc = await _fieldCipher.encryptField(
        record.panNumber,
        keyBytes,
      );
      final id = await _database.db.insert(VaultTables.panCards, {
        'pan_number_enc': panNumberEnc,
        'name_on_card': record.nameOnCard,
        'fathers_name': record.fathersName,
        'date_of_birth': record.dateOfBirth?.millisecondsSinceEpoch,
        'card_image_blob_enc': record.cardImageBlob == null
            ? null
            : await _fieldCipher.encryptField(
                String.fromCharCodes(record.cardImageBlob!),
                keyBytes,
              ),
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
      return Success(id);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to create PAN card', cause: e),
      );
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
      );
      final dob = row['date_of_birth'] as int?;
      final blobEnc = row['card_image_blob_enc'] as String?;

      return Success(
        PanCardRecord(
          id: row['id'] as int,
          panNumber: panNumber,
          nameOnCard: row['name_on_card'] as String,
          fathersName: row['fathers_name'] as String?,
          dateOfBirth: dob == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(dob),
          cardImageBlob: blobEnc == null
              ? null
              : (await _fieldCipher.decryptField(blobEnc, keyBytes)).codeUnits,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
        ),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to read PAN card', cause: e),
      );
    }
  }

  /// Lists all PAN cards as key-free summaries (unencrypted columns only).
  Future<Result<List<PanCardSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.panCards,
        columns: const ['id', 'name_on_card', 'fathers_name'],
        orderBy: 'name_on_card ASC',
      );
      return Success([
        for (final row in rows)
          PanCardSummary(
            id: row['id'] as int,
            nameOnCard: row['name_on_card'] as String,
            fathersName: row['fathers_name'] as String?,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list PAN cards', cause: e),
      );
    }
  }

  /// Updates the row identified by [PanCardRecord.id]. `card_image_blob_enc`
  /// and `created_at` are left untouched.
  Future<Result<void>> update(PanCardRecord record, List<int> keyBytes) async {
    final id = record.id;
    if (id == null) {
      return const Failure(
        ValidationFailure(
          message: 'A stored PAN card record must have an id to update',
          field: 'id',
        ),
      );
    }
    try {
      final panNumberEnc = await _fieldCipher.encryptField(
        record.panNumber,
        keyBytes,
      );
      final count = await _database.db.update(
        VaultTables.panCards,
        {
          'pan_number_enc': panNumberEnc,
          'name_on_card': record.nameOnCard,
          'fathers_name': record.fathersName,
          'date_of_birth': record.dateOfBirth?.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        return Failure(
          NotFoundFailure(
            message: 'No PAN card with id $id',
            resourceType: 'PanCardRecord',
            resourceId: '$id',
          ),
        );
      }
      return const Success<void>(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update PAN card', cause: e),
      );
    }
  }

  Future<Result<void>> deleteById(int id) async {
    try {
      final count = await _database.db.delete(
        VaultTables.panCards,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        return Failure(
          NotFoundFailure(
            message: 'No PAN card with id $id',
            resourceType: 'PanCardRecord',
            resourceId: '$id',
          ),
        );
      }
      return const Success<void>(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete PAN card', cause: e),
      );
    }
  }
}
