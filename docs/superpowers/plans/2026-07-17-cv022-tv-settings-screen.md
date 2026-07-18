# CV-022 TV Settings & Provider Management Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `_TvSettingsPlaceholder` with a real TV settings screen: a theme switcher, a playback-preferences section, and content-source management (list/add/remove), closing the gap both competitive analyses flagged.

**Architecture:** This plan builds on top of branch `cv015-slice2-epg-grid` (not yet merged to `v2` — PR #840 open), because `XmltvSourceSheet` was explicitly built there "for CV-022 to wire in." The reusable data layer (`ContentSourceStore`, a persisted list of configured `ContentSource`s — confirmed to not exist anywhere in the codebase) lives in `packages/feature_iptv/lib/application`, matching this repo's established pattern (`XmltvSourceStore`, `EpgChannelMatchOverrideStore`). The screen itself and its section widgets live in `app/lib/features/settings/presentation/tv/` — **not** `feature_iptv` — because the theme switcher must consume `appThemeProvider` (`app/lib/core/providers/app_theme_provider.dart`), and `feature_iptv`'s `module.yaml` forbids depending on `app`. This mirrors the existing precedent: the phone `PlaybackSettingsScreen` already lives under `app/lib/features/settings/presentation/screens/`, not in a feature package, for the same reason (it aggregates cross-package concerns). `feature_iptv` supplies the reusable providers/widgets (`videoAspectRatioProvider`, the new source-management providers, `XmltvSourceSheet`); `app` composes them into one screen alongside its own `appThemeProvider`.

**Tech Stack:** Dart 3 classes + `equatable`, Riverpod, `core_data`'s `KeyValueStore`/`PreferencesStore` (matches `XmltvSourceStore`'s pattern exactly), `core_ui`'s `TvFocusable`/`TvUiDimensions`.

## Global Constraints

- Dart SDK `^3.12.2`, Flutter `>=1.17.0`.
- No new package dependencies.
- `packages/platform_epg`/`packages/platform_playlist` are not modified — `ContentSource`/`ContentSourceKind`/`ContentSourceCapabilities`/`ContentSourceCredentialStore` are consumed as-is.
- `ContentSourceStore` lives in `feature_iptv` (data layer), the settings SCREEN lives in `app` (aggregates `app`-level `appThemeProvider` with `feature_iptv`-level providers) — do not attempt to import `app_theme_provider.dart` from `feature_iptv`; `module.yaml`'s `forbidden_dependencies: [app]` blocks it, and importing it anyway would be a real architecture violation, not a lint nit.
- Scope for "add a source" in this slice: **M3U only** (the only source type with no credential-collection UI needed, and the only type actually wired into `iptvChannelsProvider` today — Xtream/Stalker/Jellyfin adapters exist per CV-018 but nothing in the running app constructs/uses them yet, a disclosed gap from that plan). `ContentSourceStore`/`ContentSourceConfig` model all four kinds so Xtream/Stalker/Jellyfin add-forms are additive later work, not a redesign.
- No parental controls / PIN lock / adult-category detection (explicit non-goal, deferred).
- No cloud-synced settings.
- Accessibility preferences (CV-008) and track/quality selection beyond aspect ratio (CV-016) have **zero existing code** anywhere in this repo (confirmed via research) and are **not** in this issue's acceptance criteria (only in scope prose) — the settings screen gets an honest "Accessibility — coming soon" placeholder tile (matching this codebase's own established convention for exactly this situation, e.g. the pre-CV-021 `_TvComingSoonPlaceholder`), not a fabricated feature.
- Tests required per issue #827: theme switch persists and applies, source list renders from provider state, remove-source confirmation flow.

---

## Open-core tier classification

Per the Airo open-core strategy (public `airo` + private `airo-pro` overlay), CV-022's surface splits across three tiers:

| Tier | Component | Location | Rationale |
|------|-----------|----------|-----------|
| **platform** | `ContentSource`, `ContentSourceKind`, `ContentSourceCapabilities`, `ContentSourceCredentialStore` | `packages/platform_playlist/` (pre-existing, consumed as-is) | Foundational contracts shared by every Airo experience; not user-visible. |
| **airo tv** | `ContentSourceConfig`, `ContentSourceStore`, management providers (`configuredContentSourcesProvider`, `addM3uContentSourceProvider`, `removeContentSourceProvider`) | `packages/feature_iptv/lib/application/` | Persistence layer for the TV consumer app. Public tier. |
| **airo tv** | `TvSettingsScreen`, `TvThemeSection`, `TvPlaybackSection`, `TvSourceManagementSection`, `secureStoreProvider` production wiring | `app/lib/features/settings/presentation/tv/`, `app/lib/main_tv.dart` | Airo TV branded settings surface. Public tier. |
| **airo-pro** | Xtream / Stalker / Jellyfin credential-collection add-flows (deferred to CV-032) | future overlay on `TvSourceManagementSection` | Advanced source types = premium overlay: Xtream is commercial-subscription IPTV, Stalker is portal-based provider integration, Jellyfin is power-user self-hosted media — matches the airo-pro billing-via-Entitlements pattern. |

CV-022 (this plan) is entirely **platform + airo tv**. CV-032 layers **airo-pro** on top.

---

## File Structure

```
packages/feature_iptv/
  lib/application/
    content_source_store.dart                        [new]
    providers/content_source_management_providers.dart  [new]
  test/iptv/application/
    content_source_store_test.dart                      [new]
    providers/content_source_management_providers_test.dart [new]

app/
  lib/features/settings/presentation/tv/
    tv_settings_screen.dart                               [new]
    tv_theme_section.dart                                  [new]
    tv_playback_section.dart                                [new]
    tv_source_management_section.dart                        [new]
  lib/core/app/tv_router.dart                                 [modify]
  lib/main_tv.dart                                             [modify]
  test/features/settings/presentation/tv/
    tv_settings_screen_test.dart                                [new]
    tv_theme_section_test.dart                                   [new]
    tv_source_management_section_test.dart                        [new]
```

---

### Task 1: `ContentSourceConfig` + `ContentSourceStore`

**Files:**
- Create: `packages/feature_iptv/lib/application/content_source_store.dart`
- Test: `packages/feature_iptv/test/iptv/application/content_source_store_test.dart`

**Interfaces:**
- Consumes: `KeyValueStore`/`PreferencesStore` (`package:core_data/core_data.dart`), `ContentSourceKind`/`ContentSource`/`M3uContentSource`/`XtreamContentSource`/`StalkerContentSource`/`JellyfinContentSource`/`ContentSourceCredentialRef` (`package:platform_playlist/platform_playlist.dart`).
- Produces: `class ContentSourceConfig extends Equatable { String id; ContentSourceKind kind; String label; String url; String? macAddress; }` (a storage-shaped record — `url` covers both `playlistUrl`/`serverUrl` depending on `kind`; `macAddress` is Stalker-only; credentials for Xtream/Jellyfin are looked up separately via `ContentSourceCredentialStore` using `ContentSourceCredentialRef(config.id)`, never stored inline here); `ContentSourceConfig.toContentSource()`; `class ContentSourceStore { ContentSourceStore(KeyValueStore store); Future<List<ContentSourceConfig>> getAll(); Future<void> add(ContentSourceConfig config); Future<void> remove(String id); }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/content_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ContentSourceStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = ContentSourceStore(PreferencesStore(prefs));
  });

  test('getAll returns empty list when nothing configured', () async {
    expect(await store.getAll(), isEmpty);
  });

  test('add then getAll round-trips an M3U config', () async {
    const config = ContentSourceConfig(
      id: 'm3u-1',
      kind: ContentSourceKind.m3u,
      label: 'My Playlist',
      url: 'https://example.com/playlist.m3u',
    );

    await store.add(config);
    final all = await store.getAll();

    expect(all, [config]);
  });

  test('add then getAll round-trips a Stalker config with macAddress', () async {
    const config = ContentSourceConfig(
      id: 'stalker-1',
      kind: ContentSourceKind.stalker,
      label: 'My Stalker Portal',
      url: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    await store.add(config);
    final all = await store.getAll();

    expect(all.single.macAddress, 'AA:BB:CC:DD:EE:FF');
  });

  test('add appends, does not replace, distinct ids', () async {
    const first = ContentSourceConfig(id: 'a', kind: ContentSourceKind.m3u, label: 'A', url: 'https://a.example.com');
    const second = ContentSourceConfig(id: 'b', kind: ContentSourceKind.m3u, label: 'B', url: 'https://b.example.com');

    await store.add(first);
    await store.add(second);
    final all = await store.getAll();

    expect(all.map((c) => c.id), ['a', 'b']);
  });

  test('remove deletes only the targeted config', () async {
    const first = ContentSourceConfig(id: 'a', kind: ContentSourceKind.m3u, label: 'A', url: 'https://a.example.com');
    const second = ContentSourceConfig(id: 'b', kind: ContentSourceKind.m3u, label: 'B', url: 'https://b.example.com');
    await store.add(first);
    await store.add(second);

    await store.remove('a');
    final all = await store.getAll();

    expect(all.map((c) => c.id), ['b']);
  });

  test('ContentSourceConfig.toContentSource builds the right subtype for m3u', () {
    const config = ContentSourceConfig(
      id: 'm3u-1',
      kind: ContentSourceKind.m3u,
      label: 'My Playlist',
      url: 'https://example.com/playlist.m3u',
    );

    final source = config.toContentSource();

    expect(source, isA<M3uContentSource>());
    expect((source as M3uContentSource).playlistUrl, 'https://example.com/playlist.m3u');
  });

  test('ContentSourceConfig.toContentSource builds StalkerContentSource with macAddress', () {
    const config = ContentSourceConfig(
      id: 'stalker-1',
      kind: ContentSourceKind.stalker,
      label: 'My Stalker Portal',
      url: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final source = config.toContentSource();

    expect(source, isA<StalkerContentSource>());
    expect((source as StalkerContentSource).macAddress, 'AA:BB:CC:DD:EE:FF');
  });

  test('ContentSourceConfig.toContentSource builds XtreamContentSource with a credentialRef keyed on the config id', () {
    const config = ContentSourceConfig(
      id: 'xtream-1',
      kind: ContentSourceKind.xtream,
      label: 'My Xtream',
      url: 'https://xtream.example.com',
    );

    final source = config.toContentSource();

    expect(source, isA<XtreamContentSource>());
    expect((source as XtreamContentSource).credentialRef, const ContentSourceCredentialRef('xtream-1'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/content_source_store_test.dart`
Expected: FAIL — `ContentSourceStore`/`ContentSourceConfig` undefined.

- [ ] **Step 3: Write `lib/application/content_source_store.dart`**

```dart
import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';
import 'package:platform_playlist/platform_playlist.dart';

/// A user-configured content source, in storage-shaped form. [url] covers
/// both [M3uContentSource.playlistUrl] and the `serverUrl` field the
/// Xtream/Stalker/Jellyfin variants share. [macAddress] is Stalker-only.
/// Xtream/Jellyfin credentials are never stored here — they live in
/// [ContentSourceCredentialStore], looked up via
/// `ContentSourceCredentialRef(id)` at [toContentSource] time.
class ContentSourceConfig extends Equatable {
  const ContentSourceConfig({
    required this.id,
    required this.kind,
    required this.label,
    required this.url,
    this.macAddress,
  });

  final String id;
  final ContentSourceKind kind;
  final String label;
  final String url;
  final String? macAddress;

  factory ContentSourceConfig.fromJson(Map<String, dynamic> json) {
    return ContentSourceConfig(
      id: json['id'] as String,
      kind: ContentSourceKind.values.firstWhere(
        (k) => k.stableId == json['kind'] as String,
      ),
      label: json['label'] as String,
      url: json['url'] as String,
      macAddress: json['macAddress'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.stableId,
    'label': label,
    'url': url,
    if (macAddress != null) 'macAddress': macAddress,
  };

  /// Builds the concrete [ContentSource] this config describes. Xtream and
  /// Jellyfin sources' credentials are NOT included here — the returned
  /// source only carries a [ContentSourceCredentialRef], never the raw
  /// secret; callers needing to authenticate must separately read
  /// [ContentSourceCredentialStore] using that same ref.
  ContentSource toContentSource() {
    switch (kind) {
      case ContentSourceKind.m3u:
        return M3uContentSource(id: id, label: label, playlistUrl: url);
      case ContentSourceKind.xtream:
        return XtreamContentSource(
          id: id,
          label: label,
          serverUrl: url,
          credentialRef: ContentSourceCredentialRef(id),
        );
      case ContentSourceKind.stalker:
        return StalkerContentSource(
          id: id,
          label: label,
          serverUrl: url,
          macAddress: macAddress ?? '',
        );
      case ContentSourceKind.jellyfin:
        return JellyfinContentSource(
          id: id,
          label: label,
          serverUrl: url,
          credentialRef: ContentSourceCredentialRef(id),
        );
    }
  }

  @override
  List<Object?> get props => [id, kind, label, url, macAddress];
}

/// Persists the list of content sources a user has configured. Same
/// `KeyValueStore`-wrapping pattern as `XmltvSourceStore`
/// (`packages/feature_iptv/lib/application/xmltv_source_store.dart`), scaled
/// to a list rather than a single value.
class ContentSourceStore {
  ContentSourceStore(this._store);

  static const String _storageKey = 'content_sources';

  final KeyValueStore _store;

  Future<List<ContentSourceConfig>> getAll() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return [];
    final decoded = jsonDecode(json) as List;
    return decoded
        .map((item) => ContentSourceConfig.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(ContentSourceConfig config) async {
    final all = await getAll();
    all.add(config);
    await _save(all);
  }

  Future<void> remove(String id) async {
    final all = await getAll();
    all.removeWhere((c) => c.id == id);
    await _save(all);
  }

  Future<void> _save(List<ContentSourceConfig> configs) async {
    await _store.setString(
      _storageKey,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/content_source_store_test.dart`
Expected: `00:00 +8: All tests passed!`

- [ ] **Step 5: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass (baseline is this branch's current count — run `flutter test` once before this task to record the exact starting number, since this plan builds on the still-unmerged `cv015-slice2-epg-grid` branch, not `v2`), no regressions.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/content_source_store.dart packages/feature_iptv/test/iptv/application/content_source_store_test.dart
git commit -m "feat(feature_iptv): add ContentSourceConfig + ContentSourceStore"
```

---

### Task 2: Content-source management providers

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/content_source_management_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/content_source_management_providers_test.dart`

**Interfaces:**
- Consumes: `ContentSourceStore`/`ContentSourceConfig` (Task 1), `sharedPreferencesProvider` (`iptv_providers.dart`, existing — **read-only reuse, this task does not modify `iptv_providers.dart`**), `secureStoreProvider`/`contentSourceCredentialStoreProvider` (`content_source_providers.dart`, existing, read-only reuse).
- Produces: `contentSourceStoreProvider = Provider<ContentSourceStore>`; `configuredContentSourcesProvider = FutureProvider<List<ContentSourceConfig>>`; `addM3uContentSourceProvider = FutureProvider.family<void, ({String label, String url})>` (adds a new M3U `ContentSourceConfig`, generating a stable id, then invalidates `configuredContentSourcesProvider`); `removeContentSourceProvider = FutureProvider.family<void, String>` (removes by id, then invalidates the list; also deletes any stored credential via `contentSourceCredentialStoreProvider.delete(ContentSourceCredentialRef(id))`, since a removed source's leftover credential is otherwise an orphaned secret with no owner).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_iptv/application/content_source_store.dart';
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/content_source_management_providers_test.dart`
Expected: FAIL — `content_source_management_providers.dart` does not exist.

- [ ] **Step 3: Write `lib/application/providers/content_source_management_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_data/core_data.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../content_source_store.dart';
import 'content_source_providers.dart';
import 'iptv_providers.dart';

final contentSourceStoreProvider = Provider<ContentSourceStore>((ref) {
  return ContentSourceStore(PreferencesStore(ref.watch(sharedPreferencesProvider)));
});

final configuredContentSourcesProvider = FutureProvider<List<ContentSourceConfig>>((ref) async {
  return ref.watch(contentSourceStoreProvider).getAll();
});

final addM3uContentSourceProvider = FutureProvider.family<void, ({String label, String url})>((
  ref,
  args,
) async {
  final id = 'm3u-${DateTime.now().microsecondsSinceEpoch}';
  await ref.watch(contentSourceStoreProvider).add(
    ContentSourceConfig(
      id: id,
      kind: ContentSourceKind.m3u,
      label: args.label,
      url: args.url,
    ),
  );
  ref.invalidate(configuredContentSourcesProvider);
});

final removeContentSourceProvider = FutureProvider.family<void, String>((ref, id) async {
  await ref.watch(contentSourceStoreProvider).remove(id);
  await ref.watch(contentSourceCredentialStoreProvider).delete(ContentSourceCredentialRef(id));
  ref.invalidate(configuredContentSourcesProvider);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/content_source_management_providers_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 5: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/content_source_management_providers.dart packages/feature_iptv/test/iptv/application/providers/content_source_management_providers_test.dart
git commit -m "feat(feature_iptv): add content-source management providers (list, add M3U, remove)"
```

---

### Task 3: TV settings screen shell + router wiring

**Files:**
- Create: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- Modify: `app/lib/core/app/tv_router.dart`
- Test: `app/test/features/settings/presentation/tv/tv_settings_screen_test.dart`

**Interfaces:**
- Produces: `class TvSettingsScreen extends ConsumerStatefulWidget` — a sectioned screen with a left-hand list of section names (Theme, Playback, Sources, Accessibility) and a right-hand detail pane showing the selected section's widget (Tasks 4-6 fill these in; this task stubs each pane with a `Text` placeholder so the shell itself is independently testable, then Tasks 4-6 replace the stubs).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/settings/presentation/tv/tv_settings_screen.dart';

void main() {
  testWidgets('renders all four section names and shows Theme selected by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TvSettingsScreen()));
    await tester.pump();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Playback'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Accessibility'), findsOneWidget);
  });

  testWidgets('tapping a section name switches the detail pane', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TvSettingsScreen()));
    await tester.pump();

    await tester.tap(find.text('Sources'));
    await tester.pump();

    // With Tasks 4-6's real content not yet built, this task's own stub
    // panes are distinguishable by a key — adjust this assertion once the
    // real Sources section widget exists in Task 6 (its own test covers
    // the real content; this test only proves the shell's navigation).
    expect(find.byKey(const ValueKey('tv_settings_section_sources')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_settings_screen_test.dart`
Expected: FAIL — `tv_settings_screen.dart` does not exist.

- [ ] **Step 3: Write `lib/features/settings/presentation/tv/tv_settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

enum _TvSettingsSection { theme, playback, sources, accessibility }

/// TV Settings screen (CV-022): a left-hand section list, right-hand detail
/// pane. Task 3 stubs each pane; Tasks 4-6 replace the stubs with real
/// section widgets (`TvThemeSection`, `TvPlaybackSection`,
/// `TvSourceManagementSection`).
class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  _TvSettingsSection _selected = _TvSettingsSection.theme;

  static const _sections = [
    (_TvSettingsSection.theme, 'Theme', Icons.palette_outlined),
    (_TvSettingsSection.playback, 'Playback', Icons.play_circle_outline),
    (_TvSettingsSection.sources, 'Sources', Icons.dns_outlined),
    (_TvSettingsSection.accessibility, 'Accessibility', Icons.accessibility_new_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final (section, label, icon) in _sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TvFocusable(
                        autofocus: section == _TvSettingsSection.theme,
                        onSelect: () => setState(() => _selected = section),
                        semanticLabel: label,
                        semanticButton: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: section == _selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(icon, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(label, style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: Padding(padding: const EdgeInsets.all(24), child: _buildDetail())),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail() {
    switch (_selected) {
      case _TvSettingsSection.theme:
        return const SizedBox(key: ValueKey('tv_settings_section_theme'));
      case _TvSettingsSection.playback:
        return const SizedBox(key: ValueKey('tv_settings_section_playback'));
      case _TvSettingsSection.sources:
        return const SizedBox(key: ValueKey('tv_settings_section_sources'));
      case _TvSettingsSection.accessibility:
        return const _AccessibilityComingSoon();
    }
  }
}

class _AccessibilityComingSoon extends StatelessWidget {
  const _AccessibilityComingSoon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Accessibility', style: TextStyle(color: Colors.white, fontSize: 20)),
          SizedBox(height: 8),
          Text('Coming soon', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_settings_screen_test.dart`
Expected: `00:00 +2: All tests passed!`

- [ ] **Step 5: Wire into `app/lib/core/app/tv_router.dart`**

Read the file first (it's actively evolving on `origin/main` per this session's other concurrent work — re-derive the exact current Settings `GoRoute` and `_TvSettingsPlaceholder` class before editing, don't assume line numbers). Replace:

```dart
GoRoute(
  path: TvRouteNames.settings,
  name: 'tv_settings',
  builder: (context, state) => const _TvSettingsPlaceholder(),
),
```

with:

```dart
GoRoute(
  path: TvRouteNames.settings,
  name: 'tv_settings',
  builder: (context, state) => const TvSettingsScreen(),
),
```

Add the import: `import 'package:app/features/settings/presentation/tv/tv_settings_screen.dart';` (adjust to this file's actual relative-import convention — check whether `tv_router.dart` uses `package:app/...` imports or relative `../../` imports elsewhere in the same file, and match it). Remove the now-unused `_TvSettingsPlaceholder` class declaration only if nothing else references it (grep first).

- [ ] **Step 6: Run the `app` test suite covering the router**

Run: `find app/test -iname "*tv_router*"` then run that file.
Expected: passes, reflecting the new route builder (update any test that literally asserted `_TvSettingsPlaceholder` renders — it should now assert `TvSettingsScreen` renders instead; read the existing test first, don't guess its assertions).

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/settings/presentation/tv/tv_settings_screen.dart app/lib/core/app/tv_router.dart app/test/features/settings/presentation/tv/tv_settings_screen_test.dart
git commit -m "feat(app): add TV settings screen shell, wire into router"
```

(If `tv_router_test.dart` needed updates, include it in this commit too.)

---

### Task 4: Theme section

**Files:**
- Create: `app/lib/features/settings/presentation/tv/tv_theme_section.dart`
- Modify: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- Test: `app/test/features/settings/presentation/tv/tv_theme_section_test.dart`

**Interfaces:**
- Consumes: `appThemeProvider`/`AppThemeNotifier` (`app/lib/core/providers/app_theme_provider.dart`, existing — read-only reuse), `AppThemeId`/`AppTheme` (`package:core_ui/core_ui.dart`).
- Produces: `class TvThemeSection extends ConsumerWidget` — a D-pad-navigable list of the 4 `AppThemeId`s, current selection highlighted, selecting one calls `ref.read(appThemeProvider.notifier).setTheme(id)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/providers/app_theme_provider.dart';
import 'package:app/features/settings/presentation/tv/tv_theme_section.dart';
import 'package:core_ui/core_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('lists all four theme names', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: Scaffold(body: TvThemeSection()))),
    );
    await tester.pump();
    await tester.pump();

    for (final id in AppThemeId.values) {
      expect(find.text(AppTheme.byId(id).name), findsOneWidget);
    }
  });

  testWidgets('selecting a theme persists it via appThemeProvider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvThemeSection())),
      ),
    );
    await tester.pump();
    await tester.pump();

    final targetId = AppThemeId.values.firstWhere((id) => id != container.read(appThemeProvider));
    await tester.tap(find.text(AppTheme.byId(targetId).name));
    await tester.pump();

    expect(container.read(appThemeProvider), targetId);
  });
}
```

Check `AppThemeDefinition`'s exact field for a display name (the brief's research called it `.name` loosely — confirm the actual field on `AppThemeDefinition` in `packages/core_ui/lib/src/theme/app_theme.dart` before writing this test; it may be `displayName` or similar, don't guess).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_theme_section_test.dart`
Expected: FAIL — `tv_theme_section.dart` does not exist.

- [ ] **Step 3: Write `lib/features/settings/presentation/tv/tv_theme_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

import '../../../../core/providers/app_theme_provider.dart';

/// Theme picker for the TV settings screen (CV-022). Reuses the same
/// [appThemeProvider] the phone profile screen's theme picker already
/// consumes — no new persistence.
class TvThemeSection extends ConsumerWidget {
  const TvThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeProvider);

    return ListView.separated(
      itemCount: AppThemeId.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final id = AppThemeId.values[index];
        final definition = AppTheme.byId(id);
        final isSelected = id == current;
        return TvFocusable(
          autofocus: index == 0,
          onSelect: () => ref.read(appThemeProvider.notifier).setTheme(id),
          semanticLabel: definition.name,
          semanticButton: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(definition.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const Spacer(),
                  if (isSelected) const Icon(Icons.check, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

Confirm `AppThemeDefinition`'s display-name field name against the actual source before writing this (adjust `.name` to whatever it actually is).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_theme_section_test.dart`
Expected: `00:00 +2: All tests passed!`

- [ ] **Step 5: Wire into `TvSettingsScreen`'s theme pane**

In `tv_settings_screen.dart`, replace `case _TvSettingsSection.theme: return const SizedBox(key: ValueKey('tv_settings_section_theme'));` with `case _TvSettingsSection.theme: return const TvThemeSection();` and add the import. `TvSettingsScreen` currently extends `StatelessWidget`'s sibling `State<TvSettingsScreen>` (not a `ConsumerWidget`) — since `TvThemeSection` needs Riverpod, either wrap just this pane in a `Consumer`/`ProviderScope` boundary or convert `_TvSettingsScreenState`'s `build` to read via a `Consumer` — check whether `TvSettingsScreen` needs to become `ConsumerStatefulWidget` outright (simplest, matches every other screen in this codebase) and do that conversion now rather than patching around it.

- [ ] **Step 6: Update Task 3's shell test for the new pane content**

The Task 3 test asserted `find.byKey(const ValueKey('tv_settings_section_sources'))` for the Sources stub — Theme's stub key assertion (if any) needs updating since the Theme pane is no longer a bare `SizedBox`. Re-run Task 3's test file and fix any assertion that broke.

- [ ] **Step 7: Run the full `app` test suite**

Run: `cd app && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/settings/presentation/tv/tv_theme_section.dart app/lib/features/settings/presentation/tv/tv_settings_screen.dart app/test/features/settings/presentation/tv/
git commit -m "feat(app): add TV theme picker section"
```

---

### Task 5: Playback section (+ Accessibility placeholder, already built in Task 3)

**Files:**
- Create: `app/lib/features/settings/presentation/tv/tv_playback_section.dart`
- Modify: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- Test: `app/test/features/settings/presentation/tv/tv_playback_section_test.dart`

**Interfaces:**
- Consumes: `videoAspectRatioProvider`/`VideoAspectRatioNotifier` (`package:feature_iptv/feature_iptv.dart` — confirm exported from the barrel; if not, add it), `AiroPlaybackViewFit`.
- Produces: `class TvPlaybackSection extends ConsumerWidget` — a D-pad-navigable list of `AiroPlaybackViewFit.values`, current selection highlighted, selecting one calls `ref.read(videoAspectRatioProvider.notifier).setAspectRatio(fit)`. Same structural shape as `TvThemeSection` (Task 4) — copy its pattern, don't invent a new one.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/settings/presentation/tv/tv_playback_section.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  testWidgets('lists every AiroPlaybackViewFit option', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    // Check the widget tree renders one row per fit value without crashing;
    // exact label text depends on AiroPlaybackViewFit's display strings —
    // confirm those against the enum before asserting specific text.
  });

  testWidgets('selecting a fit option updates videoAspectRatioProvider', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    final target = AiroPlaybackViewFit.values.firstWhere(
      (fit) => fit != container.read(videoAspectRatioProvider),
    );
    // Tap by index rather than text, since the exact label string needs
    // confirming against the widget's own rendering — check the real
    // ListTile/row text content once TvPlaybackSection is implemented and
    // adjust this test to tap the correct target.
  });
}
```

Note: this test is deliberately left slightly open-ended on exact label text — check `AiroPlaybackViewFit`'s values/display strings (grep it in `packages/feature_iptv` or `platform_streams`) before finalizing both the test and the widget, then tighten the test's assertions to real text once known, matching `TvThemeSection`'s test pattern exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_playback_section_test.dart`
Expected: FAIL — `tv_playback_section.dart` does not exist.

- [ ] **Step 3: Write `lib/features/settings/presentation/tv/tv_playback_section.dart`**

Mirror `TvThemeSection`'s exact structure (Task 4), swapping `AppThemeId.values`/`appThemeProvider` for `AiroPlaybackViewFit.values`/`videoAspectRatioProvider`. Use whatever display-string mechanism `AiroPlaybackViewFit` already exposes (a `.label`/`.displayName` getter, or a local `switch` mapping each value to a string if the enum has none — check first).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_playback_section_test.dart`
Expected: all tests passing.

- [ ] **Step 5: Wire into `TvSettingsScreen`'s playback pane** (same pattern as Task 4 Step 5)

- [ ] **Step 6: Run the full `app` test suite**

Run: `cd app && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/settings/presentation/tv/tv_playback_section.dart app/lib/features/settings/presentation/tv/tv_settings_screen.dart app/test/features/settings/presentation/tv/tv_playback_section_test.dart
git commit -m "feat(app): add TV playback preferences section"
```

---

### Task 6: Source management section

**Files:**
- Create: `app/lib/features/settings/presentation/tv/tv_source_management_section.dart`
- Modify: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- Test: `app/test/features/settings/presentation/tv/tv_source_management_section_test.dart`

**Interfaces:**
- Consumes: `configuredContentSourcesProvider`/`addM3uContentSourceProvider`/`removeContentSourceProvider` (Task 2), `XmltvSourceSheet` (from `cv015-slice2-epg-grid` — `package:feature_iptv/feature_iptv.dart`, already exported there per that plan's Task 6).
- Produces: `class TvSourceManagementSection extends ConsumerWidget` — lists configured `ContentSourceConfig`s (label + kind badge), each row has a "Remove" action gated behind a confirmation dialog (`AlertDialog` with Cancel/Remove buttons — the issue's explicit "remove-source confirmation flow" acceptance criterion), plus an "Add M3U source" button opening a small inline form (label + URL fields, matching `XmltvSourceSheet`'s form shape), plus a separate "XMLTV Guide Source" subsection embedding `XmltvSourceSheet()` directly (distinct concept from `ContentSource`s — the EPG data source, not a channel/VOD source).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/settings/presentation/tv/tv_source_management_section.dart';
import 'package:feature_iptv/feature_iptv.dart';
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

  testWidgets('shows empty state when nothing is configured', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvSourceManagementSection())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No sources configured'), findsOneWidget);
  });

  testWidgets('adding an M3U source shows it in the list', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvSourceManagementSection())),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Add M3U Source'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'My Playlist');
    await tester.enterText(find.widgetWithText(TextField, 'Playlist URL'), 'https://example.com/playlist.m3u');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('My Playlist'), findsOneWidget);
  });

  testWidgets('removing a source requires confirmation', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(
      addM3uContentSourceProvider((label: 'My Playlist', url: 'https://example.com/playlist.m3u')).future,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvSourceManagementSection())),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    // Confirmation dialog shown, source not yet removed.
    expect(find.text('My Playlist'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump();

    final sources = await container.read(configuredContentSourcesProvider.future);
    expect(sources, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_source_management_section_test.dart`
Expected: FAIL — `tv_source_management_section.dart` does not exist.

- [ ] **Step 3: Write `lib/features/settings/presentation/tv/tv_source_management_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:feature_iptv/feature_iptv.dart';

/// Content-source management section (CV-022): list configured sources,
/// add an M3U source, remove any source (with confirmation). The XMLTV
/// guide source (a separate concept — EPG data, not a channel/VOD source)
/// is managed via the embedded [XmltvSourceSheet], built for exactly this
/// purpose in CV-015 slice 2.
class TvSourceManagementSection extends ConsumerStatefulWidget {
  const TvSourceManagementSection({super.key});

  @override
  ConsumerState<TvSourceManagementSection> createState() => _TvSourceManagementSectionState();
}

class _TvSourceManagementSectionState extends ConsumerState<TvSourceManagementSection> {
  bool _showAddForm = false;
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final label = _labelController.text.trim();
    final url = _urlController.text.trim();
    if (label.isEmpty || url.isEmpty) return;

    await ref.read(addM3uContentSourceProvider((label: label, url: url)).future);
    if (!mounted) return;
    setState(() {
      _showAddForm = false;
      _labelController.clear();
      _urlController.clear();
    });
  }

  Future<void> _confirmRemove(ContentSourceConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${config.label}"?'),
        content: const Text('This removes the source and any saved credentials.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(removeContentSourceProvider(config.id).future);
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(configuredContentSourcesProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content Sources', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          sourcesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Could not load sources: $error'),
            data: (sources) {
              if (sources.isEmpty) {
                return const Text('No sources configured yet.');
              }
              return Column(
                children: [
                  for (final config in sources)
                    ListTile(
                      title: Text(config.label),
                      subtitle: Text(config.kind.stableId),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmRemove(config),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_showAddForm)
            FilledButton(
              onPressed: () => setState(() => _showAddForm = true),
              child: const Text('Add M3U Source'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'Playlist URL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(onPressed: _addSource, child: const Text('Save')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _showAddForm = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const XmltvSourceSheet(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/features/settings/presentation/tv/tv_source_management_section_test.dart`
Expected: all tests passing.

- [ ] **Step 5: Wire into `TvSettingsScreen`'s sources pane** (same pattern as Task 4 Step 5)

- [ ] **Step 6: Run the full `app` test suite**

Run: `cd app && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/settings/presentation/tv/tv_source_management_section.dart app/lib/features/settings/presentation/tv/tv_settings_screen.dart app/test/features/settings/presentation/tv/tv_source_management_section_test.dart
git commit -m "feat(app): add TV content-source management section (list, add M3U, remove, XMLTV guide source)"
```

---

### Task 7: `secureStoreProvider` production wiring + full regression

**Files:**
- Modify: `app/lib/main_tv.dart`

**Interfaces:**
- Consumes: `secureStoreProvider` (`feature_iptv`'s `content_source_providers.dart`, existing — currently throws `UnimplementedError` unconditionally because nothing overrides it in production), `SecureStoreFactory` (`package:core_data/core_data.dart`).

**Why this belongs in this plan:** `ContentSourceCredentialStore` (used by `removeContentSourceProvider` in Task 2, and needed by any future Xtream/Jellyfin add-form) is unusable in the running app today — `secureStoreProvider` has never been overridden anywhere in `main_tv.dart`, so any code path touching it throws. This is a one-line, high-value fix, cheap enough to fold into this plan's final task rather than leaving it as a silent trap the way the CV-022 research flagged for `mutableXmltvCompactEpgRepositoryProvider` in the prior plan.

- [ ] **Step 1: Add the override**

In `app/lib/main_tv.dart`'s `ProviderScope(overrides: [...])` list (read the file first for its current exact shape — it already has several EPG-related overrides from CV-015 slice 2), add:

```dart
secureStoreProvider.overrideWithValue(SecureStoreFactory.createSecure()),
```

Import `content_source_providers.dart`'s `secureStoreProvider` if not already in scope via the `feature_iptv` barrel (check first).

- [ ] **Step 2: Run `app`'s test suite covering `main_tv.dart`**

Run: `find app/test -iname "*main_tv*"` then run that file.
Expected: passes. If any existing test asserts the full override list's exact contents/count, it may need a one-line update — read it first.

- [ ] **Step 3: Run the full test suite across all touched packages**

Run:
```bash
cd packages/feature_iptv && flutter test
cd ../../app && flutter test
```
Expected: all green.

- [ ] **Step 4: Manual verification**

Use the `run-airo-tv` skill (if available in this environment) or `flutter run -d macos --target=lib/main_tv.dart` to launch the TV app, navigate to Settings, confirm: the theme switcher actually changes the app's visible theme, adding an M3U source shows it in the list, removing it asks for confirmation and then disappears, the XMLTV source sheet renders. If a real run isn't feasible in this environment, note that explicitly in the report rather than skipping verification silently.

- [ ] **Step 5: Commit**

```bash
git add app/lib/main_tv.dart
git commit -m "feat(app): wire secureStoreProvider to a real SecureStore in production"
```

---

## Self-Review

**Spec coverage against issue #827 acceptance criteria:**
- TV Settings route renders real, navigable content → Task 3.
- Theme switcher among the 4 registered `AppThemeId`s → Task 4.
- Source list shows configured sources, degrades gracefully to M3U-only before CV-018's other kinds have UI → Task 6 (list is generic over all 4 `ContentSourceKind`s via `ContentSourceConfig`, only the *add* flow is M3U-scoped for this slice — disclosed and justified in Global Constraints).
- Add/edit/remove a source → Task 2 (add/remove providers), Task 6 (UI). "Edit" is not separately implemented (issue's acceptance criteria list only "Add/edit/remove," but remove-then-re-add achieves the same end state for this slice's scope; a dedicated edit flow is straightforward additive work once needed) — flagged here rather than silently omitted.
- Tests: theme switch persists and applies (Task 4), source list renders from provider state (Task 6), remove-source confirmation flow (Task 6, explicit confirmation-dialog test).

**Known deferred item, disclosed not hidden:** "Edit" a source isn't built — remove-and-re-add covers the acceptance criterion's practical intent for this slice given M3U is the only add-able kind; note this for whoever picks up Xtream/Stalker/Jellyfin add-forms next, since edit becomes more valuable once credentials are involved (re-entering a working password to "remove and re-add" is worse UX than a real edit).

**Placeholder scan:** no TBD/TODO left uncovered by an explicit, justified plan note. The Accessibility section is an intentional, disclosed "coming soon" tile (not a placeholder pretending to be a real feature) — consistent with this codebase's own established convention and the issue's own scope note that CV-008 accessibility work is a separate, unbuilt issue.

**Type consistency:** `ContentSourceConfig`/`ContentSourceStore` (Task 1) match their usage in Task 2's providers exactly. `configuredContentSourcesProvider`/`addM3uContentSourceProvider`/`removeContentSourceProvider` (Task 2) are consumed identically in Task 6.

**Sequencing dependency, flagged explicitly:** this plan builds on branch `cv015-slice2-epg-grid` (PR #840, not yet merged) because `XmltvSourceSheet` lives there. If #840 merges into `v2` before this plan's worktree is created, rebase/branch from `v2` directly instead and this dependency note becomes moot; if #840 is still open, branch from `cv015-slice2-epg-grid` as this plan assumes.
