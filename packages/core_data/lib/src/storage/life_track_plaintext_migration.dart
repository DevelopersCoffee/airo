import 'dart:convert';

import 'package:core_domain/core_domain.dart';

import 'encrypted_life_track_data_source.dart';
import 'life_track_graph_sql_store.dart';
import 'life_track_local_data_source.dart';
import 'life_track_sql_schema.dart';

class LifeTrackMigrationReport {
  const LifeTrackMigrationReport({
    required this.trackCount,
    required this.milestoneCount,
    required this.actionItemCount,
    required this.requirementCount,
    required this.verified,
    required this.plaintextBackupPath,
  });

  final int trackCount;
  final int milestoneCount;
  final int actionItemCount;
  final int requirementCount;
  final bool verified;
  final String plaintextBackupPath;
}

/// Copies plaintext LifeTrack rows into the encrypted destination in one
/// verifiable transaction. Plaintext data is retained for rollback.
class LifeTrackPlaintextMigration {
  LifeTrackPlaintextMigration({
    required LifeTrackLocalDataSource plaintext,
    required EncryptedLifeTrackDataSource encrypted,
  }) : _plaintext = plaintext,
       _encrypted = encrypted;

  final LifeTrackLocalDataSource _plaintext;
  final EncryptedLifeTrackDataSource _encrypted;

  Future<Result<LifeTrackMigrationReport>> migrateIfNeeded({
    required String plaintextBackupPath,
  }) async {
    if (await _encrypted.isMigrationComplete()) {
      return Ok(
        LifeTrackMigrationReport(
          trackCount: 0,
          milestoneCount: 0,
          actionItemCount: 0,
          requirementCount: 0,
          verified: true,
          plaintextBackupPath: plaintextBackupPath,
        ),
      );
    }

    try {
      await _plaintext.initialize();
      final initResult = await _encrypted.initialize();
      if (initResult case Err<void>(error: final error, stack: final stack)) {
        return Err(error, stack);
      }

      final tracks = await _plaintext.listTracks();
      final plaintextCounts = await _plaintext.rowCounts();

      await _encrypted.database.transaction((txn) async {
        final store = LifeTrackGraphSqlStore(txn);
        for (final track in tracks) {
          await store.createTrack(track);
        }
      });

      final encryptedStore = _encrypted.store;
      final encryptedCounts = {
        'tracks': await encryptedStore.countRows(
          LifeTrackSqlSchema.lifeTracksTable,
        ),
        'milestones': await encryptedStore.countRows(
          LifeTrackSqlSchema.milestonesTable,
        ),
        'action_items': await encryptedStore.countRows(
          LifeTrackSqlSchema.actionItemsTable,
        ),
        'requirements': await encryptedStore.countRows(
          LifeTrackSqlSchema.inputRequirementsTable,
        ),
      };

      final countsMatch =
          plaintextCounts['tracks'] == encryptedCounts['tracks'] &&
          plaintextCounts['milestones'] == encryptedCounts['milestones'] &&
          plaintextCounts['action_items'] == encryptedCounts['action_items'] &&
          plaintextCounts['requirements'] == encryptedCounts['requirements'];

      final verified = countsMatch && await _verifyTracks(tracks);

      if (!verified) {
        return Err(
          StorageError('LifeTrack migration verification failed'),
          StackTrace.current,
        );
      }

      await _encrypted.writeMeta(
        LifeTrackSqlSchema.metaKeyPlaintextBackupPath,
        plaintextBackupPath,
      );
      await _encrypted.writeMeta(
        LifeTrackSqlSchema.metaKeyMigrationComplete,
        'true',
      );

      return Ok(
        LifeTrackMigrationReport(
          trackCount: encryptedCounts['tracks']!,
          milestoneCount: encryptedCounts['milestones']!,
          actionItemCount: encryptedCounts['action_items']!,
          requirementCount: encryptedCounts['requirements']!,
          verified: verified,
          plaintextBackupPath: plaintextBackupPath,
        ),
      );
    } catch (error, stack) {
      return Err(StorageError('LifeTrack migration failed: $error'), stack);
    }
  }

  Future<bool> _verifyTracks(List<LifeTrack> sourceTracks) async {
    for (final source in sourceTracks) {
      final migrated = await _encrypted.store.getTrack(source.id);
      if (migrated == null) return false;
      if (_fingerprint(source) != _fingerprint(migrated)) return false;
      if (migrated != source) return false;
    }
    return true;
  }

  String _fingerprint(LifeTrack track) => jsonEncode(track.toJson());
}
