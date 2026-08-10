# IPTV unified playlist merge — design

## Problem

Airo supports multiple configured content sources (M3U, Xtream, Stalker,
Jellyfin) but Live TV does not present them as one list today:

- `_runtimeChannelsProvider` (`packages/feature_iptv/lib/application/providers/iptv_providers.dart:305`)
  branches on `activeContentSourceProvider`. If a single active source is
  set, only that source loads — every other configured source is ignored
  for Live TV. If no active source is set, only M3U + Xtream + personal
  channels merge; Stalker never joins unless it's the sole active source.
  Jellyfin is explicitly unsupported for Live TV regardless.
- The existing merge step, `_mergeChannelLibraries`
  (`iptv_providers.dart:580`), dedups only on exact `channel.id` or exact
  `streamUrl` match. The same channel offered by two different providers
  (different ids, different stream URLs) shows as two separate entries.

Industry precedent (TiviMate) confirms the requested shape: merge every
configured playlist into one list, with duplicate detection by stream URL
first and channel name as fallback. IPTV Smarters, by contrast, keeps
playlists separate — that is the model we are explicitly moving away from.

## Pro classification

This is a `pro` feature, currently free (launch-promo phase, not yet
charged for). `core_entitlements` (airo-pro repo) already declares
`ProFeature.importIntelligence`: "Import-time dedup, canonical channel
matching, dead-link pruning" — this exact capability area was reserved
ahead of time but never wired up. `LaunchPromoEntitlements.isEnabled`
returns `true` for every feature today, so gating behind
`ProFeature.importIntelligence` ships this to every user immediately
without a billing dependency, while giving product a lever to restrict it
later without touching call sites.

**Existing unused infra found in airo-pro** (`packages_pro/pro_import_intelligence`):
`ChannelMatcher` (hash → alias → fuzzy matching against a canonical
registry, `matchAndMerge()` producing `MergedChannel` cards with
`RankedSource`s), `ChannelRegistry`/`StreamIndex` (CDN-fed canonical
channel data + stream health verdicts), `ChannelNormalizer`
(`dedupKey()`/`sameChannel()`). `ImportIntelligenceModule` registers the
`ProFeature.importIntelligence` id but its `initialize()` is a no-op —
"skeleton... canonical catalog matching lands behind this module." Nothing
in `feature_iptv` calls into this package yet.

This design wires that existing package into the Live TV channel list
instead of writing new matching logic — see Component design below.

## Scope

- Live TV channel list always merges every configured M3U, Xtream, and
  Stalker source simultaneously. No "pick one active source" gate for
  Live TV. This part is plumbing, ships in the public repo, unconditional
  — it benefits even the free/baseline exact-match merge.
- Cross-provider identity matching (same channel, different provider,
  different id/URL) auto-merges via tvg-id or normalized-name equality.
  This part is gated behind `ProFeature.importIntelligence` — see Pro
  classification above.
- **CDN-backed matching (hash/alias/fuzzy against `ChannelRegistry`,
  source health ranking via `StreamIndex`) is explicitly deferred.** No
  `channels.json.gz` / `stream_index.json.gz` pipeline exists yet
  (`server/build.py` referenced in code comments isn't built). Shipping
  this now means running `ChannelMatcher` with an empty registry/index —
  see Component design for how that degrades safely — and tracking the
  CDN pack as a follow-up, not a blocker.
- Jellyfin remains excluded from Live TV — that's a separate capability
  gap (no Live TV adapter yet), not something this change addresses.
- On metadata conflict (logo/name/category) between merged channels, the
  channel matched at higher confidence wins; ties keep first-seen.
- Merge is invisible to the user: no source badges, no per-source
  labeling. A merged channel just has more stream sources to fall back
  across, exactly like today's multi-source fallback behavior.
- VOD is out of scope. `activeContentSourceProvider` keeps gating VOD's
  single-source browsing (`vod_providers.dart:21`) — untouched.
- No user-facing toggle for merge/dedup. Always on (subject to the
  entitlement check above, which is `true` for everyone today).

## Component design

This spans both repos.

### airo-pro: extend `ChannelMatcher` with a local pairwise stage

`ChannelMatcher.matchAndMerge` (`pro_import_intelligence/lib/src/channel_matcher.dart`)
today only matches a stream against the canonical `ChannelRegistry` (hash
→ alias → fuzzy). With an empty/unbuilt registry every stream falls
through to `MatchStage.unmatched` and gets a unique synthesized
`local:<hash>` id — meaning zero cross-provider merging happens until the
CDN pack ships, which contradicts "ship without it first."

Add a fourth stage that runs **after** the registry stages miss, matching
remaining streams **against each other** (not against a registry) using
data already available:

1. Group remaining unmatched streams by `tvgId` (new field on `RawStream`
   — not currently present, needs adding) where non-null → high
   confidence, `MatchStage.tvgId`.
2. Group what's left by `ChannelNormalizer.sameChannel()` (already
   implemented, currently unused by `matchAndMerge`) → medium confidence,
   `MatchStage.nameOnly`.
3. Whatever's still alone stays `unmatched`, one card per stream — same
   as today.

This reuses `ChannelNormalizer` as-is and needs one new field on
`RawStream` plus the new stage in `matchAndMerge`'s grouping loop. No CDN
dependency. Once the CDN pack ships later, stages 1–3 (hash/alias/fuzzy)
naturally take priority since they run first and produce higher
confidence/earlier matches — this new stage is strictly a fallback for
data the registry doesn't cover yet.

Metadata conflict resolution (logo/name/category) already exists in
`matchAndMerge` — the display logo picks the first source with a
non-empty logo across the merge group; extend the same
highest-confidence-wins rule to `name` (currently always takes
`best.canonicalName`, `best` being the top-ranked source — needs no
change, already correct for this design's "higher confidence wins" rule
since `results` sorts by source score, and stage/confidence should be
folded into that sort so a `tvgId`-stage match outranks a `nameOnly`-stage
match regardless of health score).

`ImportIntelligenceModule.initialize()` stays a no-op for now — no
registry/index to warm without the CDN pack.

### airo (public): extension seam + always-merge loading

New provider seam in `feature_iptv`, matching the existing
`playbackSettingsExtraSectionsProvider` pattern
(`application/providers/playback_settings_extension_point.dart`):

```dart
/// Merges multiple channel libraries into one Live TV list. Defaults to
/// exact id/URL dedup — the airo-pro overlay overrides this to add
/// cross-provider identity matching (see ProFeature.importIntelligence).
final channelLibraryMergerProvider =
    Provider<List<IPTVChannel> Function(Iterable<List<IPTVChannel>>)>(
  (ref) => _mergeChannelLibraries, // today's exact id/URL dedup, unchanged
);
```

`_mergeChannelLibraries` itself is unchanged — it stays the free/baseline
implementation and becomes this provider's default. Call sites (`iptv_providers.dart`)
switch from calling the private function directly to
`ref.read(channelLibraryMergerProvider)(...)`.

`_runtimeChannelsProvider` drops its `activeContentSourceProvider` branch
for Live TV — always loads M3U, Xtream, and Stalker sources in parallel
(plus personal channels and the legacy-parser fallback, as today), each
behind its own try/catch so one dead source doesn't blank the others,
then runs the result through `channelLibraryMergerProvider`.
`PlaylistSourcesUnavailableException` still fires only when every source
fails — same aggregate-failure semantics as today. This loading change is
unconditional (not entitlement-gated) — every user gets all-sources-merged
list; only the *matching quality* differs by entitlement.

`activeContentSourceProvider` is not deleted; it continues to gate VOD's
single-source browsing.

### airo-pro: wire the override

`airo_pro_bootstrap`'s `createProviderOverrides()` (already the place pro
UI gets injected, e.g. `tvSourceManagementSectionBuilderProvider`) adds:

```dart
channelLibraryMergerProvider.overrideWithValue(
  entitlements.isEnabled(ProFeature.importIntelligence)
      ? ProChannelMatcherAdapter(channelMatcher).mergeLibraries
      : _mergeChannelLibraries, // fall back to baseline if disentitled
),
```

`ProChannelMatcherAdapter` (new, small, in `pro_import_intelligence` or
`airo_pro_bootstrap`) adapts between `feature_iptv`'s `IPTVChannel` list
shape and `ChannelMatcher`'s `RawStream`/`MergedChannel` shape — converts
in, calls `matchAndMerge`, converts merged cards back into `IPTVChannel`s
with unioned `streamSources` (same union/sort logic as today's
`_mergeChannelLibraries`, reused rather than duplicated).

## Settings UI

`tv_source_management_section.dart:396-410` currently reads "Choose one
active source for Live TV." That copy is wrong once Live TV always
merges. Replace with copy describing merged behavior (e.g. "All
configured sources are merged into one Live TV list."); the active-source
picker in that screen is either relabeled as VOD-only or removed from the
Live TV context. Exact layout is an implementation-plan detail. This is a
public-repo change (the screen itself is public; only the pro-only
`ProSourceManagementSection` override lives in airo-pro).

## EPG

Unaffected. `CompactEpgRepository` already supports multiple named
sources with priority (`updateNamedSource`, already wired for Xtream).
Each merged channel still resolves EPG by its own `channel.id` — no new
EPG merge logic required by this change.

## Error handling

Unchanged pattern: per-source try/catch, coarse diagnostics only (no
URLs or credentials in logs — source URLs can carry private tokens),
aggregate failure surfaced only when every configured source is dead.

## Testing

- **airo-pro**: `ChannelMatcher` unit tests for the new pairwise fallback
  stage (tvgId group, nameOnly group via `sameChannel`, still-unmatched
  singletons), and for stage-priority-over-health-score in the
  confidence sort. `ImportIntelligenceModule` tests unchanged (still a
  no-op skeleton).
- **airo-pro**: a provider-override contract test (matching the existing
  `provider_override_contract_test.dart` pattern) proving
  `channelLibraryMergerProvider` resolves to the pro adapter when
  entitled and falls back to baseline when not.
- **airo (public)**: `channelLibraryMergerProvider`'s default unit-tested
  against today's `_mergeChannelLibraries` test cases (exact id, exact
  URL) — behavior must be identical to today when no pro override is
  linked.
- **airo (public)**: `iptv_providers` tests updated to assert
  always-merge-all-sources instead of active-source gating for Live TV.

## Delivery

Two-repo change, sequenced:
1. **airo (public)**: add `channelLibraryMergerProvider` seam, switch
   `_runtimeChannelsProvider` to always-merge-all-sources, update
   settings copy. Ships independently — behavior is identical to today
   except all sources now load together (still exact-match-only dedup).
2. **airo-pro (private)**: add `RawStream.tvgId`, the pairwise fallback
   stage in `ChannelMatcher`, `ProChannelMatcherAdapter`, and the
   `channelLibraryMergerProvider` override in `airo_pro_bootstrap`. Ships
   once (1) lands upstream in the overlay's sync.

## Out of scope / follow-ups

- CDN canonical channel registry + stream health data pack
  (`channels.json.gz`, `stream_index.json.gz`, `server/build.py`) — the
  hash/alias/fuzzy stages and health-ranked failover they unlock are
  deferred, tracked separately.
- Jellyfin Live TV support (separate capability gap).
- A "possible duplicate" review UI for medium-confidence matches (not
  requested — auto-merge was the explicit choice).
- A user-facing merge/dedup toggle (not requested — always-on was the
  explicit choice).
