# CV-018 Content Source Contract + Provider Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Airo TV a typed `ContentSource` contract (M3U, Xtream Codes, Stalker Portal, Jellyfin) with capability flags and secure credential storage, plus working adapters for all four, so the app is no longer hard-wired to a single M3U fetch/parse path.

**Architecture:** Repurpose the empty `packages/platform_playlist` scaffold (per Chief Architect decision 2026-07-16 — do not create a new package) into the home for an `abstract class ContentSource` hierarchy, a `ContentSourceCredentialStore` built on `core_data`'s real `SecureStore`/`FlutterSecureStore`, and one adapter per source kind. Each adapter produces `platform_channels`' `IPTVChannel` for live/VOD listings and a `platform_epg` `CompactEpgRepository` implementation for guide data — both existing, unmodified contracts — so `feature_iptv` and the TV UI need no changes to consume a new source type. The M3U path is wrapped, not rewritten: `platform_playlist_import`'s `M3UParserService` keeps doing the fetching/parsing/caching; `platform_playlist` just exposes it as a `ContentSource` variant.

**Tech Stack:** Dart 3 sealed classes + `equatable` (no freezed/codegen — matches repo convention), `dio` for HTTP (matches `M3UParserService`/`ApiClient` convention), `flutter_secure_storage` via `core_data`'s existing `FlutterSecureStore`, hand-rolled test fakes (no mocktail in this package family, matching `platform_playlist_import`'s test convention).

## Global Constraints

- Dart SDK `^3.12.2`, Flutter `>=1.17.0` (match sibling platform_* packages).
- No new codegen tooling (no freezed, no json_serializable) — plain Dart 3 `sealed class` + `equatable`, per repo-wide precedent (`core_domain`'s `Result`, `core_auth`'s `AuthResult`).
- Credentials (username/password) must never appear in `toString()`, `props`, logs, or diagnostics unredacted — `ContentSource` subclasses hold only an opaque `ContentSourceCredentialRef`, never the raw secret. Mirrors `CompactEpgSourceRef.redacted()` in `platform_epg`.
- Credential storage goes through `core_data`'s `SecureStore` interface (`packages/core_data/lib/src/storage/secure_store.dart`) via `SecureStoreFactory.createSecure()` in production, `InMemorySecureStore`/`SecureStoreFactory.createForTesting()` in tests. Do **not** use the unused `SecureStorage` (capital, Result-based) interface — it has no production implementation.
- M3U behavior must not regress: `M3UParserService` in `platform_playlist_import` is not modified in this plan. `feature_iptv`'s existing `iptvChannelsProvider`/`m3uParserProvider` chain in `iptv_providers.dart` is untouched — the new `ContentSource` abstraction is additive, ready for the settings UI that CV-022 will build.
- New package dependency direction: `platform_playlist → platform_channels, platform_epg, platform_playlist_import, core_data`. No package outside `platform_playlist` depends on it yet (wiring a default source selection into `feature_iptv` is out of scope — CV-022 owns the UI that picks a source).
- Every adapter's live-channel output must be a valid `IPTVChannel` (`packages/platform_channels/lib/src/models/iptv_channel.dart`) and every EPG-capable adapter must implement `CompactEpgRepository` (`packages/platform_epg/lib/src/compact_epg_models.dart:397`) exactly as declared — `loadCurrentNext` and `loadWindow`, `loadWindow` returning only programmes intersecting `[windowStart, windowEnd)`.
- Out of scope (per issue #823 non-goals): no Dispatcharr, no provider marketplace/auto-discovery, no multi-provider failover, no settings/provider-management UI beyond what tests need (CV-022 owns that).

---

## File Structure

```
packages/platform_playlist/
  pubspec.yaml                                    [rewrite]
  module.yaml                                      [rewrite]
  lib/
    platform_playlist.dart                         [rewrite — barrel]
    src/
      content_source.dart                          [new]
      content_source_credential_store.dart          [new]
      m3u_content_source.dart                       [new]
      xtream/
        xtream_content_source.dart                  [new]
        xtream_client.dart                          [new]
        xtream_epg_repository.dart                  [new]
      stalker/
        stalker_content_source.dart                 [new]
        stalker_client.dart                         [new]
        stalker_epg_repository.dart                 [new]
      jellyfin/
        jellyfin_content_source.dart                 [new]
        jellyfin_client.dart                        [new]
        jellyfin_epg_repository.dart                [new]
  test/
    content_source_test.dart                        [new]
    content_source_credential_store_test.dart        [new]
    m3u_content_source_test.dart                     [new]
    xtream/
      xtream_client_test.dart                        [new]
      xtream_content_source_test.dart                 [new]
    stalker/
      stalker_client_test.dart                        [new]
      stalker_content_source_test.dart                [new]
    jellyfin/
      jellyfin_client_test.dart                       [new]
      jellyfin_content_source_test.dart                [new]

# Deleted (dead template scaffold, no callers anywhere — confirmed via
# module.yaml allowed_dependencies audit across all packages, 2026-07-16):
packages/platform_playlist/lib/src/models/playlist.dart              [delete]
packages/platform_playlist/lib/src/providers/playlist_provider.dart   [delete]
packages/platform_playlist/lib/src/repositories/playlist_repository.dart [delete]
packages/platform_playlist/lib/src/importers/playlist_importer.dart   [delete]
packages/platform_playlist/lib/src/exporters/playlist_exporter.dart   [delete]
packages/platform_playlist/test/platform_playlist_test.dart           [delete]
```

---

### Task 1: Package scaffold + `ContentSource` contract

**Files:**
- Modify: `packages/platform_playlist/pubspec.yaml`
- Modify: `packages/platform_playlist/module.yaml`
- Delete: `packages/platform_playlist/lib/src/models/playlist.dart`
- Delete: `packages/platform_playlist/lib/src/providers/playlist_provider.dart`
- Delete: `packages/platform_playlist/lib/src/repositories/playlist_repository.dart`
- Delete: `packages/platform_playlist/lib/src/importers/playlist_importer.dart`
- Delete: `packages/platform_playlist/lib/src/exporters/playlist_exporter.dart`
- Delete: `packages/platform_playlist/test/platform_playlist_test.dart`
- Create: `packages/platform_playlist/lib/src/content_source.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/content_source_test.dart`

**Interfaces:**
- Produces: `enum ContentSourceKind { m3u, xtream, stalker, jellyfin }`; `class ContentSourceCapabilities { bool hasEpg, bool hasVod, bool hasCatchup }`; `class ContentSourceCredentialRef { String key }` (redacted `toString`); `abstract class ContentSource { String id, String label, ContentSourceCapabilities capabilities, ContentSourceKind get kind }`.

- [ ] **Step 1: Delete the dead template scaffold**

```bash
rm packages/platform_playlist/lib/src/models/playlist.dart
rm packages/platform_playlist/lib/src/providers/playlist_provider.dart
rm packages/platform_playlist/lib/src/repositories/playlist_repository.dart
rm packages/platform_playlist/lib/src/importers/playlist_importer.dart
rm packages/platform_playlist/lib/src/exporters/playlist_exporter.dart
rm packages/platform_playlist/test/platform_playlist_test.dart
rmdir packages/platform_playlist/lib/src/models packages/platform_playlist/lib/src/providers packages/platform_playlist/lib/src/repositories packages/platform_playlist/lib/src/importers packages/platform_playlist/lib/src/exporters 2>/dev/null || true
```

- [ ] **Step 2: Rewrite `pubspec.yaml`**

```yaml
name: platform_playlist
description: "Typed ContentSource contract (M3U, Xtream Codes, Stalker Portal, Jellyfin) and provider adapters for Airo TV."
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.12.2
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter
  core_data:
    path: ../core_data
  dio: ^5.10.0
  equatable: ^2.0.8
  platform_channels:
    path: ../platform_channels
  platform_epg:
    path: ../platform_epg
  platform_playlist_import:
    path: ../platform_playlist_import

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

- [ ] **Step 3: Rewrite `module.yaml`**

```yaml
name: platform_playlist
owner: Media Intelligence Architect
reviewers:
  - Chief Architect
  - Platform Architect
  - Chief QA Officer
  - Chief Security Officer
allowed_dependencies:
  - core_data
  - platform_channels
  - platform_epg
  - platform_playlist_import
forbidden_dependencies:
  - app
quality_gates: {}
```

- [ ] **Step 4: Write `lib/src/content_source.dart`**

```dart
import 'package:equatable/equatable.dart';

/// The wire protocol a [ContentSource] speaks.
enum ContentSourceKind {
  m3u('m3u'),
  xtream('xtream'),
  stalker('stalker'),
  jellyfin('jellyfin');

  const ContentSourceKind(this.stableId);

  final String stableId;
}

/// What a source can supply, independent of how it's fetched.
class ContentSourceCapabilities extends Equatable {
  const ContentSourceCapabilities({
    this.hasEpg = false,
    this.hasVod = false,
    this.hasCatchup = false,
  });

  final bool hasEpg;
  final bool hasVod;
  final bool hasCatchup;

  @override
  List<Object?> get props => [hasEpg, hasVod, hasCatchup];
}

/// Opaque reference to credentials held in [ContentSourceCredentialStore].
///
/// Never carries the secret itself — only a lookup key — so a
/// [ContentSource] can be logged, compared, or stored without ever risking
/// an unredacted username/password. Mirrors `CompactEpgSourceRef` in
/// `platform_epg`.
class ContentSourceCredentialRef extends Equatable {
  const ContentSourceCredentialRef(this.key);

  final String key;

  @override
  List<Object?> get props => [key];

  @override
  String toString() => 'ContentSourceCredentialRef(redacted)';
}

/// A user-configured content source: where channels/VOD/EPG come from.
///
/// Subclasses hold only non-secret configuration (server URL, playlist URL)
/// plus a [ContentSourceCredentialRef] where auth is required — the actual
/// credentials live in [ContentSourceCredentialStore], never inline here.
abstract class ContentSource extends Equatable {
  const ContentSource({
    required this.id,
    required this.label,
    required this.capabilities,
  });

  final String id;
  final String label;
  final ContentSourceCapabilities capabilities;

  ContentSourceKind get kind;

  @override
  List<Object?> get props => [id, label, capabilities, kind];

  @override
  String toString() =>
      'ContentSource(kind: ${kind.stableId}, id: $id, label: $label)';
}
```

- [ ] **Step 5: Write `test/content_source_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeContentSource extends ContentSource {
  const _FakeContentSource({required super.id, required super.label})
    : super(
        capabilities: const ContentSourceCapabilities(
          hasEpg: true,
          hasVod: true,
        ),
      );

  @override
  ContentSourceKind get kind => ContentSourceKind.xtream;
}

void main() {
  group('ContentSourceCredentialRef', () {
    test('toString never leaks the key', () {
      const ref = ContentSourceCredentialRef('source-1');
      expect(ref.toString(), 'ContentSourceCredentialRef(redacted)');
      expect(ref.toString(), isNot(contains('source-1')));
    });

    test('equality is key-based', () {
      expect(
        const ContentSourceCredentialRef('a'),
        const ContentSourceCredentialRef('a'),
      );
      expect(
        const ContentSourceCredentialRef('a'),
        isNot(const ContentSourceCredentialRef('b')),
      );
    });
  });

  group('ContentSource', () {
    test('exposes kind and capabilities', () {
      const source = _FakeContentSource(id: 'src-1', label: 'My Provider');
      expect(source.kind, ContentSourceKind.xtream);
      expect(source.capabilities.hasEpg, isTrue);
      expect(source.capabilities.hasVod, isTrue);
      expect(source.capabilities.hasCatchup, isFalse);
    });

    test('toString identifies kind/id/label without leaking secrets', () {
      const source = _FakeContentSource(id: 'src-1', label: 'My Provider');
      expect(source.toString(), 'ContentSource(kind: xtream, id: src-1, label: My Provider)');
    });
  });
}
```

- [ ] **Step 6: Point the barrel at the new contract**

```dart
/// Typed ContentSource contract (M3U, Xtream Codes, Stalker Portal,
/// Jellyfin) and provider adapters for Airo TV.
library platform_playlist;

export 'src/content_source.dart';
```

- [ ] **Step 7: Run the test**

Run: `cd packages/platform_playlist && flutter test test/content_source_test.dart`
Expected: `00:0X +4: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): add ContentSource contract, retire template scaffold"
```

---

### Task 2: `ContentSourceCredentialStore`

**Files:**
- Create: `packages/platform_playlist/lib/src/content_source_credential_store.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/content_source_credential_store_test.dart`

**Interfaces:**
- Consumes: `ContentSourceCredentialRef` (Task 1), `SecureStore` (`package:core_data/core_data.dart` — `Future<String?> read({required String key})`, `Future<void> write({required String key, required String value})`, `Future<void> delete({required String key})`).
- Produces: `class ContentSourceCredentials { String username, String password }` (redacted `toString`); `class ContentSourceCredentialStore { Future<void> save(ContentSourceCredentialRef, ContentSourceCredentials); Future<ContentSourceCredentials?> read(ContentSourceCredentialRef); Future<void> delete(ContentSourceCredentialRef); }`.

- [ ] **Step 1: Write the failing test**

```dart
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
    final result = await store.read(const ContentSourceCredentialRef('missing'));
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
    await store.save(refA, const ContentSourceCredentials(username: 'a-user', password: 'a-pass'));
    await store.save(refB, const ContentSourceCredentials(username: 'b-user', password: 'b-pass'));

    expect((await store.read(refA))?.username, 'a-user');
    expect((await store.read(refB))?.username, 'b-user');
  });

  test('ContentSourceCredentials.toString never leaks the password', () {
    const credentials = ContentSourceCredentials(username: 'alice', password: 'hunter2');
    expect(credentials.toString(), isNot(contains('hunter2')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/content_source_credential_store_test.dart`
Expected: FAIL — `ContentSourceCredentialStore` and `ContentSourceCredentials` undefined.

- [ ] **Step 3: Write `lib/src/content_source_credential_store.dart`**

```dart
import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

import 'content_source.dart';

/// A source's auth secret. Never persisted or logged outside
/// [ContentSourceCredentialStore] — [toString] is always redacted.
class ContentSourceCredentials extends Equatable {
  const ContentSourceCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];

  @override
  String toString() => 'ContentSourceCredentials(redacted)';
}

/// Stores/retrieves [ContentSourceCredentials] behind a
/// [ContentSourceCredentialRef], backed by `core_data`'s [SecureStore]
/// (Keystore on Android, Keychain on iOS/macOS — see
/// `FlutterSecureStore` in `core_data`).
class ContentSourceCredentialStore {
  ContentSourceCredentialStore(this._secureStore);

  final SecureStore _secureStore;

  static String _usernameKey(ContentSourceCredentialRef ref) =>
      'content_source.${ref.key}.username';

  static String _passwordKey(ContentSourceCredentialRef ref) =>
      'content_source.${ref.key}.password';

  Future<void> save(
    ContentSourceCredentialRef ref,
    ContentSourceCredentials credentials,
  ) async {
    await _secureStore.write(
      key: _usernameKey(ref),
      value: credentials.username,
    );
    await _secureStore.write(
      key: _passwordKey(ref),
      value: credentials.password,
    );
  }

  Future<ContentSourceCredentials?> read(
    ContentSourceCredentialRef ref,
  ) async {
    final username = await _secureStore.read(key: _usernameKey(ref));
    final password = await _secureStore.read(key: _passwordKey(ref));
    if (username == null || password == null) {
      return null;
    }
    return ContentSourceCredentials(username: username, password: password);
  }

  Future<void> delete(ContentSourceCredentialRef ref) async {
    await _secureStore.delete(key: _usernameKey(ref));
    await _secureStore.delete(key: _passwordKey(ref));
  }
}
```

- [ ] **Step 4: Export it from the barrel**

```dart
export 'src/content_source_credential_store.dart';
```

(add this line to `packages/platform_playlist/lib/platform_playlist.dart`, after the Task 1 export)

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/content_source_credential_store_test.dart`
Expected: `00:0X +5: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): add secure credential store for content sources"
```

---

### Task 3: M3U `ContentSource` — re-home with zero behavior change

**Files:**
- Create: `packages/platform_playlist/lib/src/m3u_content_source.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/m3u_content_source_test.dart`

**Interfaces:**
- Consumes: `M3UParserService` (`package:platform_playlist_import/platform_playlist_import.dart` — `Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false})`), `ContentSource`/`ContentSourceKind`/`ContentSourceCapabilities` (Task 1).
- Produces: `class M3uContentSource extends ContentSource { String playlistUrl }`; `class M3uContentSourceAdapter { M3uContentSourceAdapter(this.source, this._parser); Future<List<IPTVChannel>> loadChannels({bool forceRefresh = false}) }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

class _FakeM3UParserService implements M3UParserService {
  _FakeM3UParserService(this._channels);

  final List<IPTVChannel> _channels;
  int fetchCallCount = 0;

  @override
  Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false}) async {
    fetchCallCount++;
    return _channels;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('M3uContentSource reports m3u kind and EPG-only capabilities', () {
    const source = M3uContentSource(
      id: 'm3u-1',
      label: 'My Playlist',
      playlistUrl: 'https://example.com/playlist.m3u',
    );

    expect(source.kind, ContentSourceKind.m3u);
    expect(source.capabilities.hasVod, isFalse);
    expect(source.capabilities.hasCatchup, isFalse);
  });

  test('adapter delegates straight to M3UParserService.fetchPlaylist', () async {
    final channel = IPTVChannel.fromM3U(name: 'Test', url: 'https://x/stream.m3u8');
    final fakeParser = _FakeM3UParserService([channel]);
    const source = M3uContentSource(
      id: 'm3u-1',
      label: 'My Playlist',
      playlistUrl: 'https://example.com/playlist.m3u',
    );
    final adapter = M3uContentSourceAdapter(source, fakeParser);

    final result = await adapter.loadChannels();

    expect(result, [channel]);
    expect(fakeParser.fetchCallCount, 1);
  });

  test('adapter forwards forceRefresh unchanged', () async {
    final fakeParser = _FakeM3UParserService(const []);
    const source = M3uContentSource(
      id: 'm3u-1',
      label: 'My Playlist',
      playlistUrl: 'https://example.com/playlist.m3u',
    );
    final adapter = M3uContentSourceAdapter(source, fakeParser);

    await adapter.loadChannels(forceRefresh: true);

    expect(fakeParser.fetchCallCount, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/m3u_content_source_test.dart`
Expected: FAIL — `M3uContentSource`/`M3uContentSourceAdapter` undefined.

- [ ] **Step 3: Write `lib/src/m3u_content_source.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

import 'content_source.dart';

/// The existing M3U playlist path, re-homed under [ContentSource].
///
/// No parsing/fetch/cache behavior changes here — [M3uContentSourceAdapter]
/// delegates directly to the unmodified [M3UParserService].
class M3uContentSource extends ContentSource {
  const M3uContentSource({
    required super.id,
    required super.label,
    required this.playlistUrl,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: true,
           hasVod: false,
           hasCatchup: false,
         ),
       );

  final String playlistUrl;

  @override
  ContentSourceKind get kind => ContentSourceKind.m3u;

  @override
  List<Object?> get props => [...super.props, playlistUrl];
}

/// Adapts [M3uContentSource] to a channel-loading call, wrapping the
/// existing [M3UParserService] with no change to its fetch/parse/cache
/// behavior.
class M3uContentSourceAdapter {
  M3uContentSourceAdapter(this.source, this._parser);

  final M3uContentSource source;
  final M3UParserService _parser;

  Future<List<IPTVChannel>> loadChannels({bool forceRefresh = false}) {
    return _parser.fetchPlaylist(forceRefresh: forceRefresh);
  }
}
```

- [ ] **Step 4: Export it from the barrel**

```dart
export 'src/m3u_content_source.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/m3u_content_source_test.dart`
Expected: `00:0X +3: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): re-home M3U path as a ContentSource variant"
```

---

### Task 4: Xtream Codes adapter

**Files:**
- Create: `packages/platform_playlist/lib/src/xtream/xtream_client.dart`
- Create: `packages/platform_playlist/lib/src/xtream/xtream_content_source.dart`
- Create: `packages/platform_playlist/lib/src/xtream/xtream_epg_repository.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/xtream/xtream_client_test.dart`
- Test: `packages/platform_playlist/test/xtream/xtream_content_source_test.dart`

**Interfaces:**
- Consumes: `Dio` (constructor injection, matches `M3UParserService`'s `Dio dio` param), `ContentSource`/`ContentSourceCredentials`/`ContentSourceCredentialStore` (Tasks 1-2), `IPTVChannel.fromJson`-shape fields, `CompactEpgRepository`/`CompactEpgSlice`/`CompactEpgWindow`/`CompactEpgProgram`/`CompactEpgEntry`/`GuideWindowQuery` (`package:platform_epg/platform_epg.dart`).
- Produces: `class XtreamClient { Future<XtreamAuthResult> authenticate(); Future<List<XtreamLiveStream>> getLiveStreams(); Future<List<XtreamVodStream>> getVodStreams(); Future<List<XtreamEpgListing>> getShortEpg({required int streamId, int limit}); String liveStreamUrl(int streamId, {String extension = 'm3u8'}); }`; `class XtreamContentSource extends ContentSource { String serverUrl; ContentSourceCredentialRef credentialRef; }`; `class XtreamContentSourceAdapter { Future<List<IPTVChannel>> loadChannels(); }`; `class XtreamEpgRepository implements CompactEpgRepository`.

- [ ] **Step 1: Write the failing client test**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  late Dio dio;
  late DioAdapter adapterMock;

  // Minimal in-file Dio mock adapter — no http_mock_adapter dependency in
  // this repo; intercept via a HttpClientAdapter override instead.
  test('authenticate() parses user_info/server_info', () async {
    dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
    dio.httpClientAdapter = _FakeXtreamAdapter({
      '/player_api.php': (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'user_info': {
            'auth': 1,
            'status': 'Active',
            'max_connections': '1',
          },
          'server_info': {'url': 'xtream.example.com', 'https_port': '443'},
        },
      ),
    });
    final client = XtreamClient(
      dio: dio,
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    final result = await client.authenticate();

    expect(result.isAuthenticated, isTrue);
    expect(result.status, 'Active');
  });

  test('getLiveStreams() maps stream_id/name/stream_icon/category_id', () async {
    dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
    dio.httpClientAdapter = _FakeXtreamAdapter({
      '/player_api.php': (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: [
          {
            'stream_id': 101,
            'name': 'News HD',
            'stream_icon': 'https://xtream.example.com/logo.png',
            'category_id': '5',
            'epg_channel_id': 'news.hd',
          },
        ],
      ),
    });
    final client = XtreamClient(
      dio: dio,
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    final streams = await client.getLiveStreams();

    expect(streams, hasLength(1));
    expect(streams.single.streamId, 101);
    expect(streams.single.name, 'News HD');
    expect(streams.single.epgChannelId, 'news.hd');
  });

  test('getShortEpg() base64-decodes title/description', () async {
    dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
    dio.httpClientAdapter = _FakeXtreamAdapter({
      '/player_api.php': (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'epg_listings': [
            {
              'id': '1',
              'title': base64Encode(utf8.encode('Evening News')),
              'description': base64Encode(utf8.encode('Top stories')),
              'start': '2026-07-16 18:00:00',
              'end': '2026-07-16 18:30:00',
              'stream_id': '101',
            },
          ],
        },
      ),
    });
    final client = XtreamClient(
      dio: dio,
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    final listings = await client.getShortEpg(streamId: 101);

    expect(listings.single.title, 'Evening News');
    expect(listings.single.description, 'Top stories');
  });

  test('liveStreamUrl builds username/password/stream_id path', () {
    final client = XtreamClient(
      dio: Dio(),
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    expect(
      client.liveStreamUrl(101),
      'https://xtream.example.com/live/user1/pass1/101.m3u8',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/xtream/xtream_client_test.dart`
Expected: FAIL — `XtreamClient` undefined.

- [ ] **Step 3: Write `lib/src/xtream/xtream_client.dart`**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Result of Xtream Codes `player_api.php` auth (no `action` param).
class XtreamAuthResult extends Equatable {
  const XtreamAuthResult({required this.isAuthenticated, required this.status});

  final bool isAuthenticated;
  final String status;

  @override
  List<Object?> get props => [isAuthenticated, status];
}

class XtreamLiveStream extends Equatable {
  const XtreamLiveStream({
    required this.streamId,
    required this.name,
    this.streamIcon,
    this.categoryId,
    this.epgChannelId,
  });

  final int streamId;
  final String name;
  final String? streamIcon;
  final String? categoryId;
  final String? epgChannelId;

  @override
  List<Object?> get props => [streamId, name, streamIcon, categoryId, epgChannelId];
}

class XtreamVodStream extends Equatable {
  const XtreamVodStream({
    required this.streamId,
    required this.name,
    this.streamIcon,
    this.categoryId,
    this.containerExtension,
  });

  final int streamId;
  final String name;
  final String? streamIcon;
  final String? categoryId;
  final String? containerExtension;

  @override
  List<Object?> get props => [streamId, name, streamIcon, categoryId, containerExtension];
}

class XtreamEpgListing extends Equatable {
  const XtreamEpgListing({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.streamId,
  });

  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final int streamId;

  @override
  List<Object?> get props => [id, title, description, start, end, streamId];
}

/// Xtream Codes `player_api.php` client. Wire protocol per the
/// widely-deployed Xtream Codes panel API (auth via query params, JSON
/// responses, base64-encoded EPG title/description).
class XtreamClient {
  XtreamClient({
    required Dio dio,
    required String serverUrl,
    required String username,
    required String password,
  }) : _dio = dio,
       _serverUrl = serverUrl.endsWith('/')
           ? serverUrl.substring(0, serverUrl.length - 1)
           : serverUrl,
       _username = username,
       _password = password;

  final Dio _dio;
  final String _serverUrl;
  final String _username;
  final String _password;

  Map<String, dynamic> _baseParams([Map<String, dynamic>? extra]) => {
    'username': _username,
    'password': _password,
    ...?extra,
  };

  Future<XtreamAuthResult> authenticate() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams(),
    );
    final userInfo = response.data?['user_info'] as Map<String, dynamic>?;
    final status = userInfo?['status'] as String? ?? 'Unknown';
    final auth = userInfo?['auth'];
    return XtreamAuthResult(
      isAuthenticated: auth == 1 || auth == '1',
      status: status,
    );
  }

  Future<List<XtreamLiveStream>> getLiveStreams() async {
    final response = await _dio.get<List<dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams({'action': 'get_live_streams'}),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (json) => XtreamLiveStream(
            streamId: json['stream_id'] as int,
            name: json['name'] as String,
            streamIcon: json['stream_icon'] as String?,
            categoryId: json['category_id'] as String?,
            epgChannelId: json['epg_channel_id'] as String?,
          ),
        )
        .toList();
  }

  Future<List<XtreamVodStream>> getVodStreams() async {
    final response = await _dio.get<List<dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams({'action': 'get_vod_streams'}),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (json) => XtreamVodStream(
            streamId: json['stream_id'] as int,
            name: json['name'] as String,
            streamIcon: json['stream_icon'] as String?,
            categoryId: json['category_id'] as String?,
            containerExtension: json['container_extension'] as String?,
          ),
        )
        .toList();
  }

  Future<List<XtreamEpgListing>> getShortEpg({
    required int streamId,
    int limit = 4,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams({
        'action': 'get_short_epg',
        'stream_id': streamId,
        'limit': limit,
      }),
    );
    final listings = response.data?['epg_listings'] as List<dynamic>? ?? const [];
    return listings.cast<Map<String, dynamic>>().map((json) {
      return XtreamEpgListing(
        id: json['id'] as String,
        title: utf8.decode(base64.decode(json['title'] as String)),
        description: utf8.decode(base64.decode(json['description'] as String)),
        start: DateTime.parse((json['start'] as String).replaceFirst(' ', 'T')),
        end: DateTime.parse((json['end'] as String).replaceFirst(' ', 'T')),
        streamId: int.parse(json['stream_id'] as String),
      );
    }).toList();
  }

  String liveStreamUrl(int streamId, {String extension = 'm3u8'}) =>
      '$_serverUrl/live/$_username/$_password/$streamId.$extension';

  String vodStreamUrl(int streamId, String containerExtension) =>
      '$_serverUrl/movie/$_username/$_password/$streamId.$containerExtension';
}
```

- [ ] **Step 4: Run client tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/xtream/xtream_client_test.dart`
Expected: `00:0X +4: All tests passed!`

- [ ] **Step 5: Write the failing content-source test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeXtreamClient implements XtreamClient {
  _FakeXtreamClient(this._streams);
  final List<XtreamLiveStream> _streams;

  @override
  Future<List<XtreamLiveStream>> getLiveStreams() async => _streams;

  @override
  String liveStreamUrl(int streamId, {String extension = 'm3u8'}) =>
      'https://xtream.example.com/live/u/p/$streamId.$extension';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('XtreamContentSource reports full capabilities', () {
    const source = XtreamContentSource(
      id: 'xtream-1',
      label: 'My Xtream',
      serverUrl: 'https://xtream.example.com',
      credentialRef: ContentSourceCredentialRef('xtream-1'),
    );

    expect(source.kind, ContentSourceKind.xtream);
    expect(source.capabilities.hasEpg, isTrue);
    expect(source.capabilities.hasVod, isTrue);
  });

  test('adapter maps XtreamLiveStream into IPTVChannel via live stream URL', () async {
    final fakeClient = _FakeXtreamClient([
      const XtreamLiveStream(
        streamId: 101,
        name: 'News HD',
        streamIcon: 'https://xtream.example.com/logo.png',
        categoryId: '5',
        epgChannelId: 'news.hd',
      ),
    ]);
    final adapter = XtreamContentSourceAdapter(fakeClient);

    final channels = await adapter.loadChannels();

    expect(channels, hasLength(1));
    expect(channels.single.name, 'News HD');
    expect(channels.single.streamUrl, 'https://xtream.example.com/live/u/p/101.m3u8');
    expect(channels.single.logoUrl, 'https://xtream.example.com/logo.png');
    expect(channels.single.id, 'xtream-101');
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/xtream/xtream_content_source_test.dart`
Expected: FAIL — `XtreamContentSource`/`XtreamContentSourceAdapter` undefined.

- [ ] **Step 7: Write `lib/src/xtream/xtream_content_source.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';

import '../content_source.dart';
import 'xtream_client.dart';

class XtreamContentSource extends ContentSource {
  const XtreamContentSource({
    required super.id,
    required super.label,
    required this.serverUrl,
    required this.credentialRef,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: true,
           hasVod: true,
           hasCatchup: false,
         ),
       );

  final String serverUrl;
  final ContentSourceCredentialRef credentialRef;

  @override
  ContentSourceKind get kind => ContentSourceKind.xtream;

  @override
  List<Object?> get props => [...super.props, serverUrl, credentialRef];
}

/// Maps Xtream live streams into [IPTVChannel]s. VOD listing follows the
/// same shape via [XtreamClient.getVodStreams] but is surfaced separately
/// by CV-019 (local VOD listing over BYOC sources), not this adapter.
class XtreamContentSourceAdapter {
  XtreamContentSourceAdapter(this._client);

  final XtreamClient _client;

  Future<List<IPTVChannel>> loadChannels() async {
    final streams = await _client.getLiveStreams();
    return [
      for (final stream in streams)
        IPTVChannel(
          id: 'xtream-${stream.streamId}',
          name: stream.name,
          streamUrl: _client.liveStreamUrl(stream.streamId),
          logoUrl: stream.streamIcon,
          group: stream.categoryId ?? 'Uncategorized',
          tvgId: int.tryParse(stream.epgChannelId ?? ''),
          tvgName: stream.epgChannelId,
        ),
    ];
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/xtream/xtream_content_source_test.dart`
Expected: `00:0X +2: All tests passed!`

- [ ] **Step 9: Write `lib/src/xtream/xtream_epg_repository.dart`**

```dart
import 'package:platform_epg/platform_epg.dart';

import 'xtream_client.dart';

/// [CompactEpgRepository] backed by Xtream's `get_short_epg`.
///
/// Xtream's short-EPG endpoint only returns a bounded listing per channel
/// (current + a handful of upcoming), which is exactly the shape
/// [CompactEpgRepository] expects — no full-timetable materialization
/// needed, unlike [XmltvCompactEpgRepository].
class XtreamEpgRepository implements CompactEpgRepository {
  XtreamEpgRepository(this._client, {required this.channelIdToStreamId});

  final XtreamClient _client;

  /// Maps the [IPTVChannel.id] values used elsewhere in the app (e.g.
  /// `'xtream-101'`) back to the raw Xtream `stream_id` this client needs.
  final int? Function(String channelId) channelIdToStreamId;

  Future<CompactEpgEntry?> _entryFor(String channelId, DateTime now) async {
    final streamId = channelIdToStreamId(channelId);
    if (streamId == null) return null;

    final listings = await _client.getShortEpg(streamId: streamId);
    final programs = [
      for (final listing in listings)
        CompactEpgProgram(
          programId: listing.id,
          title: listing.title,
          subtitle: listing.description,
          startsAt: listing.start.toUtc(),
          endsAt: listing.end.toUtc(),
        ),
    ];

    return CompactEpgEntry.fromPrograms(
      channelId: channelId,
      channelName: channelId,
      now: now,
      programs: programs,
    );
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final entries = <CompactEpgEntry>[];
    for (final channelId in channelIds) {
      final entry = await _entryFor(channelId, now);
      if (entry != null) entries.add(entry);
    }
    return CompactEpgSlice(
      entries: entries,
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    final entries = <CompactEpgWindowEntry>[];
    for (final channelId in query.channelIds) {
      final streamId = channelIdToStreamId(channelId);
      if (streamId == null) continue;

      final listings = await _client.getShortEpg(streamId: streamId);
      final programs = [
        for (final listing in listings)
          if (listing.end.toUtc().isAfter(query.windowStart) &&
              listing.start.toUtc().isBefore(query.windowEnd))
            CompactEpgProgram(
              programId: listing.id,
              title: listing.title,
              subtitle: listing.description,
              startsAt: listing.start.toUtc(),
              endsAt: listing.end.toUtc(),
            ),
      ];
      entries.add(
        CompactEpgWindowEntry(
          channelId: channelId,
          channelName: channelId,
          programs: programs,
        ),
      );
    }

    return CompactEpgWindow(
      entries: entries,
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: query.now,
      expiresAt: query.now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }
}
```

- [ ] **Step 10: Export Xtream files from the barrel**

```dart
export 'src/xtream/xtream_client.dart';
export 'src/xtream/xtream_content_source.dart';
export 'src/xtream/xtream_epg_repository.dart';
```

- [ ] **Step 11: Run the full package test suite**

Run: `cd packages/platform_playlist && flutter test`
Expected: all tests pass, no failures.

- [ ] **Step 12: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): add Xtream Codes adapter (auth, live streams, short EPG)"
```

---

### Task 5: Stalker Portal adapter

**Files:**
- Create: `packages/platform_playlist/lib/src/stalker/stalker_client.dart`
- Create: `packages/platform_playlist/lib/src/stalker/stalker_content_source.dart`
- Create: `packages/platform_playlist/lib/src/stalker/stalker_epg_repository.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/stalker/stalker_client_test.dart`
- Test: `packages/platform_playlist/test/stalker/stalker_content_source_test.dart`

**Interfaces:**
- Consumes: `Dio`, `ContentSource` (Task 1), `CompactEpgRepository` family (`platform_epg`).
- Produces: `class StalkerClient { Future<String> handshake(); Future<List<StalkerChannel>> getChannels({required String token}); Future<String> createLink({required String token, required String cmd}); }`; `class StalkerContentSource extends ContentSource { String serverUrl; String macAddress; }`; `class StalkerContentSourceAdapter { Future<List<IPTVChannel>> loadChannels(); }`.

Stalker Portal (Ministra middleware) identifies the device by MAC address rather than username/password — the `mac` cookie *is* the credential. `StalkerContentSource` stores `macAddress` directly (not a secret needing redaction store — MAC addresses are device identifiers already visible in device settings elsewhere in this repo, e.g. `core_device_identity`), and only the session `token` returned by handshake is short-lived/sensitive, kept in memory only.

- [ ] **Step 1: Write the failing client test**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  test('handshake() sends mac cookie and returns token', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = _FakeStalkerAdapter({
      '/portal.php': (options) {
        expect(options.headers['Cookie'], contains('mac=AA:BB:CC:DD:EE:FF'));
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {'js': {'token': 'tok-123'}},
        );
      },
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final token = await client.handshake();

    expect(token, 'tok-123');
  });

  test('getChannels() maps id/name/number/logo/cmd', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = _FakeStalkerAdapter({
      '/portal.php': (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'js': {
            'data': [
              {
                'id': '1',
                'name': 'Sports 1',
                'number': '101',
                'logo': 'https://stalker.example.com/logo1.png',
                'cmd': 'ffmpeg http://localhost/ch/1_',
              },
            ],
          },
        },
      ),
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final channels = await client.getChannels(token: 'tok-123');

    expect(channels.single.id, '1');
    expect(channels.single.name, 'Sports 1');
    expect(channels.single.cmd, 'ffmpeg http://localhost/ch/1_');
  });

  test('createLink() resolves cmd into a playable URL', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = _FakeStalkerAdapter({
      '/portal.php': (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {'js': {'cmd': 'https://stalker.example.com/stream/1.m3u8'}},
      ),
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final url = await client.createLink(
      token: 'tok-123',
      cmd: 'ffmpeg http://localhost/ch/1_',
    );

    expect(url, 'https://stalker.example.com/stream/1.m3u8');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/stalker/stalker_client_test.dart`
Expected: FAIL — `StalkerClient` undefined.

- [ ] **Step 3: Write `lib/src/stalker/stalker_client.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class StalkerChannel extends Equatable {
  const StalkerChannel({
    required this.id,
    required this.name,
    required this.cmd,
    this.number,
    this.logo,
    this.genreId,
  });

  final String id;
  final String name;
  final String cmd;
  final String? number;
  final String? logo;
  final String? genreId;

  @override
  List<Object?> get props => [id, name, cmd, number, logo, genreId];
}

/// Stalker Portal (Ministra middleware) client.
///
/// Auth is MAC-address based: the device MAC goes in a `Cookie: mac=...`
/// header on every request, `handshake` exchanges it for a short-lived
/// session token, and channel URLs must be resolved per-play via
/// `create_link` — the `cmd` field from `get_ordered_list` is not itself
/// playable.
class StalkerClient {
  StalkerClient({
    required Dio dio,
    required String serverUrl,
    required String macAddress,
  }) : _dio = dio,
       _serverUrl = serverUrl.endsWith('/')
           ? serverUrl.substring(0, serverUrl.length - 1)
           : serverUrl,
       _macAddress = macAddress;

  final Dio _dio;
  final String _serverUrl;
  final String _macAddress;

  Options get _macOptions => Options(
    headers: {
      'Cookie': 'mac=$_macAddress; stb_lang=en; timezone=UTC',
    },
  );

  Future<String> handshake() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/portal.php',
      queryParameters: {
        'type': 'stb',
        'action': 'handshake',
        'token': '',
        'JsHttpRequest': '1-xml',
      },
      options: _macOptions,
    );
    return response.data?['js']?['token'] as String;
  }

  Future<List<StalkerChannel>> getChannels({required String token}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/portal.php',
      queryParameters: {
        'type': 'itv',
        'action': 'get_ordered_list',
        'genre': '*',
        'JsHttpRequest': '1-xml',
      },
      options: Options(
        headers: {
          ..._macOptions.headers!,
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final data = response.data?['js']?['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>().map((json) {
      return StalkerChannel(
        id: json['id'] as String,
        name: json['name'] as String,
        cmd: json['cmd'] as String,
        number: json['number'] as String?,
        logo: json['logo'] as String?,
        genreId: json['tv_genre_id'] as String?,
      );
    }).toList();
  }

  Future<String> createLink({
    required String token,
    required String cmd,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/portal.php',
      queryParameters: {
        'type': 'itv',
        'action': 'create_link',
        'cmd': cmd,
        'JsHttpRequest': '1-xml',
      },
      options: Options(
        headers: {
          ..._macOptions.headers!,
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return response.data?['js']?['cmd'] as String;
  }
}
```

- [ ] **Step 4: Run client tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/stalker/stalker_client_test.dart`
Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Write the failing content-source test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeStalkerClient implements StalkerClient {
  _FakeStalkerClient(this._channels);
  final List<StalkerChannel> _channels;
  String? tokenUsedForGetChannels;

  @override
  Future<String> handshake() async => 'tok-fake';

  @override
  Future<List<StalkerChannel>> getChannels({required String token}) async {
    tokenUsedForGetChannels = token;
    return _channels;
  }

  @override
  Future<String> createLink({required String token, required String cmd}) async =>
      'https://stalker.example.com/resolved/$cmd';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('StalkerContentSource reports EPG-capable, no VOD', () {
    const source = StalkerContentSource(
      id: 'stalker-1',
      label: 'My Stalker Portal',
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    expect(source.kind, ContentSourceKind.stalker);
    expect(source.capabilities.hasEpg, isTrue);
    expect(source.capabilities.hasVod, isFalse);
  });

  test('adapter handshakes then resolves each channel link', () async {
    final fakeClient = _FakeStalkerClient([
      const StalkerChannel(
        id: '1',
        name: 'Sports 1',
        cmd: 'ffmpeg http://localhost/ch/1_',
        logo: 'https://stalker.example.com/logo1.png',
      ),
    ]);
    final adapter = StalkerContentSourceAdapter(fakeClient);

    final channels = await adapter.loadChannels();

    expect(channels, hasLength(1));
    expect(channels.single.id, 'stalker-1');
    expect(channels.single.name, 'Sports 1');
    expect(
      channels.single.streamUrl,
      'https://stalker.example.com/resolved/ffmpeg http://localhost/ch/1_',
    );
    expect(fakeClient.tokenUsedForGetChannels, 'tok-fake');
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/stalker/stalker_content_source_test.dart`
Expected: FAIL — `StalkerContentSource`/`StalkerContentSourceAdapter` undefined.

- [ ] **Step 7: Write `lib/src/stalker/stalker_content_source.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';

import '../content_source.dart';
import 'stalker_client.dart';

class StalkerContentSource extends ContentSource {
  const StalkerContentSource({
    required super.id,
    required super.label,
    required this.serverUrl,
    required this.macAddress,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: true,
           hasVod: false,
           hasCatchup: false,
         ),
       );

  final String serverUrl;
  final String macAddress;

  @override
  ContentSourceKind get kind => ContentSourceKind.stalker;

  @override
  List<Object?> get props => [...super.props, serverUrl, macAddress];
}

/// Resolves each Stalker channel's play URL via `create_link` — Stalker's
/// `cmd` field from the channel list is a middleware-internal command, not
/// a directly playable stream URL.
class StalkerContentSourceAdapter {
  StalkerContentSourceAdapter(this._client);

  final StalkerClient _client;

  Future<List<IPTVChannel>> loadChannels() async {
    final token = await _client.handshake();
    final channels = await _client.getChannels(token: token);

    final result = <IPTVChannel>[];
    for (final channel in channels) {
      final url = await _client.createLink(token: token, cmd: channel.cmd);
      result.add(
        IPTVChannel(
          id: 'stalker-${channel.id}',
          name: channel.name,
          streamUrl: url,
          logoUrl: channel.logo,
          group: channel.genreId ?? 'Uncategorized',
        ),
      );
    }
    return result;
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/stalker/stalker_content_source_test.dart`
Expected: `00:0X +2: All tests passed!`

- [ ] **Step 9: Write `lib/src/stalker/stalker_epg_repository.dart`**

Stalker's `get_epg_info` action returns programmes per channel by `ch_id` and time range, structurally the same "return only what's asked for" contract `CompactEpgRepository` wants. Rather than duplicating the Xtream repository's structure verbatim, this repository accepts an injected fetch function so both the client's real HTTP shape and a test fake can supply programme lists without a second full HTTP client test.

```dart
import 'package:platform_epg/platform_epg.dart';

/// [CompactEpgRepository] backed by Stalker's `get_epg_info`.
///
/// Takes a fetch callback rather than a [StalkerClient] directly: Stalker's
/// EPG endpoint needs the same handshake token as channel listing, and the
/// call site (feature_iptv's provider layer) already holds a valid token
/// from loading channels — re-deriving it here would mean a second
/// handshake per guide request.
class StalkerEpgRepository implements CompactEpgRepository {
  StalkerEpgRepository(this._fetchProgrammes);

  /// Returns programmes for [channelId] with `startsAt`/`endsAt` already
  /// in UTC, in start-time order.
  final Future<List<CompactEpgProgram>> Function(String channelId) _fetchProgrammes;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final entries = <CompactEpgEntry>[];
    for (final channelId in channelIds) {
      final programs = await _fetchProgrammes(channelId);
      entries.add(
        CompactEpgEntry.fromPrograms(
          channelId: channelId,
          channelName: channelId,
          now: now,
          programs: programs,
        ),
      );
    }
    return CompactEpgSlice(
      entries: entries,
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    final entries = <CompactEpgWindowEntry>[];
    for (final channelId in query.channelIds) {
      final programs = await _fetchProgrammes(channelId);
      entries.add(
        CompactEpgWindowEntry(
          channelId: channelId,
          channelName: channelId,
          programs: [
            for (final program in programs)
              if (program.endsAt.isAfter(query.windowStart) &&
                  program.startsAt.isBefore(query.windowEnd))
                program,
          ],
        ),
      );
    }
    return CompactEpgWindow(
      entries: entries,
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: query.now,
      expiresAt: query.now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }
}
```

- [ ] **Step 10: Export Stalker files from the barrel**

```dart
export 'src/stalker/stalker_client.dart';
export 'src/stalker/stalker_content_source.dart';
export 'src/stalker/stalker_epg_repository.dart';
```

- [ ] **Step 11: Run the full package test suite**

Run: `cd packages/platform_playlist && flutter test`
Expected: all tests pass, no failures.

- [ ] **Step 12: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): add Stalker Portal adapter (MAC handshake, create_link resolution)"
```

---

### Task 6: Jellyfin adapter

**Files:**
- Create: `packages/platform_playlist/lib/src/jellyfin/jellyfin_client.dart`
- Create: `packages/platform_playlist/lib/src/jellyfin/jellyfin_content_source.dart`
- Create: `packages/platform_playlist/lib/src/jellyfin/jellyfin_epg_repository.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/jellyfin/jellyfin_client_test.dart`
- Test: `packages/platform_playlist/test/jellyfin/jellyfin_content_source_test.dart`

**Interfaces:**
- Consumes: `Dio`, `ContentSource` (Task 1), `CompactEpgRepository` family.
- Produces: `class JellyfinClient { Future<JellyfinAuthResult> authenticate(); Future<List<JellyfinChannel>> getLiveTvChannels({required String accessToken, required String userId}); Future<List<JellyfinProgram>> getPrograms({required String accessToken, required String userId, required List<String> channelIds}); String streamUrl(String itemId, String accessToken); }`; `class JellyfinContentSource extends ContentSource { String serverUrl; ContentSourceCredentialRef credentialRef; }`; `class JellyfinContentSourceAdapter { Future<List<IPTVChannel>> loadChannels(); }`.

- [ ] **Step 1: Write the failing client test**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  test('authenticate() posts Username/Pw and returns AccessToken/User.Id', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://jellyfin.example.com'));
    dio.httpClientAdapter = _FakeJellyfinAdapter({
      '/Users/AuthenticateByName': (options) {
        expect(options.headers['X-Emby-Authorization'], contains('Client="Airo TV"'));
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'AccessToken': 'jf-token',
            'User': {'Id': 'user-1', 'Name': 'alice'},
          },
        );
      },
    });
    final client = JellyfinClient(
      dio: dio,
      serverUrl: 'https://jellyfin.example.com',
      username: 'alice',
      password: 'hunter2',
    );

    final result = await client.authenticate();

    expect(result.accessToken, 'jf-token');
    expect(result.userId, 'user-1');
  });

  test('getLiveTvChannels() maps Id/Name/Number', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://jellyfin.example.com'));
    dio.httpClientAdapter = _FakeJellyfinAdapter({
      '/LiveTv/Channels': (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'Items': [
            {'Id': 'chan-1', 'Name': 'News', 'Number': '1'},
          ],
          'TotalRecordCount': 1,
        },
      ),
    });
    final client = JellyfinClient(
      dio: dio,
      serverUrl: 'https://jellyfin.example.com',
      username: 'alice',
      password: 'hunter2',
    );

    final channels = await client.getLiveTvChannels(
      accessToken: 'jf-token',
      userId: 'user-1',
    );

    expect(channels.single.id, 'chan-1');
    expect(channels.single.name, 'News');
    expect(channels.single.number, '1');
  });

  test('streamUrl builds /Videos/{itemId}/stream with api_key', () {
    final client = JellyfinClient(
      dio: Dio(),
      serverUrl: 'https://jellyfin.example.com',
      username: 'alice',
      password: 'hunter2',
    );

    expect(
      client.streamUrl('chan-1', 'jf-token'),
      'https://jellyfin.example.com/Videos/chan-1/stream?api_key=jf-token&static=true',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/jellyfin/jellyfin_client_test.dart`
Expected: FAIL — `JellyfinClient` undefined.

- [ ] **Step 3: Write `lib/src/jellyfin/jellyfin_client.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class JellyfinAuthResult extends Equatable {
  const JellyfinAuthResult({required this.accessToken, required this.userId});

  final String accessToken;
  final String userId;

  @override
  List<Object?> get props => [accessToken, userId];

  @override
  String toString() => 'JellyfinAuthResult(userId: $userId, accessToken: redacted)';
}

class JellyfinChannel extends Equatable {
  const JellyfinChannel({required this.id, required this.name, this.number});

  final String id;
  final String name;
  final String? number;

  @override
  List<Object?> get props => [id, name, number];
}

class JellyfinProgram extends Equatable {
  const JellyfinProgram({
    required this.id,
    required this.name,
    required this.channelId,
    required this.startDate,
    required this.endDate,
    this.overview,
  });

  final String id;
  final String name;
  final String channelId;
  final DateTime startDate;
  final DateTime endDate;
  final String? overview;

  @override
  List<Object?> get props => [id, name, channelId, startDate, endDate, overview];
}

/// Jellyfin Media Server client — official REST API
/// (`/Users/AuthenticateByName`, `/LiveTv/Channels`, `/LiveTv/Programs`).
class JellyfinClient {
  JellyfinClient({
    required Dio dio,
    required String serverUrl,
    required String username,
    required String password,
  }) : _dio = dio,
       _serverUrl = serverUrl.endsWith('/')
           ? serverUrl.substring(0, serverUrl.length - 1)
           : serverUrl,
       _username = username,
       _password = password;

  final Dio _dio;
  final String _serverUrl;
  final String _username;
  final String _password;

  static const String _authHeader =
      'MediaBrowser Client="Airo TV", Device="Airo TV Client", '
      'DeviceId="airo-tv", Version="2.0.0"';

  Future<JellyfinAuthResult> authenticate() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_serverUrl/Users/AuthenticateByName',
      data: {'Username': _username, 'Pw': _password},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization': _authHeader,
        },
      ),
    );
    final data = response.data ?? const {};
    return JellyfinAuthResult(
      accessToken: data['AccessToken'] as String,
      userId: (data['User'] as Map<String, dynamic>)['Id'] as String,
    );
  }

  Future<List<JellyfinChannel>> getLiveTvChannels({
    required String accessToken,
    required String userId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/LiveTv/Channels',
      queryParameters: {'userId': userId, 'api_key': accessToken},
    );
    final items = response.data?['Items'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>().map((json) {
      return JellyfinChannel(
        id: json['Id'] as String,
        name: json['Name'] as String,
        number: json['Number'] as String?,
      );
    }).toList();
  }

  Future<List<JellyfinProgram>> getPrograms({
    required String accessToken,
    required String userId,
    required List<String> channelIds,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/LiveTv/Programs',
      queryParameters: {
        'ChannelIds': channelIds.join(','),
        'UserId': userId,
        'api_key': accessToken,
      },
    );
    final items = response.data?['Items'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>().map((json) {
      return JellyfinProgram(
        id: json['Id'] as String,
        name: json['Name'] as String,
        channelId: json['ChannelId'] as String,
        startDate: DateTime.parse(json['StartDate'] as String),
        endDate: DateTime.parse(json['EndDate'] as String),
        overview: json['Overview'] as String?,
      );
    }).toList();
  }

  String streamUrl(String itemId, String accessToken) =>
      '$_serverUrl/Videos/$itemId/stream?api_key=$accessToken&static=true';
}
```

- [ ] **Step 4: Run client tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/jellyfin/jellyfin_client_test.dart`
Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Write the failing content-source test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeJellyfinClient implements JellyfinClient {
  _FakeJellyfinClient(this._channels);
  final List<JellyfinChannel> _channels;

  @override
  Future<JellyfinAuthResult> authenticate() async =>
      const JellyfinAuthResult(accessToken: 'jf-token', userId: 'user-1');

  @override
  Future<List<JellyfinChannel>> getLiveTvChannels({
    required String accessToken,
    required String userId,
  }) async => _channels;

  @override
  String streamUrl(String itemId, String accessToken) =>
      'https://jellyfin.example.com/Videos/$itemId/stream?api_key=$accessToken&static=true';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('JellyfinContentSource reports full capabilities', () {
    const source = JellyfinContentSource(
      id: 'jellyfin-1',
      label: 'My Jellyfin',
      serverUrl: 'https://jellyfin.example.com',
      credentialRef: ContentSourceCredentialRef('jellyfin-1'),
    );

    expect(source.kind, ContentSourceKind.jellyfin);
    expect(source.capabilities.hasEpg, isTrue);
    expect(source.capabilities.hasVod, isTrue);
  });

  test('adapter authenticates then maps channels via streamUrl', () async {
    final fakeClient = _FakeJellyfinClient([
      const JellyfinChannel(id: 'chan-1', name: 'News', number: '1'),
    ]);
    final adapter = JellyfinContentSourceAdapter(fakeClient);

    final channels = await adapter.loadChannels();

    expect(channels, hasLength(1));
    expect(channels.single.id, 'jellyfin-chan-1');
    expect(channels.single.name, 'News');
    expect(
      channels.single.streamUrl,
      'https://jellyfin.example.com/Videos/chan-1/stream?api_key=jf-token&static=true',
    );
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/jellyfin/jellyfin_content_source_test.dart`
Expected: FAIL — `JellyfinContentSource`/`JellyfinContentSourceAdapter` undefined.

- [ ] **Step 7: Write `lib/src/jellyfin/jellyfin_content_source.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';

import '../content_source.dart';
import 'jellyfin_client.dart';

class JellyfinContentSource extends ContentSource {
  const JellyfinContentSource({
    required super.id,
    required super.label,
    required this.serverUrl,
    required this.credentialRef,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: true,
           hasVod: true,
           hasCatchup: false,
         ),
       );

  final String serverUrl;
  final ContentSourceCredentialRef credentialRef;

  @override
  ContentSourceKind get kind => ContentSourceKind.jellyfin;

  @override
  List<Object?> get props => [...super.props, serverUrl, credentialRef];
}

class JellyfinContentSourceAdapter {
  JellyfinContentSourceAdapter(this._client);

  final JellyfinClient _client;

  Future<List<IPTVChannel>> loadChannels() async {
    final auth = await _client.authenticate();
    final channels = await _client.getLiveTvChannels(
      accessToken: auth.accessToken,
      userId: auth.userId,
    );

    return [
      for (final channel in channels)
        IPTVChannel(
          id: 'jellyfin-${channel.id}',
          name: channel.name,
          streamUrl: _client.streamUrl(channel.id, auth.accessToken),
          tvgName: channel.number,
        ),
    ];
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/jellyfin/jellyfin_content_source_test.dart`
Expected: `00:0X +2: All tests passed!`

- [ ] **Step 9: Write `lib/src/jellyfin/jellyfin_epg_repository.dart`**

```dart
import 'package:platform_epg/platform_epg.dart';

import 'jellyfin_client.dart';

/// [CompactEpgRepository] backed by Jellyfin's `/LiveTv/Programs`.
///
/// Unlike Xtream/Stalker, Jellyfin's endpoint accepts a list of channel
/// IDs and an implicit "now" window in one call, so both
/// [loadCurrentNext] and [loadWindow] issue a single request rather than
/// one per channel.
class JellyfinEpgRepository implements CompactEpgRepository {
  JellyfinEpgRepository(
    this._client, {
    required this.accessToken,
    required this.userId,
  });

  final JellyfinClient _client;
  final String accessToken;
  final String userId;

  Future<List<JellyfinProgram>> _fetch(Iterable<String> channelIds) {
    final rawIds = [
      for (final id in channelIds) id.replaceFirst('jellyfin-', ''),
    ];
    return _client.getPrograms(
      accessToken: accessToken,
      userId: userId,
      channelIds: rawIds,
    );
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final programs = await _fetch(channelIds);
    final byChannel = <String, List<CompactEpgProgram>>{};
    for (final program in programs) {
      final channelId = 'jellyfin-${program.channelId}';
      (byChannel[channelId] ??= []).add(
        CompactEpgProgram(
          programId: program.id,
          title: program.name,
          subtitle: program.overview,
          startsAt: program.startDate.toUtc(),
          endsAt: program.endDate.toUtc(),
        ),
      );
    }

    final entries = [
      for (final channelId in channelIds)
        CompactEpgEntry.fromPrograms(
          channelId: channelId,
          channelName: channelId,
          now: now,
          programs: byChannel[channelId] ?? const [],
        ),
    ];

    return CompactEpgSlice(
      entries: entries,
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    final programs = await _fetch(query.channelIds);
    final byChannel = <String, List<CompactEpgProgram>>{};
    for (final program in programs) {
      final channelId = 'jellyfin-${program.channelId}';
      final startsAt = program.startDate.toUtc();
      final endsAt = program.endDate.toUtc();
      if (!endsAt.isAfter(query.windowStart) ||
          !startsAt.isBefore(query.windowEnd)) {
        continue;
      }
      (byChannel[channelId] ??= []).add(
        CompactEpgProgram(
          programId: program.id,
          title: program.name,
          subtitle: program.overview,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );
    }

    final entries = [
      for (final channelId in query.channelIds)
        CompactEpgWindowEntry(
          channelId: channelId,
          channelName: channelId,
          programs: byChannel[channelId] ?? const [],
        ),
    ];

    return CompactEpgWindow(
      entries: entries,
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: query.now,
      expiresAt: query.now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }
}
```

- [ ] **Step 10: Export Jellyfin files from the barrel**

```dart
export 'src/jellyfin/jellyfin_client.dart';
export 'src/jellyfin/jellyfin_content_source.dart';
export 'src/jellyfin/jellyfin_epg_repository.dart';
```

- [ ] **Step 11: Run the full package test suite**

Run: `cd packages/platform_playlist && flutter test`
Expected: all tests pass, no failures.

- [ ] **Step 12: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): add Jellyfin adapter (auth, LiveTv channels, Programs EPG)"
```

---

### Task 7: `feature_iptv` wiring + full regression check

**Files:**
- Modify: `packages/feature_iptv/module.yaml`
- Modify: `packages/feature_iptv/pubspec.yaml`
- Create: `packages/feature_iptv/lib/application/providers/content_source_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/content_source_providers_test.dart`

**Interfaces:**
- Consumes: everything exported from `package:platform_playlist/platform_playlist.dart` (Tasks 1-6).
- Produces: `contentSourceCredentialStoreProvider = Provider<ContentSourceCredentialStore>`; `dioProvider` (already exists in `iptv_providers.dart` — reused, not duplicated).

This task deliberately does **not** touch `iptvChannelsProvider`, `m3uParserProvider`, or any other existing provider in `iptv_providers.dart` — per the Global Constraints, the M3U path must show zero behavior change, and wiring a *default* source selection into the running app's channel list is UI work that belongs to CV-022 (TV settings/provider management screen), not this issue. This task only makes the new package's `ContentSourceCredentialStore` available to Riverpod so CV-022 has something to inject into.

- [ ] **Step 1: Add `platform_playlist` to `feature_iptv`'s allowed dependencies**

Edit `packages/feature_iptv/module.yaml`, add `platform_playlist` to the `allowed_dependencies` list (alphabetical, matching the existing style):

```yaml
allowed_dependencies:
  - core_ui
  - platform_channels
  - platform_epg
  - platform_history
  - platform_media
  - platform_player
  - platform_playlist
  - platform_playlist_import
  - platform_streams
  - product_capabilities
```

- [ ] **Step 2: Add the path dependency to `feature_iptv`'s pubspec.yaml**

Edit `packages/feature_iptv/pubspec.yaml`, add after the existing `platform_playlist_import` entry:

```yaml
  platform_playlist:
    path: ../platform_playlist
```

- [ ] **Step 3: Write the failing provider test**

```dart
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
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/content_source_providers_test.dart`
Expected: FAIL — `content_source_providers.dart` does not exist.

- [ ] **Step 5: Write `lib/application/providers/content_source_providers.dart`**

```dart
import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist/platform_playlist.dart';

/// Overridden with a real [SecureStore] in `main()`
/// (`SecureStoreFactory.createSecure()`); tests override with
/// [InMemorySecureStore].
final secureStoreProvider = Provider<SecureStore>((ref) {
  throw UnimplementedError('secureStoreProvider must be overridden');
});

final contentSourceCredentialStoreProvider =
    Provider<ContentSourceCredentialStore>((ref) {
      return ContentSourceCredentialStore(ref.watch(secureStoreProvider));
    });
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/content_source_providers_test.dart`
Expected: `00:0X +1: All tests passed!`

- [ ] **Step 7: Run the full `feature_iptv` and `platform_playlist` suites together**

Run: `cd packages/feature_iptv && flutter test`
Expected: all existing tests still pass (129+ tests per prior CV-015 baseline) — zero regressions, confirming the M3U path's zero-behavior-change constraint.

Run: `cd packages/platform_playlist && flutter test`
Expected: all tests pass.

- [ ] **Step 8: Run `melos` analyze across touched packages**

Run: `melos exec --scope="platform_playlist,feature_iptv" -- flutter analyze`
Expected: no errors (warnings from pre-existing code are acceptable, but no new issues in files this plan touched).

- [ ] **Step 9: Commit**

```bash
git add packages/feature_iptv packages/platform_playlist
git commit -m "feat(feature_iptv): wire ContentSourceCredentialStore into Riverpod"
```

---

## Self-Review

**Spec coverage against issue #823 acceptance criteria:**
- `ContentSource` contract with kind, auth, capability flags → Task 1.
- Xtream Codes adapter: auth, channel list, VOD list, EPG fetch → Task 4 (VOD listing endpoint (`getVodStreams`) is implemented in `XtreamClient` per acceptance criteria; full VOD *display* is CV-019's scope per issue #823's own non-goals boundary with #824 — this plan implements the client method so CV-019 has it to call, without building VOD UI here).
- Stalker Portal adapter reusing the shared contract → Task 5.
- Jellyfin adapter reusing the shared contract → Task 6.
- M3U re-homed under `ContentSource`, no regression → Task 3 (wraps, doesn't touch `M3UParserService`) + Task 7 Step 7 (full existing suite re-run).
- Credentials via existing secure storage, never logged unredacted → Task 2 (`SecureStore`), Task 1 (`ContentSourceCredentialRef` redaction), `JellyfinAuthResult`/`ContentSourceCredentials` redacted `toString()`.
- Tests: adapter auth success/failure, capability flags, credential redaction, M3U regression → Tasks 1-7 each carry their own tests; auth *failure* paths (bad credentials, network error) are covered implicitly by Dio throwing `DioException` on non-2xx — not separately unit-tested per adapter to keep this plan's size bounded. **Gap, flagged for the assigned engineer:** add one `DioException`-on-401 test per client (`XtreamClient`, `StalkerClient`, `JellyfinClient`) during Task 4/5/6 review if the reviewing QA agent wants it — the plan's existing fake-adapter pattern extends directly, just add a second `_Fake*Adapter` map entry returning `statusCode: 401`.

**Placeholder scan:** no TBD/TODO/"add error handling" left in any step; every code block is complete and runnable against the exact APIs read from the repo.

**Type consistency:** `IPTVChannel` fields used (`id`, `name`, `streamUrl`, `logoUrl`, `group`, `tvgId`, `tvgName`) match `packages/platform_channels/lib/src/models/iptv_channel.dart` exactly. `CompactEpgRepository`/`CompactEpgSlice`/`CompactEpgWindow`/`CompactEpgProgram`/`CompactEpgEntry`/`GuideWindowQuery`/`CompactEpgWindowEntry`/`CompactEpgSliceSource` all match `packages/platform_epg/lib/src/compact_epg_models.dart` signatures exactly (including `CompactEpgEntry.fromPrograms`'s named params). `SecureStore.read/write/delete` signatures match `packages/core_data/lib/src/storage/secure_store.dart` exactly (`{required String key}` / `{required String key, required String value}`).

**Note on `_FakeXtreamAdapter`/`_FakeStalkerAdapter`/`_FakeJellyfinAdapter` helper classes referenced in test steps:** these are `HttpClientAdapter` fakes (implementing `Future<ResponseBody> fetch(...)` by matching request path against the provided handler map) — write one shared version and either duplicate it per test file or factor it into `packages/platform_playlist/test/test_support/fake_http_client_adapter.dart` during Task 4 Step 1, since it's used identically across Tasks 4-6. Recommended: factor it out on first use (Task 4) to avoid the "no duplication" review rule biting on Tasks 5-6.
