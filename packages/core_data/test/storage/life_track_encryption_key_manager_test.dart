import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates and reuses a stable database key', () async {
    final store = InMemorySecureStore();
    final manager = LifeTrackEncryptionKeyManager(secureStore: store);

    final first = await manager.getDatabaseKey();
    expect(first, isA<Ok<List<int>>>());
    expect((first as Ok<List<int>>).value.length, 32);

    final second = await manager.getDatabaseKey();
    expect((second as Ok<List<int>>).value, (first as Ok<List<int>>).value);
  });

  test('rotateKey replaces the cached key', () async {
    final store = InMemorySecureStore();
    final manager = LifeTrackEncryptionKeyManager(secureStore: store);

    final before = (await manager.getDatabaseKey() as Ok<List<int>>).value;
    await manager.rotateKey();
    final after = (await manager.getDatabaseKey() as Ok<List<int>>).value;

    expect(after, isNot(equals(before)));
  });

  test('isEncryptionAvailable probes secure store', () async {
    final manager = LifeTrackEncryptionKeyManager(
      secureStore: InMemorySecureStore(),
    );
    expect(await manager.isEncryptionAvailable(), isTrue);
  });
}
