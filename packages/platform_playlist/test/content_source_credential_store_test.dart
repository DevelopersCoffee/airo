import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  late SecureStore secureStore;
  late ContentSourceCredentialStore store;

  setUp(() {
    secureStore = InMemorySecureStore();
    store = ContentSourceCredentialStore(secureStore);
  });

  test('save then read round-trips credentials', () async {
    const ref = ContentSourceCredentialRef('xtream-1');
    const credentials = ContentSourceCredentials(
      username: 'alice',
      password: 'hunter2',
    );

    await store.save(ref, credentials);
    final result = await store.read(ref);

    expect(result, credentials);
  });

  test('read returns null when nothing stored', () async {
    final result = await store.read(
      const ContentSourceCredentialRef('missing'),
    );
    expect(result, isNull);
  });

  test('delete removes both username and password', () async {
    const ref = ContentSourceCredentialRef('xtream-2');
    await store.save(
      ref,
      const ContentSourceCredentials(username: 'bob', password: 'secret'),
    );

    await store.delete(ref);
    final result = await store.read(ref);

    expect(result, isNull);
  });

  test('different refs do not collide', () async {
    const refA = ContentSourceCredentialRef('a');
    const refB = ContentSourceCredentialRef('b');
    await store.save(
      refA,
      const ContentSourceCredentials(username: 'a-user', password: 'a-pass'),
    );
    await store.save(
      refB,
      const ContentSourceCredentials(username: 'b-user', password: 'b-pass'),
    );

    expect((await store.read(refA))?.username, 'a-user');
    expect((await store.read(refB))?.username, 'b-user');
  });

  test('ContentSourceCredentials.toString never leaks the password', () {
    const credentials = ContentSourceCredentials(
      username: 'alice',
      password: 'hunter2',
    );
    expect(credentials.toString(), isNot(contains('hunter2')));
  });
}
