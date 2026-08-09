# IPTV Unified Playlist Merge (public airo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live TV always merges every configured M3U, Xtream, and Stalker
source into one channel list, with a public extension seam the airo-pro
overlay can override for smarter cross-provider matching.

**Architecture:** Add a `channelLibraryMergerProvider` extension point
(same pattern as `playbackSettingsExtraSectionsProvider`) defaulting to
today's exact-id/exact-URL merge. Rewrite `_runtimeChannelsProvider` to
drop its single-active-source branch and always load+merge every
configured source. Add a `configuredStalkerChannelsProvider` (mirrors
`configuredM3uChannelsProvider`/`configuredXtreamChannelsProvider`) so
Stalker joins the same always-on aggregation. Update settings copy that
currently claims only one source can be active.

**Tech Stack:** Flutter, Riverpod (`FutureProvider`, `Provider`), Dart
`package:flutter_test` / `package:test`.

## Global Constraints

- Repo: `/Users/udaychauhan/workspace/airo-worktrees/iptv-unified-merge`
  (branch `feat/iptv-unified-playlist-merge`, worktree of the public
  `airo` repo).
- Spec: `docs/superpowers/specs/2026-08-10-iptv-unified-playlist-merge-design.md`.
- VOD is untouched — `activeContentSourceProvider` keeps gating
  `vod_providers.dart`. Do not remove or rename it.
- Jellyfin stays excluded from Live TV (no loader exists for it; nothing
  in this plan adds one).
- No new user-facing toggle. Merge is unconditional at the plumbing
  level; only the *matching quality* is pro-gated (handled entirely in
  the airo-pro repo, out of scope here).
- Source URLs/credentials must never appear in logs — match the existing
  `debugPrint('[Provider] ... could not be refreshed.')` style (id only,
  no URL) used throughout `iptv_providers.dart`.
- Run `cd app && flutter build web --release` is NOT required for this
  change (no native/web-specific path touched), but package-level tests
  must pass: `cd packages/feature_iptv && flutter test`.

---

## File Structure

- Create: `packages/feature_iptv/lib/application/providers/channel_library_merger_extension_point.dart`
  — the merge function (moved from `iptv_providers.dart`) + the
  extension-point provider.
- Modify: `packages/feature_iptv/lib/application/providers/iptv_providers.dart`
  — delete the old private merge function, add
  `configuredStalkerChannelsProvider`, rewrite `_runtimeChannelsProvider`.
- Modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_source_management_section.dart`
  — copy update.
- Modify: `packages/feature_iptv/test/iptv/application/providers/iptv_providers_test.dart`
  — replace the single-active-source test with an always-merges test,
  add Stalker-failure-isolation coverage.
- Create: `packages/feature_iptv/test/iptv/application/providers/channel_library_merger_extension_point_test.dart`
  — default-provider behavior test.

---

### Task 1: Extract `mergeChannelLibraries` into a public extension point

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/channel_library_merger_extension_point.dart`
- Modify: `packages/feature_iptv/lib/application/providers/iptv_providers.dart:580-632` (delete `_mergeChannelLibraries`, its 3 call sites become Task 2's concern except the one inside `_loadConfiguredM3uChannels`, which switches to calling the new public function directly)
- Test: `packages/feature_iptv/test/iptv/application/providers/channel_library_merger_extension_point_test.dart`

**Interfaces:**
- Produces: `mergeChannelLibraries(Iterable<List<IPTVChannel>> libraries) -> List<IPTVChannel>` (top-level function, public, same behavior as today's `_mergeChannelLibraries`). `channelLibraryMergerProvider` — `Provider<List<IPTVChannel> Function(Iterable<List<IPTVChannel>>)>`, default value is `mergeChannelLibraries`.
- Consumes: `IPTVChannel`, `ChannelStreamSource`, `compareChannelStreamSources` from `package:platform_channels/platform_channels.dart` (already imported in `iptv_providers.dart` today).

- [ ] **Step 1: Write the failing test**

```dart
// packages/feature_iptv/test/iptv/application/providers/channel_library_merger_extension_point_test.dart
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  test(
    'channelLibraryMergerProvider defaults to exact id/URL merge',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final merger = container.read(channelLibraryMergerProvider);
      final merged = merger([
        const [
          IPTVChannel(
            id: 'shared',
            name: 'Shared News',
            streamUrl: 'https://cdn.example.com/shared-hd.m3u8',
          ),
        ],
        const [
          IPTVChannel(
            id: 'shared',
            name: 'Shared News',
            streamUrl: 'https://cdn.example.com/shared-sd.m3u8',
          ),
        ],
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.streamSources, hasLength(2));
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/channel_library_merger_extension_point_test.dart`
Expected: FAIL — `channelLibraryMergerProvider` not defined (or `feature_iptv.dart` doesn't export it yet).

- [ ] **Step 3: Create the extension-point file**

Move the existing `_mergeChannelLibraries` function body verbatim from
`iptv_providers.dart:580-632`, rename it to public `mergeChannelLibraries`,
and add the provider:

```dart
// packages/feature_iptv/lib/application/providers/channel_library_merger_extension_point.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

/// Merges multiple channel libraries (one list per configured source) into
/// one Live TV list. Defaults to exact `id`/`streamUrl` dedup — the
/// airo-pro overlay overrides this provider (via `ProviderScope.overrides`
/// at bootstrap) to add cross-provider identity matching gated behind
/// `ProFeature.importIntelligence`, without editing this file directly, so
/// upstream syncs never conflict here.
final channelLibraryMergerProvider =
    Provider<List<IPTVChannel> Function(Iterable<List<IPTVChannel>>)>(
      (ref) => mergeChannelLibraries,
    );

/// Exact `id`/`streamUrl` merge: channels sharing either key are folded
/// into one entry with the union of their stream sources, languages,
/// alt names, and categories.
List<IPTVChannel> mergeChannelLibraries(
  Iterable<List<IPTVChannel>> libraries,
) {
  final channelsById = <String, IPTVChannel>{};
  final channelIdByStreamUrl = <String, String>{};

  for (final library in libraries) {
    for (final channel in library) {
      final existingId = channelsById.containsKey(channel.id)
          ? channel.id
          : channelIdByStreamUrl[channel.streamUrl];
      if (existingId == null) {
        channelsById[channel.id] = channel;
        channelIdByStreamUrl[channel.streamUrl] = channel.id;
        continue;
      }

      final existing = channelsById[existingId]!;
      final streamSources = <String, ChannelStreamSource>{
        for (final source in existing.streamSources) source.url: source,
        for (final source in channel.streamSources) source.url: source,
      };
      for (final url in [
        existing.streamUrl,
        ...existing.sources,
        channel.streamUrl,
        ...channel.sources,
      ]) {
        streamSources.putIfAbsent(url, () => ChannelStreamSource(url: url));
        channelIdByStreamUrl[url] = existingId;
      }
      final orderedSources = streamSources.values.toList()
        ..sort(compareChannelStreamSources);

      channelsById[existingId] = existing.copyWith(
        sources: orderedSources.map((source) => source.url).toList(),
        streamSources: orderedSources,
        qualityUrls: {
          ...?existing.qualityUrls,
          ...?channel.qualityUrls,
          for (var index = 1; index < orderedSources.length; index++)
            'source-$index': orderedSources[index].url,
        },
        languages: {...existing.languages, ...channel.languages}.toList(),
        altNames: {...existing.altNames, ...channel.altNames}.toList(),
        categories: {...existing.categories, ...channel.categories}.toList(),
        isWorking: existing.isWorking || channel.isWorking,
      );
    }
  }

  return List.unmodifiable(channelsById.values);
}
```

Delete lines 580-632 (`_mergeChannelLibraries`) from `iptv_providers.dart`.
At the one remaining call site inside `_loadConfiguredM3uChannels`
(originally line 463: `return _mergeChannelLibraries([channels]);`),
replace with `return mergeChannelLibraries([channels]);` — this call
folds duplicate entries within a single M3U file and intentionally stays
on the baseline function, not the entitlement-aware provider (it has no
`ref` and isn't part of the cross-source unified-view surface). Add
`import 'channel_library_merger_extension_point.dart';` to
`iptv_providers.dart`'s import block.

Add `export 'application/providers/channel_library_merger_extension_point.dart';`
to `packages/feature_iptv/lib/feature_iptv.dart` (check the existing
barrel file for where sibling provider exports live, e.g. how
`playback_settings_extension_point.dart` or `iptv_providers.dart` itself
is exported, and match that pattern).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/channel_library_merger_extension_point_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full feature_iptv suite to catch any broken import**

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS (no regressions from the move — `iptvChannelsProvider` and
`_loadConfiguredM3uChannels`-related tests still reference behavior, not
the deleted private symbol).

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/channel_library_merger_extension_point.dart \
        packages/feature_iptv/lib/application/providers/iptv_providers.dart \
        packages/feature_iptv/lib/feature_iptv.dart \
        packages/feature_iptv/test/iptv/application/providers/channel_library_merger_extension_point_test.dart
git commit -m "feat(iptv): extract channel merge into a public extension point"
```

---

### Task 2: Add `configuredStalkerChannelsProvider`

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/iptv_providers.dart`
  (add new provider near `configuredXtreamChannelsProvider`, ~line 497)
- Test: `packages/feature_iptv/test/iptv/application/providers/iptv_providers_test.dart`

**Interfaces:**
- Consumes: `configuredContentSourcesProvider` (existing,
  `FutureProvider<List<ContentSourceConfig>>`), `stalkerSourceLoaderProvider`
  (existing, `Provider<StalkerSourceLoader>` where `StalkerSourceLoader`
  is `Future<List<IPTVChannel>> Function(ContentSourceConfig)`).
- Produces: `configuredStalkerChannelsProvider` —
  `FutureProvider<List<IPTVChannel>>`. Loads every configured Stalker
  source, isolating per-source failures the same way
  `configuredXtreamChannelsProvider` does (log and skip, never throw for
  a single dead source).

- [ ] **Step 1: Write the failing test**

Add to the `'configured M3U sources'` group in
`iptv_providers_test.dart` (rename the group to
`'configured multi-source loading'` in this same step since it now
covers Stalker too — see Task 3 for the M3U-specific tests already
there, which stay unchanged):

```dart
    test(
      'configuredStalkerChannelsProvider loads every configured Stalker '
      'source and isolates a failing one',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = ContentSourceStore(PreferencesStore(prefs));
        await store.replaceAll(const [
          ContentSourceConfig(
            id: 'stalker-home',
            kind: ContentSourceKind.stalker,
            label: 'Home Portal',
            url: 'https://portal.example.com',
            macAddress: 'AA:BB:CC:DD:EE:FF',
          ),
          ContentSourceConfig(
            id: 'stalker-dead',
            kind: ContentSourceKind.stalker,
            label: 'Dead Portal',
            url: 'https://dead.example.com',
            macAddress: '11:22:33:44:55:66',
          ),
        ]);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            stalkerSourceLoaderProvider.overrideWithValue((config) async {
              if (config.id == 'stalker-dead') {
                throw StateError('portal unreachable');
              }
              return const [
                IPTVChannel(
                  id: 'stalker-home-7',
                  name: 'Portal Only',
                  streamUrl: 'https://example.com/portal.m3u8',
                ),
              ];
            }),
          ],
        );
        addTearDown(container.dispose);

        final channels = await container.read(
          configuredStalkerChannelsProvider.future,
        );

        expect(channels.map((c) => c.id), ['stalker-home-7']);
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/iptv_providers_test.dart --plain-name "configuredStalkerChannelsProvider"`
Expected: FAIL — `configuredStalkerChannelsProvider` not defined.

- [ ] **Step 3: Implement the provider**

Add directly after `configuredXtreamChannelsProvider`'s definition in
`iptv_providers.dart`:

```dart
/// Loads every configured Stalker source, mirroring
/// [configuredM3uChannelsProvider] and [configuredXtreamChannelsProvider]:
/// one dead portal must not blank the others.
final configuredStalkerChannelsProvider = FutureProvider<List<IPTVChannel>>((
  ref,
) async {
  final configs = await ref.watch(configuredContentSourcesProvider.future);
  final stalkerConfigs = configs
      .where((source) => source.kind == ContentSourceKind.stalker)
      .toList(growable: false);
  if (stalkerConfigs.isEmpty) return const [];

  final loader = ref.read(stalkerSourceLoaderProvider);
  final channels = <IPTVChannel>[];
  for (final config in stalkerConfigs) {
    try {
      channels.addAll(await loader(config));
    } catch (_) {
      // Stalker portal URLs and MAC addresses are not secrets by
      // themselves, but keep diagnostics coarse for consistency with
      // the M3U/Xtream loaders above.
      debugPrint(
        '[Provider] Stalker source ${config.id} could not be refreshed.',
      );
    }
  }
  return channels;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/iptv_providers_test.dart --plain-name "configuredStalkerChannelsProvider"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/iptv_providers.dart \
        packages/feature_iptv/test/iptv/application/providers/iptv_providers_test.dart
git commit -m "feat(iptv): load every configured Stalker source, not just the active one"
```

---

### Task 3: Always merge every configured source in `_runtimeChannelsProvider`

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/iptv_providers.dart:305-395`
- Test: `packages/feature_iptv/test/iptv/application/providers/iptv_providers_test.dart:501-568`
  (replace `'active source selection is exclusive across Stalker and M3U'`)

**Interfaces:**
- Consumes: `channelLibraryMergerProvider` (Task 1),
  `configuredStalkerChannelsProvider` (Task 2), `configuredM3uChannelsProvider`,
  `configuredXtreamChannelsProvider`, `channelDataServiceProvider`,
  `m3uParserProvider` (all existing).
- Produces: `_runtimeChannelsProvider` keeps its existing signature
  (`FutureProvider.family<List<IPTVChannel>, bool>`) and existing
  `retry: surfaceChannelFailureInsteadOfRetrying` — only the body changes.

- [ ] **Step 1: Write the failing test**

Replace the test at `iptv_providers_test.dart:501-568`
(`'active source selection is exclusive across Stalker and M3U'`) with:

```dart
    test(
      'merges Stalker and M3U simultaneously regardless of any selected '
      'active source',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = ContentSourceStore(PreferencesStore(prefs));
        await store.replaceAll(const [
          ContentSourceConfig(
            id: 'm3u-news',
            kind: ContentSourceKind.m3u,
            label: 'M3U News',
            url: 'https://example.com/news.m3u',
          ),
          ContentSourceConfig(
            id: 'stalker-home',
            kind: ContentSourceKind.stalker,
            label: 'Home Portal',
            url: 'https://portal.example.com',
            macAddress: 'AA:BB:CC:DD:EE:FF',
          ),
        ]);
        await store.setActiveSourceId('stalker-home');
        final m3uParser = _FakeSourceParser(
          prefs: prefs,
          sourceId: 'm3u-news',
          channels: const [
            IPTVChannel(
              id: 'm3u-only',
              name: 'M3U Only',
              streamUrl: 'https://example.com/m3u.m3u8',
            ),
          ],
        );
        final sourceContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            m3uSourceParserFactoryProvider.overrideWithValue((_) => m3uParser),
            stalkerSourceLoaderProvider.overrideWithValue(
              (_) async => const [
                IPTVChannel(
                  id: 'stalker-home-7',
                  name: 'Portal Only',
                  streamUrl: 'https://example.com/portal.m3u8',
                ),
              ],
            ),
          ],
        );
        addTearDown(sourceContainer.dispose);

        // An active source is set (legacy VOD selection state) but Live TV
        // must ignore it and show both sources merged.
        expect(
          (await sourceContainer.read(
            iptvChannelsProvider.future,
          )).map((channel) => channel.id),
          containsAll(['stalker-home-7', 'm3u-only']),
        );
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/iptv_providers_test.dart --plain-name "merges Stalker and M3U simultaneously"`
Expected: FAIL — only `stalker-home-7` present (today's active-source
gating still applies).

- [ ] **Step 3: Rewrite `_runtimeChannelsProvider`**

Replace `iptv_providers.dart:305-395` (the entire family provider body)
with:

```dart
final _runtimeChannelsProvider = FutureProvider.family<List<IPTVChannel>, bool>(
  (ref, forceRefresh) async {
    // Live TV never gates on a single "active" source — every configured
    // library contributes, and the public catalog / legacy parser fills
    // in behind them. See
    // docs/superpowers/specs/2026-08-10-iptv-unified-playlist-merge-design.md.
    List<IPTVChannel> primaryChannels = const [];
    final channelDataService = ref.watch(channelDataServiceProvider);
    try {
      final channels = await channelDataService.fetchChannels(
        forceRefresh: forceRefresh,
      );
      if (channels.isNotEmpty) {
        primaryChannels = channels;
      }
    } catch (e) {
      debugPrint(
        '[Provider] ChannelDataService failed, falling back to M3U: $e',
      );
    }

    // A total configured-source failure must not hide channels another library
    // still has, so hold the error and only report it if nothing else loaded.
    var configuredM3uChannels = const <IPTVChannel>[];
    Object? configuredM3uFailure;
    StackTrace? configuredM3uTrace;
    try {
      configuredM3uChannels = await ref.watch(
        configuredM3uChannelsProvider.future,
      );
    } catch (error, stackTrace) {
      configuredM3uFailure = error;
      configuredM3uTrace = stackTrace;
    }

    if (primaryChannels.isEmpty && configuredM3uChannels.isEmpty) {
      // Fallback to legacy M3U parser.
      primaryChannels = await ref
          .watch(m3uParserProvider)
          .fetchPlaylist(forceRefresh: forceRefresh);
    }

    final byocChannels = await ref.watch(
      configuredXtreamChannelsProvider.future,
    );
    final stalkerChannels = await ref.watch(
      configuredStalkerChannelsProvider.future,
    );
    final merge = ref.watch(channelLibraryMergerProvider);
    final merged = merge([
      primaryChannels,
      configuredM3uChannels,
      byocChannels,
      stalkerChannels,
    ]);
    if (merged.isEmpty && configuredM3uFailure != null) {
      Error.throwWithStackTrace(configuredM3uFailure, configuredM3uTrace!);
    }
    return merged;
  },
  retry: surfaceChannelFailureInsteadOfRetrying,
);
```

This deletes the `activeContentSourceProvider` branch and its
`ContentSourceKind` switch entirely — Jellyfin's "not available in Live
TV yet" throw goes with it (Jellyfin still isn't loaded anywhere for
Live TV, so behavior for Jellyfin-only setups is unchanged: empty list,
not an error).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/iptv_providers_test.dart --plain-name "merges Stalker and M3U simultaneously"`
Expected: PASS

- [ ] **Step 5: Run the full iptv_providers test file**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/iptv_providers_test.dart`
Expected: PASS — including the existing `'loads multiple M3U sources,
merges duplicate channels, and isolates failure'` test (Task 3 doesn't
touch `configuredM3uChannelsProvider`'s internals) and the legacy Pixel
playlist migration test.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/iptv_providers.dart \
        packages/feature_iptv/test/iptv/application/providers/iptv_providers_test.dart
git commit -m "feat(iptv): merge every configured Live TV source instead of gating on one active source"
```

---

### Task 4: Update Live TV source-management copy

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_source_management_section.dart:406-410`
- Test: existing widget/golden tests for this screen, if any (check
  `packages/feature_iptv/test/presentation/tv_ux/` and
  `packages/feature_iptv/test/presentation/widgets/` for a matching
  `tv_source_management_section_test.dart`; if none exists, this task
  has no automated test and Step 1 is skipped in favor of a manual
  verification note in Step 3)

**Interfaces:**
- No new interfaces — text-only change.

- [ ] **Step 1: Check for an existing text-assertion test**

Run: `grep -rl "Choose one active source" packages/feature_iptv/test`

If a match is found, note its file path — Step 2 updates that assertion
alongside the copy change. If no match, proceed directly to Step 2.

- [ ] **Step 2: Update the copy**

In `tv_source_management_section.dart`, replace:

```dart
          Text(
            'Choose one active source for Live TV. M3U supports external '
            'XMLTV; Xtream supports Live TV, EPG, and VOD; Stalker supports '
            'Live TV. Raw .m3u8 links remain playback URLs, not channel lists.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
```

with:

```dart
          Text(
            'Every M3U, Xtream, and Stalker source you add merges into one '
            'Live TV list. Xtream also supports EPG and VOD. Raw .m3u8 '
            'links remain playback URLs, not channel lists.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
```

If Step 1 found a test asserting the old string, update it to the new
string in the same commit.

- [ ] **Step 3: Manual verification**

Run the app (`.claude/skills/run-airo-tv/SKILL.md` covers launching Airo
TV) with 2+ configured sources and open Settings → Content Sources.
Confirm the new copy renders and no leftover "active source" picker
implies single-selection for Live TV. This screen still has an
active-source picker for VOD purposes (untouched by this plan) — verify
its label doesn't now read as contradicting the new Live TV copy; if it
does, that's copy-only follow-up, not a blocker for this task.

- [ ] **Step 4: Run the package test suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/settings/tv_source_management_section.dart
git commit -m "docs(iptv): update Live TV source copy for always-merged behavior"
```

---

## Self-Review Notes

- **Spec coverage:** "always merges M3U/Xtream/Stalker" → Tasks 2+3.
  "public extension seam, baseline free behavior unchanged" → Task 1.
  "settings UI copy" → Task 4. Jellyfin-excluded / VOD-untouched
  constraints are called out explicitly in Global Constraints and Task 3
  Step 3. Cross-provider tvg-id/name matching, entitlement gating, and
  the `ProChannelMatcherAdapter` are airo-pro repo work — out of scope
  for this plan by design (see the companion plan in the airo-pro repo).
- **Placeholder scan:** none — every step has literal code or an exact
  grep/run command.
- **Type consistency:** `channelLibraryMergerProvider`'s type
  (`Provider<List<IPTVChannel> Function(Iterable<List<IPTVChannel>>)>`)
  is identical across Task 1 (definition) and Task 3 (consumption via
  `ref.watch`). `mergeChannelLibraries`'s signature matches its one
  remaining direct call site in `_loadConfiguredM3uChannels`.
