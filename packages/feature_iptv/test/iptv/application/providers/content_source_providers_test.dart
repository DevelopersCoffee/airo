import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/providers/content_source_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  test('contentSourceCredentialStoreProvider builds a working store', () async {
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
    );
    addTearDown(container.dispose);

    final store = container.read(contentSourceCredentialStoreProvider);
    const ref = ContentSourceCredentialRef('test-source');
    await store.save(
      ref,
      const ContentSourceCredentials(username: 'u', password: 'p'),
    );

    final result = await store.read(ref);
    expect(result?.username, 'u');
  });
}
