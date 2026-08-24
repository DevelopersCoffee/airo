import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../storage/life_track_local_data_source_test.dart' show sampleTrack;
import 'secure_life_track_destination_test.dart' show uniqueMemoryPath;

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

void main() {
  late DatabaseFactory databaseFactory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('open enables encrypted writes and idempotency', () async {
    final plaintext = LifeTrackLocalDataSource(
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('stack-plain'),
    );
    final stack = await LifeTrackSecureStack.open(
      plaintext: plaintext,
      keyManager: InMemoryEncryptionKeyManager(),
      databaseFactory: databaseFactory,
      encryptedDatabasePath: uniqueMemoryPath('stack-enc'),
      plaintextBackupPath: uniqueMemoryPath('stack-backup'),
    );

    expect(await stack.canWrite(), isTrue);
    expect(stack.idempotencyPort, isNotNull);

    final track = sampleTrack();
    final created = await stack.repository.createTrack(track);
    expect(created, isA<Ok<LifeTrack>>());

    await stack.close();
  });

  test('open without encryption fails closed for writes', () async {
    final plaintext = LifeTrackLocalDataSource(
      databaseFactory: databaseFactory,
      databasePath: uniqueMemoryPath('stack-plain-ro'),
    );
    final stack = await LifeTrackSecureStack.open(
      plaintext: plaintext,
      keyManager: _UnavailableEncryptionKeyManager(),
      databaseFactory: databaseFactory,
      encryptedDatabasePath: uniqueMemoryPath('stack-enc-ro'),
      plaintextBackupPath: uniqueMemoryPath('stack-backup-ro'),
    );

    expect(await stack.canWrite(), isFalse);
    expect(stack.idempotencyPort, isNull);

    final result = await stack.repository.createTrack(sampleTrack());
    expect(result, isA<Err<LifeTrack>>());

    await stack.close();
  });
}
