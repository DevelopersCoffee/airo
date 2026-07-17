import 'package:feature_iptv/application/providers/content_source_management_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_data/core_data.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
    );
  }

  test('configuredContentSourcesProvider is empty with nothing configured', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    final sources = await container.read(configuredContentSourcesProvider.future);

    expect(sources, isEmpty);
  });

  test('addM3uContentSourceProvider then configuredContentSourcesProvider round-trips', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await container.read(
      addM3uContentSourceProvider((label: 'My Playlist', url: 'https://example.com/playlist.m3u')).future,
    );
    final sources = await container.read(configuredContentSourcesProvider.future);

    expect(sources, hasLength(1));
    expect(sources.single.label, 'My Playlist');
    expect(sources.single.kind, ContentSourceKind.m3u);
  });

  test('removeContentSourceProvider removes the source and its stored credential', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(
      addM3uContentSourceProvider((label: 'My Playlist', url: 'https://example.com/playlist.m3u')).future,
    );
    final id = (await container.read(configuredContentSourcesProvider.future)).single.id;
    await container.read(contentSourceCredentialStoreProvider).save(
      ContentSourceCredentialRef(id),
      const ContentSourceCredentials(username: 'u', password: 'p'),
    );

    await container.read(removeContentSourceProvider(id).future);

    final sources = await container.read(configuredContentSourcesProvider.future);
    expect(sources, isEmpty);
    final credential = await container.read(contentSourceCredentialStoreProvider).read(ContentSourceCredentialRef(id));
    expect(credential, isNull);
  });
}
