import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import 'encrypted_life_track_data_source.dart';
import 'life_track_sql_schema.dart';

/// Persists idempotent effect records in the encrypted LifeTrack database.
class LifeTrackIdempotencyStore implements IdempotentEffectPort {
  LifeTrackIdempotencyStore(this._dataSource);

  final EncryptedLifeTrackDataSource _dataSource;

  Database get _db => _dataSource.database;

  @override
  Future<Result<IdempotentEffectRecord?>> findByKey(String idempotencyKey) async {
    try {
      final rows = await _db.query(
        LifeTrackSqlSchema.idempotentEffectsTable,
        where: 'idempotency_key = ?',
        whereArgs: [idempotencyKey],
        limit: 1,
      );
      if (rows.isEmpty) return const Ok(null);
      return Ok(_map(rows.single));
    } catch (error, stack) {
      return Err(StorageError('idempotency lookup failed: $error'), stack);
    }
  }

  @override
  Future<Result<IdempotentEffectRecord>> beginEffect({
    required String idempotencyKey,
    required String confirmationHash,
    required String resourceId,
  }) async {
    try {
      final existing = await findByKey(idempotencyKey);
      if (existing is Ok<IdempotentEffectRecord?> && existing.value != null) {
        return Ok(existing.value!);
      }

      final now = DateTime.now().toUtc();
      final record = IdempotentEffectRecord(
        idempotencyKey: idempotencyKey,
        confirmationHash: confirmationHash,
        state: IdempotentEffectState.pending,
        resourceId: resourceId,
        createdAt: now,
        updatedAt: now,
      );

      await _db.insert(
        LifeTrackSqlSchema.idempotentEffectsTable,
        _toRow(record),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return Ok(record);
    } catch (error, stack) {
      return Err(StorageError('idempotency begin failed: $error'), stack);
    }
  }

  @override
  Future<Result<void>> commitEffect({
    required String idempotencyKey,
    required String destinationReceipt,
  }) async {
    try {
      final updated = await _db.update(
        LifeTrackSqlSchema.idempotentEffectsTable,
        {
          'effect_state': IdempotentEffectState.committed.name,
          'destination_receipt': destinationReceipt,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'idempotency_key = ?',
        whereArgs: [idempotencyKey],
      );
      if (updated == 0) {
        return Err(
          NotFoundError('Idempotent effect not found: $idempotencyKey'),
          StackTrace.current,
        );
      }
      return const Ok(null);
    } catch (error, stack) {
      return Err(StorageError('idempotency commit failed: $error'), stack);
    }
  }

  @override
  Future<Result<void>> markFailed(String idempotencyKey) async {
    try {
      final updated = await _db.update(
        LifeTrackSqlSchema.idempotentEffectsTable,
        {
          'effect_state': IdempotentEffectState.failed.name,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'idempotency_key = ?',
        whereArgs: [idempotencyKey],
      );
      if (updated == 0) {
        return Err(
          NotFoundError('Idempotent effect not found: $idempotencyKey'),
          StackTrace.current,
        );
      }
      return const Ok(null);
    } catch (error, stack) {
      return Err(StorageError('idempotency mark failed failed: $error'), stack);
    }
  }

  IdempotentEffectRecord _map(Map<String, Object?> row) => IdempotentEffectRecord(
    idempotencyKey: row['idempotency_key']! as String,
    confirmationHash: row['confirmation_hash']! as String,
    state: IdempotentEffectState.fromJson(row['effect_state']! as String),
    resourceId: row['resource_id']! as String,
    destinationReceipt: row['destination_receipt'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
  );

  Map<String, Object?> _toRow(IdempotentEffectRecord record) => {
    'idempotency_key': record.idempotencyKey,
    'confirmation_hash': record.confirmationHash,
    'effect_state': record.state.name,
    'destination_receipt': record.destinationReceipt,
    'resource_id': record.resourceId,
    'created_at': record.createdAt.millisecondsSinceEpoch,
    'updated_at': record.updatedAt.millisecondsSinceEpoch,
  };
}
