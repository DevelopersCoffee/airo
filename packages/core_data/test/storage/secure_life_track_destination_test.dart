import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../storage/life_track_local_data_source_test.dart' show sampleTrack;

class _UnavailableEncryptionKeyManager implements EncryptionKeyManager {
  @override
  Future<Result<List<int>>> getDatabaseKey() async =>
      Err(SecureDestinationUnavailableError('no key'), StackTrace.current);

  @override
  Future<Result<void>> rotateKey() async => const Ok(null);

  @override
  Future<bool> isEncryptionAvailable() async => false;

  @override
  Future<Result<void>> clearKeys() async => const Ok(null);
}

String uniqueMemoryPath(String label) =>
    '${inMemoryDatabasePath}_${label}_${DateTime.now().microsecondsSinceEpoch}';

void main() {
  late DatabaseFactory databaseFactory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration copies plaintext rows with matching counts and fingerprints',
      () async {
    final plaintext = LifeTrackLocalDataSource(
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('plaintext'),
    );
    final encryptedDb = SqfliteEncryptedDatabase(
      keyManager: InMemoryEncryptionKeyManager(),
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('secure'),
    );
    final encrypted = EncryptedLifeTrackDataSource(database: encryptedDb);
    final migration = LifeTrackPlaintextMigration(
      plaintext: plaintext,
      encrypted: encrypted,
    );

    await plaintext.initialize();
    final track = sampleTrack();
    await plaintext.createTrack(track);

    final result = await migration.migrateIfNeeded(
      plaintextBackupPath: '/tmp/life_track.db',
    );
    expect(result, isA<Ok<LifeTrackMigrationReport>>());
    final report = (result as Ok<LifeTrackMigrationReport>).value;
    expect(report.verified, isTrue);
    expect(report.trackCount, 1);
    expect(report.milestoneCount, 2);
    expect(report.actionItemCount, 4);
    expect(report.requirementCount, 1);

    final migrated = await encrypted.store.getTrack(track.id);
    expect(migrated, track);

    await plaintext.close();
    await encrypted.close();
  });

  test('secure destination rejects writes when encryption is unavailable', () async {
    final plaintext = LifeTrackLocalDataSource(
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('plaintext_ro'),
    );
    final encryptedDb = SqfliteEncryptedDatabase(
      keyManager: _UnavailableEncryptionKeyManager(),
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('secure_ro'),
    );
    final encrypted = EncryptedLifeTrackDataSource(database: encryptedDb);
    final destination = SecureLifeTrackDestination(
      plaintext: plaintext,
      encrypted: encrypted,
      keyManager: _UnavailableEncryptionKeyManager(),
    );

    await plaintext.initialize();
    await plaintext.createTrack(sampleTrack(id: 'legacy-track'));

    final writeResult = await destination.createTrack(sampleTrack(id: 'new'));
    expect(writeResult, isA<Err<LifeTrack>>());
    expect(
      (writeResult as Err<LifeTrack>).error,
      isA<SecureDestinationUnavailableError>(),
    );

    final readResult = await destination.getTrack('legacy-track');
    expect(readResult, isA<Ok<LifeTrack>>());

    await plaintext.close();
    await encrypted.close();
  });

  test('idempotency store records begin and commit in encrypted database', () async {
    final encryptedDb = SqfliteEncryptedDatabase(
      keyManager: InMemoryEncryptionKeyManager(),
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('idem'),
    );
    final encrypted = EncryptedLifeTrackDataSource(database: encryptedDb);
    await encrypted.initialize();

    final store = LifeTrackIdempotencyStore(encrypted);
    final idempotencyKey = 'idem-${DateTime.now().microsecondsSinceEpoch}';
    final begin = await store.beginEffect(
      idempotencyKey: idempotencyKey,
      confirmationHash: 'hash-1',
      resourceId: 'track-1',
    );
    expect(begin, isA<Ok<IdempotentEffectRecord>>());
    expect(
      (begin as Ok<IdempotentEffectRecord>).value.state,
      IdempotentEffectState.pending,
    );

    final commit = await store.commitEffect(
      idempotencyKey: idempotencyKey,
      destinationReceipt: 'receipt-1',
    );
    expect(commit, isA<Ok<void>>());

    final loaded = await store.findByKey(idempotencyKey);
    expect(loaded, isA<Ok<IdempotentEffectRecord?>>());
    final record = (loaded as Ok<IdempotentEffectRecord?>).value!;
    expect(record.state, IdempotentEffectState.committed);
    expect(record.destinationReceipt, 'receipt-1');

    await encrypted.close();
  });

  test('key rotation allows re-initialization after rotateKey', () async {
    final keyManager = InMemoryEncryptionKeyManager();
    final encryptedDb = SqfliteEncryptedDatabase(
      keyManager: keyManager,
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('rotate'),
    );
    final encrypted = EncryptedLifeTrackDataSource(database: encryptedDb);
    await encrypted.initialize();
    await encrypted.store.createTrack(sampleTrack(id: 'rotate-track'));

    final rotate = await keyManager.rotateKey();
    expect(rotate, isA<Ok<void>>());

    await encrypted.close();
    final reinit = await encrypted.initialize();
    expect(reinit, isA<Ok<void>>());
    final rotated = await encrypted.store.getTrack('rotate-track');
    expect(rotated, isNotNull);

    await encrypted.close();
  });
}
