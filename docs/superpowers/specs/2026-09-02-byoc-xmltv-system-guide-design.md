# BYOC XMLTV and first-party system guide — Design

Status: Approved (2026-09-02)
Owner: Aika Stream / `feature_iptv` + `iptv-data` pipeline
Related: `docs/features/airo-tv/MULTI_SOURCE_EPG.md`, `docs/release/MIDAS_STREAM_PLAY_STORE_GATE.md`, `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart`

## Decision

Aika Stream remains a **bring-your-own-content player**. Programme guides follow the same split as playlists:

| Role | Source | Who fetches |
|---|---|---|
| **BYOC (higher priority)** | User-pasted XMLTV HTTPS URL | The device, via existing Guide URL sheet |
| **Product default (optional, lower priority)** | Our `guide_XX.xml.gz` from `iptv-data`, checksummed, same-origin as `IPTV_DATA_MANIFEST_URL` | The device, only when those dart-defines are set |
| **Grabber (not in the app)** | `iptv-org/epg` npm/Docker tools | CI / operator machine that publishes `iptv-data` artifacts, or a user who hosts their own `guide.xml` |

epg.pw, EPGShare01, a self-hosted iptv-org grab, and a provider XMLTV file are all **BYOC URLs**. They are not compiled into the APK and are not fetched by `airo_core`.

## Why not epg.pw inside Rust

epg.pw does publish real XMLTV files (`https://epg.pw/xmltv/epg_IN.xml.gz`, `https://epg.pw/api/epg.xml?channel_id=543480`). It does **not** publish a documented master `channels.json` with the schema invented in generic AI samples.

Putting `reqwest` in the mobile Rust core to sync a global channel index on startup would:

- duplicate Dart `Dio` download + existing `quick-xml` parse;
- download a third-party channel catalogue (Play posture we already rejected for `streams.json`);
- bind listings to numeric ids (`543480`) that do not match iptv-org `tvg-id` values (`MTV.in@SD`).

Rust stays the **parser**. HTTP, gzip, checksum, and source policy stay in `XmltvSourceRefreshService`.

## Architecture

```
User XMLTV URL  ──priority 0──► MutableXmltvCompactEpgRepository
Our manifest     ──priority 1──► same merge (system kind)
                                      │
                                      ▼
                         GuideWindowQuery + optional
                         EpgChannelMatchOverrideStore
                                      │
                                      ▼
                         CompactEpgWindow (playlist channel ids)
```

- Overlay **only** on channels already in the user’s playlist. A guide file must not add rows to Live.
- User source wins on overlap (`XmltvSourceKind.user` priority 0, `system` priority 1).
- System fetch requires HTTPS manifest, same-origin filename, SHA-256 match (already implemented).
- System fetch is skipped unless `IPTV_DATA_PLAYLIST_URL` and `IPTV_DATA_MANIFEST_URL` are non-empty. Preview Play builds that omit them stay paste-only.
- **CI ingests globally.** GitHub Actions downloads epg.pw `epg.xml.gz` (~50 MB compressed, 2026-09-02) and/or every published country pack, remaps ids, writes per-country `guide_XX.xml.gz` plus a `guide_ALL.xml.gz` into R2. The device does **not** hit epg.pw.
- **The app filters by which shards to download**, not by pulling the world file then throwing it away. After playlist load, collect ISO codes from `tvg-id` (`.in@SD` → `IN`). Fetch only those `guide_XX` files (plus checksums). `GuideWindowQuery` already keeps programmes for playlist channel ids only.
- Do not download `guide_ALL.xml.gz` on Android TV / iOS as the default. 50 MB gzip plus a 100k programme cap would truncate and blow the 30s receive timeout. `guide_ALL` is a CDN artifact for tooling and optional future Wi-Fi desktop, not the TV boot path.
- Refresh on explicit Save & Refresh, and on the existing post-`runApp` system schedule for the selected country shards. Not on iOS background tasks.

### Channel id matching

Query order per playlist channel (already in `queryGuideWindowWithOverrides`):

1. Manual override from `EpgChannelMatchOverrideStore` if set.
2. Playlist `tvg-id` string (`MTV.in@SD`).
3. Alias with `@quality` stripped (`MTV.in`).

**Gap:** `EpgMatchOverrideSheet` exists and is tested, but no product screen opens it. BYOC feeds that use numeric ids (epg.pw `543480`) cannot be attached to `MTV.in@SD` without that UI.

**Product default** artifacts must emit iptv-org-style `xmltv_id` values (`MTV.in`, `AajTak.in`, `BBCOne.uk`) so country M3Us match without a per-channel override. The pipeline remaps epg.pw numeric ids using display-name → iptv-org id. Unmatched rows are dropped from that country’s file, not published under `543480`.

### Click-through (EPG row → playlist stream)

The Guide grid is a list of **playlist** `IPTVChannel`s. Programmes are looked up with `entriesByChannel[channel.id]` (`EpgTimelineGrid`). TV `Watch Now` and phone row/program tap already call `playChannel(channel)` on that same object.

Mapping is what makes click-through work: after remap or override, `queryGuideWindowWithOverrides` must key the window entry with the playlist `IPTVChannel.id` (URL-hash id), never leave it as `543480` or `MTV.in`. Then a click plays `channel.streamUrl` and routes to Live/player via existing `onChannelSelected`.

Invariants:

- Do not build a synthetic channel from an XMLTV id. If there is no playlist row, there is no click target (overlay-only).
- One EPG id → first playlist channel that claimed it (`putIfAbsent` in `guide_window_query.dart`). Two rows (`MTV.in@SD` and `MTV.in@HD`) sharing `MTV.in` after alias strip: first in filtered order wins; both still play their own stream if the user taps **that** row’s label.
- After saving a Match EPG override, invalidate `guideEpgOverridesProvider` and `guidePagedWindowProvider` so the row fills before the next tap.
- Phone `EpgTouchTimelineGrid` must pass the row’s `IPTVChannel` into `onChannelSelect` for program taps (already does). TV `onProgramSelect(channel, program)` must keep that channel for Watch Now (already does). Tests must assert the played id is the playlist channel id, not the EPG id.

## mitthu786/tvepg (what to copy, what not to)

Scraped 2026-09-02. This is **not** a global epg.pw processor.

| They do | We do |
|---|---|
| GitHub Actions bot commits `epg.xml.gz` daily into the repo; GitHub Pages + `avkb.short.gy` CDN | Actions → Cloudflare R2; do not commit 50 MB binaries to git |
| India **OTT operator** guides: JioTV, TataPlay, Zee5, SunNxt, SonyLIV | epg.pw global XMLTV + iptv-org id remap |
| Ids `144`, `ts840`, `0-9-zeetv` — playlist must be rewritten | Keep playlist `MTV.in@SD`; remap on our side |
| ~2.1 MB AIO / ~2.3 MB Jio / ~1.2 MB Tata gzip | Per-country shards; IN pack from epg.pw is ~0.7 MB *before* remap |
| Catch-up + README demos with Widevine license URLs and `localhost/jiotv` | Out of scope. Play BYOC player; no operator DRM proxy |
| Educational disclaimer | Privacy names our origin only |

Copy the **ops shape** (scheduled gzip publish to HTTPS). Do not copy Jio/Tata id schemes, catch-up, or their playlist examples.

## Product surfaces

1. **Guide URL sheet** (existing): paste/remove/refresh any HTTP(S) XMLTV URL, including epg.pw. HTML schedule pages are invalid; the sheet already requires a downloadable XML/gzip body.
2. **Match EPG** (new entry point): from Guide, on a focused/selected channel, open `EpgMatchOverrideSheet`. Save stores `channel.id → epg id` (e.g. MTV stream → `543480`). Clear restores auto ids.
3. **No** in-app “Import iptv-org/epg” GitHub clone. Copy in the sheet: user supplies an XMLTV URL they are allowed to use.

## Privacy and Play

- Privacy already says EPG is downloaded from the XMLTV URL the user configures. Keep that for BYOC.
- If a release sets `IPTV_DATA_MANIFEST_URL`, add one sentence: the app may also fetch programme-guide shards from DevelopersCoffee (that origin) for countries present in the user’s playlist, overlay-only. Do not name epg.pw or tvepg as a product vendor.
- Store listing still must not claim bundled live TV, channels, or a public IPTV index. A programme-guide overlay on user channels is metadata, not a stream catalogue.
- iptv-org **playlists** remain out of production UI.

## UAT fixtures (not shipped)

These are tester-pasted URLs, same as today:

| Check | URL | Exit |
|---|---|---|
| BYOC fetch | `https://epg.pw/api/epg.xml?channel_id=543480` | Guide sheet: `Guide refreshed.` |
| BYOC listings on MTV | same URL + override MTV → `543480` | Guide row shows **Hustle** (or the current `543480` programme), not empty |
| Click-through | listings visible on MTV row | Watch Now / program tap plays playlist `MTV` (`streamUrl` of `MTV.in@SD` or `@HD` row), not a synthetic EPG channel |
| HTML rejected | `https://epg.pw/last/543480.html?...` | Refresh failed |
| System guide | only when `guide_IN.xml.gz` exists on our origin with `MTV.in` | MTV listings without a numeric override |

India playlist fixture for those checks: user-pasted `https://iptv-org.github.io/iptv/countries/in.m3u` (test-supplied, not a product preset). Channel `MTV` / `MTV.in@SD`.

## Non-goals

- `reqwest` / Tokio HTTP client in `airo_core` for epg.pw
- The **device** downloading epg.pw `epg.xml.gz` (~50 MB) or `guide_ALL.xml.gz` on TV/iOS boot
- JioTV/TataPlay catch-up, numeric operator ids, or Widevine playlist demos from tvepg
- Fuzzy name matching against a third-party channel index
- Compiling XMLTV blobs into the APK
- One-tap iptv-org country M3U or `streams.json`
- Shipping WebGrab+Plus, m3u4u, or EPGShare01 as a vendor SDK
- Changing the 30s receive timeout or 100k programme cap in this spec

## Implementation slices (after spec approval)

1. **Match override entry** — open `EpgMatchOverrideSheet` from Guide for the selected channel; widget tests that Save writes `543480` and the paged window queries that id.
2. **Copy** — Guide URL helper text: paste XMLTV or `.xml.gz`, not an HTML schedule page.
3. **Pipeline** — CI fetches epg.pw **global** `epg.xml.gz` (HTTP/1.1, retries), remaps to iptv-org ids, publishes `guide_XX.xml.gz` for every country present plus `guide_ALL.xml.gz` and `manifest.json` to R2. App dart-defines point at that manifest; the client requests only `guide_XX` for ISO codes in the current playlist.
4. **Privacy** — one sentence if slice 3 ships in a Play build.

Slice 1 unblocks pasted epg.pw MTV UAT. Slice 3 is the product default. Do not enable dart-defines until at least `guide_IN.xml.gz` is on R2 with a checksum.

## Testing

- Keep existing `xmltv_source_refresh_service_test` (gzip, checksum, system vs user kind).
- Add Guide widget test: Match EPG action visible; save override invalidates `guideEpgOverridesProvider` and `guidePagedWindowProvider`.
- Keep `guide_window_query_test` coverage for override + `@SD` alias. Add: XMLTV id `543480` remapped onto playlist channel id; `playChannel` receives that `IPTVChannel`.
- No network tests against epg.pw in CI; use a local XML fixture with `channel id="543480"`.
