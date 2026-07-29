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
        xtreamAuthenticatorProvider.overrideWithValue(
          ({
            required String serverUrl,
            required String username,
            required String password,
          }) async => const XtreamAuthResult(
            isAuthenticated: true,
            status: 'Active',
            maxConnections: 2,
          ),
        ),
      ],
    );
  }

  test(
    'configuredContentSourcesProvider is empty with nothing configured',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );

      expect(sources, isEmpty);
    },
  );

  test(
    'addM3uContentSourceProvider then configuredContentSourcesProvider round-trips',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      await container.read(
        addM3uContentSourceProvider((
          label: 'My Playlist',
          url: 'https://example.com/playlist.m3u',
        )).future,
      );
      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );

      expect(sources, hasLength(1));
      expect(sources.single.label, 'My Playlist');
      expect(sources.single.kind, ContentSourceKind.m3u);
    },
  );

  test('addM3uContentSourceProvider rejects a duplicate URL', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    const source = (label: 'First', url: 'https://example.com/playlist.m3u');

    await container.read(addM3uContentSourceProvider(source).future);

    await expectLater(
      container.read(
        addM3uContentSourceProvider((
          label: 'Duplicate',
          url: source.url,
        )).future,
      ),
      throwsA(isA<DuplicatePlaylistSourceException>()),
    );
    expect(
      await container.read(configuredContentSourcesProvider.future),
      hasLength(1),
    );
  });

  test('addXtreamContentSourceProvider persists config + credential', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await container.read(
      addXtreamContentSourceProvider((
        label: 'My Xtream',
        url: 'https://xtream.example.com',
        username: 'u1',
        password: 'p1',
      )).future,
    );

    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );
    expect(sources, hasLength(1));
    final config = sources.single;
    expect(config.kind, ContentSourceKind.xtream);
    expect(config.label, 'My Xtream');
    expect(config.url, 'https://xtream.example.com');
    expect(config.id, startsWith('xtream-'));
    expect(config.accountStatus, 'Active');
    expect(config.maxConnections, 2);

    final credential = await container
        .read(contentSourceCredentialStoreProvider)
        .read(ContentSourceCredentialRef(config.id));
    expect(credential, isNotNull);
    expect(credential!.username, 'u1');
    expect(credential.password, 'p1');
  });

  test('rejected Xtream credentials persist no config or secret', () async {
    final prefs = await SharedPreferences.getInstance();
    final secureStore = InMemorySecureStore();
    var authenticationAttempts = 0;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(secureStore),
        xtreamAuthenticatorProvider.overrideWithValue(({
          required String serverUrl,
          required String username,
          required String password,
        }) async {
          authenticationAttempts++;
          return const XtreamAuthResult(
            isAuthenticated: false,
            status: 'Disabled',
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(
        addXtreamContentSourceProvider((
          label: 'Rejected',
          url: 'https://xtream.example.com',
          username: 'secret-user',
          password: 'secret-pass',
        )).future,
      ),
      throwsA(isA<XtreamAuthenticationException>()),
    );
    expect(
      await container.read(configuredContentSourcesProvider.future),
      isEmpty,
    );
    expect(authenticationAttempts, 1);
  });

  test(
    'addStalkerContentSourceProvider persists config with macAddress, no credential',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      await container.read(
        addStalkerContentSourceProvider((
          label: 'My Portal',
          url: 'https://stalker.example.com',
          macAddress: 'AA:BB:CC:DD:EE:FF',
        )).future,
      );

      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );
      expect(sources, hasLength(1));
      final config = sources.single;
      expect(config.kind, ContentSourceKind.stalker);
      expect(config.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(config.id, startsWith('stalker-'));

      final credential = await container
          .read(contentSourceCredentialStoreProvider)
          .read(ContentSourceCredentialRef(config.id));
      expect(credential, isNull);
    },
  );

  test(
    'addJellyfinContentSourceProvider persists config + credential',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      await container.read(
        addJellyfinContentSourceProvider((
          label: 'Home Jellyfin',
          url: 'https://jellyfin.example.com',
          username: 'admin',
          password: 'api-key-xyz',
        )).future,
      );

      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );
      expect(sources, hasLength(1));
      final config = sources.single;
      expect(config.kind, ContentSourceKind.jellyfin);
      expect(config.id, startsWith('jellyfin-'));

      final credential = await container
          .read(contentSourceCredentialStoreProvider)
          .read(ContentSourceCredentialRef(config.id));
      expect(credential, isNotNull);
      expect(credential!.username, 'admin');
      expect(credential.password, 'api-key-xyz');
    },
  );

  test(
    'removeContentSourceProvider removes the source and its stored credential',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await container.read(
        addM3uContentSourceProvider((
          label: 'My Playlist',
          url: 'https://example.com/playlist.m3u',
        )).future,
      );
      final id = (await container.read(
        configuredContentSourcesProvider.future,
      )).single.id;
      await container
          .read(contentSourceCredentialStoreProvider)
          .save(
            ContentSourceCredentialRef(id),
            const ContentSourceCredentials(username: 'u', password: 'p'),
          );

      await container.read(removeContentSourceProvider(id).future);

      final sources = await container.read(
        configuredContentSourcesProvider.future,
      );
      expect(sources, isEmpty);
      final credential = await container
          .read(contentSourceCredentialStoreProvider)
          .read(ContentSourceCredentialRef(id));
      expect(credential, isNull);
    },
  );

  test('removing a migrated legacy playlist prevents remigration', () async {
    const legacyUrl = 'https://iptv-org.github.io/iptv/index.m3u';
    SharedPreferences.setMockInitialValues({
      'iptv_user_playlist_url': legacyUrl,
    });
    final container = await buildContainer();
    addTearDown(container.dispose);
    final migrated = await container.read(
      configuredContentSourcesProvider.future,
    );

    await container.read(
      removeContentSourceProvider(migrated.single.id).future,
    );
    final sources = await container.read(
      configuredContentSourcesProvider.future,
    );

    expect(sources, isEmpty);
    expect(container.read(m3uParserProvider).getPlaylistUrl(), isNull);
  });
}
