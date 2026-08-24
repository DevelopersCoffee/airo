import 'package:core_domain/core_domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../repositories/secure_life_track_repository_impl.dart';
import '../secure/secure_storage.dart';
import '../secure/sqflite_encrypted_database.dart';
import 'encrypted_life_track_data_source.dart';
import 'life_track_encryption_key_manager.dart';
import 'life_track_idempotency_store.dart';
import 'life_track_local_data_source.dart';
import 'life_track_plaintext_migration.dart';
import 'secure_life_track_destination.dart';

/// Opens the encrypted LifeTrack destination and optional idempotency store.
class LifeTrackSecureStack {
  LifeTrackSecureStack._({
    required this.destination,
    required this.repository,
    required this.plaintext,
    required this.encrypted,
    this.idempotencyPort,
  });

  final SecureLifeTrackDestination destination;
  final LifeTrackRepository repository;
  final LifeTrackLocalDataSource plaintext;
  final EncryptedLifeTrackDataSource encrypted;
  final IdempotentEffectPort? idempotencyPort;

  static Future<LifeTrackSecureStack> open({
    LifeTrackLocalDataSource? plaintext,
    EncryptionKeyManager? keyManager,
    DatabaseFactory? databaseFactory,
    String? encryptedDatabasePath,
    String? plaintextBackupPath,
  }) async {
    final plain =
        plaintext ??
        LifeTrackLocalDataSource(databaseFactory: databaseFactory);
    final manager = keyManager ?? LifeTrackEncryptionKeyManager();
    final encDb = SqfliteEncryptedDatabase(
      keyManager: manager,
      databaseFactory: databaseFactory,
      databasePath: encryptedDatabasePath,
    );
    final encrypted = EncryptedLifeTrackDataSource(database: encDb);
    final destination = SecureLifeTrackDestination(
      plaintext: plain,
      encrypted: encrypted,
      keyManager: manager,
    );

    final mode = await destination.writeMode();
    IdempotentEffectPort? idempotencyPort;
    if (mode == SecureLifeTrackWriteMode.encryptedWritable) {
      final init = await encrypted.initialize();
      if (init is Ok<void>) {
        final backup =
            plaintextBackupPath ?? await _defaultPlaintextBackupPath();
        final migration = await destination.migratePlaintext(
          plaintextBackupPath: backup,
        );
        if (migration is Ok<LifeTrackMigrationReport>) {
          idempotencyPort = LifeTrackIdempotencyStore(encrypted);
        }
      }
    } else {
      await plain.initialize();
    }

    return LifeTrackSecureStack._(
      destination: destination,
      repository: SecureLifeTrackRepositoryImpl(destination: destination),
      plaintext: plain,
      encrypted: encrypted,
      idempotencyPort: idempotencyPort,
    );
  }

  Future<bool> canWrite() async =>
      (await destination.writeMode()) ==
      SecureLifeTrackWriteMode.encryptedWritable;

  Future<void> close() async {
    await encrypted.close();
    await plaintext.close();
  }

  static Future<String> _defaultPlaintextBackupPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'life_track_plaintext_backup.marker');
  }
}
