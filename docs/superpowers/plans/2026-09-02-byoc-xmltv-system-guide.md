# BYOC XMLTV and first-party system guide — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire EPG↔playlist mapping so a Guide click plays the matching IPTV stream; expose Match EPG for BYOC numeric ids; preprocess global epg.pw XMLTV in CI (remap to iptv-org ids) and publish country shards to R2 for optional system fetch.

**Architecture:** Device never talks to epg.pw. Dart `XmltvSourceRefreshService` downloads user XMLTV or our checksummed `guide_XX.xml.gz`. Rust `quick-xml` parses. `queryGuideWindowWithOverrides` keys programmes by playlist `IPTVChannel.id` so `EpgTimelineGrid` / `EpgTouchTimelineGrid` `playChannel(channel)` is click-through. CI remaps epg.pw numeric ids → `MTV.in` before R2.

**Tech Stack:** Flutter/Riverpod (`feature_iptv`), existing `XmltvCompactEpgRepository.fromXmltvFileNative`, Python `iptv-data`, GitHub Actions, Cloudflare R2 (upload gated on secrets).

**Spec:** `docs/superpowers/specs/2026-09-02-byoc-xmltv-system-guide-design.md` (approved).

---

## Global constraints

- Play BYOC: no iptv-org M3U presets, no `streams.json`, no Jio/Tata catch-up, no Widevine demos from mitthu786/tvepg.
- No `reqwest` in `airo_core`. No device download of `epg.xml.gz` (~50 MB) or `guide_ALL.xml.gz` on TV/iOS boot.
- Do not enable `IPTV_DATA_MANIFEST_URL` dart-defines until R2 has `guide_IN.xml.gz` + checksum.
- If `CLOUDFLARE_R2_*` secrets are missing, the workflow still produces artifacts; skip R2 put with a log line, do not fail the job.
- Prove contracts with the narrowest local tests (`flutter test` in `feature_iptv`, `pytest` in `iptv-data`). No full CI matrix unless asked.
- Branch from `origin/main`: `agent/iptv/byoc-xmltv-system-guide`. Conventional commits, e.g. `feat(iptv): expose match EPG from guide`.
- Click-through: never construct a synthetic `IPTVChannel` from an XMLTV id. Play the playlist row object.

---

## File map

```
docs/superpowers/specs/2026-09-02-byoc-xmltv-system-guide-design.md   [done]
packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart
packages/feature_iptv/lib/presentation/widgets/epg_match_override_sheet.dart
packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart
packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart
packages/feature_iptv/lib/presentation/widgets/epg_touch_timeline_grid.dart
packages/feature_iptv/lib/application/guide_window_query.dart          [verify + tests]
packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart
packages/feature_iptv/lib/application/airo_tv_bootstrap_io.dart
app/lib/main_tv.dart
iptv-data/src/epg_pw_remap.py                                         [new]
iptv-data/tests/test_epg_pw_remap.py                                  [new]
iptv-data/src/epg_artifacts.py                                        [reuse publish_country_guides if ids already remapped]
.github/workflows/iptv_sanity.yml
docs/legal/privacy-policy/index.html                                  [only if dart-defines will ship]
```

---

### Task 1: Guide URL copy — XMLTV not HTML

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`

- [ ] Add helper text under the URL field: `Paste an XMLTV URL or .xml.gz. HTML schedule pages will fail.`
- [ ] Set hint to `https://example.com/guide.xml.gz`
- [ ] Widget test: `find.textContaining('XMLTV URL or .xml.gz')`
- [ ] Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`
- [ ] Commit: `fix(iptv): tell users to paste XMLTV not HTML EPG pages`

---

### Task 2: Click-through mapping tests (EPG id → playlist channel → play)

**Files:**
- Test: `packages/feature_iptv/test/iptv/application/guide_window_query_test.dart`
- Modify only if tests fail: `packages/feature_iptv/lib/application/guide_window_query.dart`

Existing query remaps `entry.channelId` through `epgIdToChannelId` then `putIfAbsent` onto playlist `channel.id`. Lock that as the click-through contract.

- [ ] Add a test: playlist channel `id: 'mtv-hash'`, `xmltvId: 'MTV.in@SD'`, override `'mtv-hash' → '543480'`. Repository `loadWindow` is asked for `543480` and `MTV.in@SD` / `MTV.in`. Returned entry `channelId: '543480'` with one programme titled `Hustle`. Result `entryForChannel('mtv-hash')` has that programme; `entryForChannel('543480')` is null.

```dart
test('override remaps numeric EPG id onto playlist channel id for click-through', () async {
  // IPTVChannel id is the Live/player key; EPG id 543480 must not leak into the window.
});
```

- [ ] Add a test: two playlist channels with `epgLookupIds` both containing `MTV.in`; first in list wins `putIfAbsent`; both still exist as separate `IPTVChannel`s for label taps.
- [ ] After Match EPG save, `guidePagedWindowProvider` must be invalidated (today `EpgMatchOverrideSheet` only invalidates `guideEpgOverridesProvider`). Extend sheet `_save` / `_clear` to also `ref.invalidate(guidePagedWindowProvider)`.
- [ ] Test in `epg_match_override_sheet_test.dart` is enough if you assert save still works; add a notifier test only if invalidate is easy to observe.
- [ ] Run: `cd packages/feature_iptv && flutter test test/iptv/application/guide_window_query_test.dart test/iptv/presentation/widgets/epg_match_override_sheet_test.dart`
- [ ] Commit: `fix(iptv): remap EPG ids onto playlist channels for guide click-through`

---

### Task 3: Match EPG from Guide (long-press channel label)

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/epg_match_override_sheet.dart` — add `showEpgMatchOverrideSheet(BuildContext, IPTVChannel)` using `showAdaptiveIptvSheet` like `showXmltvSourceSheet`.
- Modify: `epg_timeline_grid.dart` / `epg_touch_timeline_grid.dart` — `onMatchEpg` callback; channel-label `onLongPress` (TV: also a secondary `TvFocusable` or long-press on the 220px label). Semantic label: `Match EPG for ${channel.name}`.
- Modify: `iptv_guide_screen.dart` — `onMatchEpg: (channel) => showEpgMatchOverrideSheet(context, channel)`.
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart` — pump TV grid, long-press `City News Live` label, expect `Match "City News Live" to EPG channel`.
- Phone: long-press on touch grid label; extend or add a compact-form-factor test if one exists.

Click-through regression: TV `onProgramSelect` / Watch Now must still call `selectChannel(channel)` with the **row** `IPTVChannel` (already in `iptv_guide_screen.dart` ~90–97). Do not pass EPG id. Add a test that a fake `VideoPlayerStreamingService` / callback records `channel.id == 'news-1'` when Watch Now is tapped (follow existing `iptv_guide_screen_test` pump helpers).

- [ ] Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_guide_screen_test.dart test/iptv/presentation/widgets/epg_match_override_sheet_test.dart`
- [ ] Commit: `feat(iptv): open Match EPG from guide channel long-press`

---

### Task 4: epg.pw → iptv-org id remap (Python)

**Files:**
- Create: `iptv-data/src/epg_pw_remap.py`
- Create: `iptv-data/tests/test_epg_pw_remap.py`

Behaviour:

- Input: XMLTV whose `<channel id>` is numeric (e.g. `543480`) and `<display-name>` is `MTV` / `MTV India`.
- Catalog: `iptv_channels.json`-shaped `{ "channels": [ { "id": "MTV.in", "name": "MTV", "country": "IN" }, ... ] }`.
- Optional checked-in aliases file later; v1: normalize names (casefold, strip ` HD`, punctuation) and map display-name → catalog `id`. Exact `id` already in XML is kept.
- Output: rewrite `channel id` and `programme channel=` to catalog id. Drop channels/programmes with no match. Split by catalog `country` into in-memory trees.
- Also write `guide_ALL` as the union.
- Do not emit numeric ids in output.

```python
def normalize_name(name: str) -> str: ...

def remap_epg_pw_xmltv(
    xml_bytes: bytes,
    channels_payload: dict,
) -> dict[str, bytes]:
    """Return country -> xmltv bytes, plus key ALL."""
```

- [ ] Tests with a tiny XML (`543480` / MTV / one `Hustle` programme) and catalog `MTV.in` → output IN xml has `channel id="MTV.in"` and programme `channel="MTV.in"`; `543480` absent.
- [ ] Unmatched channel dropped.
- [ ] Collision: two catalog rows same normalized name — stable pick: prefer id whose suffix matches display lang/country if present, else lexicographically smaller id. Document in docstring.
- [ ] Run: `cd iptv-data && pytest tests/test_epg_pw_remap.py -v`
- [ ] Commit: `feat(iptv-data): remap epg.pw numeric ids to iptv-org xmltv ids`

---

### Task 5: Publish remapped shards + optional R2

**Files:**
- Modify: `iptv-data/src/epg_artifacts.py` — accept already-remapped per-country XML (or gzip from remap output) and write `guide_XX.xml.gz` + SHA-256 into `manifest.json` (`files.guide_IN`, `fileChecksums.guide_IN`, same for ALL as `guide_ALL`). Reuse existing gzip mtime=0 + atomic replace.
- Modify: `.github/workflows/iptv_sanity.yml`

Workflow (after existing tests; **in addition to** or **as alternative ingest** to the iptv-org grab):

1. `curl --http1.1 --fail --retry 3` `https://epg.pw/xmltv/epg.xml.gz` to `/tmp/epg.pw.xml.gz` (global). If that fails, fall back to concatenating country packs listed on https://epg.pw/xmltv.html (`epg_IN.xml.gz`, `epg_US.xml.gz`, …) — still CI-only.
2. Gunzip, `python -m src.epg_pw_remap --input ... --channels output/current/iptv_channels.json --output-dir /tmp/remapped`
3. Publish gzips into `output/current/` and update manifest checksums.
4. Keep the iptv-org grab stage if remap coverage for IN is below the existing 70% gate — do not replace a good `guide_IN.xml.gz`. If both exist, prefer remap file when IN programme count ≥ grab count; else keep grab. Encode this in a small `src/epg_publish_prefer.py` or a few lines in the workflow.
5. `upload-artifact` already includes `output/current/`.
6. R2 (skip if secrets unset):

```bash
# secrets: CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_R2_ACCESS_KEY_ID, CLOUDFLARE_R2_SECRET_ACCESS_KEY, CLOUDFLARE_R2_BUCKET
# endpoint: https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com
aws s3 cp output/current/manifest.json s3://$BUCKET/iptv-data/manifest.json
aws s3 cp output/current/guide_IN.xml.gz s3://$BUCKET/iptv-data/guide_IN.xml.gz
# ... other guide_XX and guide_ALL
```

Use AWS CLI with `AWS_ACCESS_KEY_ID`/`SECRET`/`AWS_ENDPOINT_URL`. Do not commit credentials. Do **not** upload `iptv_channels.json` or M3U to the public guide prefix (stream catalogue).

7. Do not PATCH Gist with gzip binaries. Leave existing gist JSON as-is.

- [ ] Run remap unit tests + `pytest tests/test_epg_artifacts.py`
- [ ] Commit: `feat(iptv-data): publish remapped country guide shards for R2`

Human follow-up (not this agent): create R2 bucket, public domain or Worker, put `IPTV_DATA_MANIFEST_URL` on a later release.

---

### Task 6: App fetches `guide_XX` for playlist countries only

**Files:**
- Modify: `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart` — add `refreshSystemSourceFromManifest` overload or `refreshSystemGuidesForCountries({required String manifestUrl, required Set<String> countries})` that fetches each `guide_$CC` present in manifest (skip missing keys). Merge into `MutableXmltvCompactEpgRepository` as one system source or one named source per country with priority 1. Same-origin + SHA-256 per file. HTTPS only.
- Modify: `airo_tv_bootstrap_io.dart` / `refreshAiroTvBundledSystemGuide` — derive countries from loaded playlist channels (`IPTVChannel.country` / `_countryFromXmltvId` already on the model). If empty, fall back to `IPTV_DATA_COUNTRY` default `IN`.
- Tests in `xmltv_source_refresh_service_test.dart`: fake Dio adapter serves `manifest.json` + `guide_IN.xml.gz`; assert repository has programmes for remapped `MTV.in`; request log does **not** include `guide_ALL.xml.gz` or `epg.xml.gz`.
- Do not set dart-defines in `pubspec_tv.yaml` until R2 is live.

- [ ] Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`
- [ ] Commit: `feat(iptv): fetch system guide shards for playlist countries`

---

### Task 7: Privacy sentence (only if Task 6 dart-defines will ship in the same PR)

**Files:** `docs/legal/privacy-policy/index.html` (EPG bullet ~line 250), terms only if they still say EPG is user-configured only.

- [ ] Add: the app may download country programme-guide files from DevelopersCoffee when a system manifest is compiled in; overlay on the user’s channels; not uploaded. Do not name epg.pw.
- [ ] Commit: `docs(legal): disclose optional system programme guide fetch`

If dart-defines stay empty, skip this task.

---

## UAT (human / Pixel, not CI)

Entry: India M3U pasted (test fixture), search empty, country IN.

1. Guide URL `https://epg.pw/api/epg.xml?channel_id=543480` → `Guide refreshed.`
2. Long-press MTV → Match EPG `543480` → Save.
3. Guide row shows current `543480` title (Hustle / Splitsvilla per scrape).
4. Watch Now / program tap plays that MTV playlist stream (click-through).
5. HTML `last/543480.html` → refresh failed.

---

## Out of scope

- Fuzzy name matching in the app against a downloaded epg.pw index
- tvepg Jio `144` / Tata `ts840` ids
- Changing 30s timeout / 100k programme cap except if system multi-shard fetch needs a documented bump (prefer not)
