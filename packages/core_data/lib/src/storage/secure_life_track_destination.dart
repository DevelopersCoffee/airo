import 'package:core_domain/core_domain.dart';

import '../secure/secure_storage.dart';
import 'encrypted_life_track_data_source.dart';
import 'life_track_local_data_source.dart';
import 'life_track_plaintext_migration.dart';

enum SecureLifeTrackWriteMode {
  encryptedWritable,
  plaintextReadOnly,
  unavailable,
}

/// Routes LifeTrack reads and writes across plaintext compatibility and the
/// encrypted destination.
class SecureLifeTrackDestination {
  SecureLifeTrackDestination({
    required LifeTrackLocalDataSource plaintext,
    required EncryptedLifeTrackDataSource encrypted,
    required EncryptionKeyManager keyManager,
    LifeTrackPlaintextMigration? migration,
  }) : _plaintext = plaintext,
       _encrypted = encrypted,
       _keyManager = keyManager,
       _migration = migration ??
           LifeTrackPlaintextMigration(
             plaintext: plaintext,
             encrypted: encrypted,
           );

  final LifeTrackLocalDataSource _plaintext;
  final EncryptedLifeTrackDataSource _encrypted;
  final EncryptionKeyManager _keyManager;
  final LifeTrackPlaintextMigration _migration;

  Future<SecureLifeTrackWriteMode> writeMode() async {
    if (await _keyManager.isEncryptionAvailable()) {
      if (!_encrypted.isInitialized) {
        final init = await _encrypted.initialize();
        if (init is Ok<void>) {
          return SecureLifeTrackWriteMode.encryptedWritable;
        }
      } else {
        return SecureLifeTrackWriteMode.encryptedWritable;
      }
    }

    await _plaintext.initialize();
    final tracks = await _plaintext.listTracks();
    if (tracks.isNotEmpty) {
      return SecureLifeTrackWriteMode.plaintextReadOnly;
    }
    return SecureLifeTrackWriteMode.unavailable;
  }

  Future<Result<LifeTrackMigrationReport>> migratePlaintext({
    required String plaintextBackupPath,
  }) => _migration.migrateIfNeeded(plaintextBackupPath: plaintextBackupPath);

  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack writes require encrypted storage',
        ),
        StackTrace.current,
      );
    }
    try {
      await _encrypted.store.createTrack(track);
      return Ok(track);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<LifeTrack>> getTrack(String id) async {
    if (_encrypted.isInitialized || await _tryInitializeEncrypted()) {
      final encryptedTrack = await _encrypted.store.getTrack(id);
      if (encryptedTrack != null) {
        return Ok(encryptedTrack);
      }
    }

    await _plaintext.initialize();
    final plaintextTrack = await _plaintext.getTrack(id);
    if (plaintextTrack == null) {
      return Err(
        NotFoundError('LifeTrack not found: $id'),
        StackTrace.current,
      );
    }
    return Ok(plaintextTrack);
  }

  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async {
    if (_encrypted.isInitialized || await _tryInitializeEncrypted()) {
      if (await _encrypted.isMigrationComplete()) {
        return Ok(await _encrypted.store.listTracks(status: status));
      }
    }

    await _plaintext.initialize();
    return Ok(await _plaintext.listTracks(status: status));
  }

  Future<Result<void>> updateTrack(LifeTrack track) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack writes require encrypted storage',
        ),
        StackTrace.current,
      );
    }
    try {
      await _encrypted.store.updateTrack(track);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<void>> deleteTrack(String id) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack writes require encrypted storage',
        ),
        StackTrace.current,
      );
    }
    try {
      await _encrypted.store.deleteTrack(id);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack writes require encrypted storage',
        ),
        StackTrace.current,
      );
    }
    try {
      await _encrypted.store.saveInputValue(requirementId, value);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return _readOnlyWriteFailure();
    }
    try {
      await _encrypted.store.updateItemStatus(itemId, status);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<void>> updateActionItem(ActionItem item) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return _readOnlyWriteFailure();
    }
    try {
      await _encrypted.store.updateActionItem(item);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<void>> updateMilestone(Milestone milestone) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return _readOnlyWriteFailure();
    }
    try {
      await _encrypted.store.updateMilestone(milestone);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Future<Result<LifeTrack>> hydrateTemplate(LifeTrack track) async {
    final mode = await writeMode();
    if (mode != SecureLifeTrackWriteMode.encryptedWritable) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack writes require encrypted storage',
        ),
        StackTrace.current,
      );
    }
    try {
      await _encrypted.store.hydrateTemplate(track);
      return Ok(track);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  Result<void> _readOnlyWriteFailure() => Err(
    SecureDestinationUnavailableError(
      'LifeTrack writes require encrypted storage',
    ),
    StackTrace.current,
  );

  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) async* {
    if (_encrypted.isInitialized) {
      yield await _encrypted.store.listTracks(status: status);
      yield* _encrypted.store.changes.asyncMap(
        (_) => _encrypted.store.listTracks(status: status),
      );
      return;
    }

    await _plaintext.initialize();
    yield await _plaintext.listTracks(status: status);
    yield* _plaintext.watchTracks(status: status);
  }

  Future<bool> _tryInitializeEncrypted() async {
    if (!await _keyManager.isEncryptionAvailable()) return false;
    final init = await _encrypted.initialize();
    return init is Ok<void>;
  }
}
