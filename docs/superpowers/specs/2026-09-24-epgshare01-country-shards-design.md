# Spec: Country EPG from EPGShare01 shards (`airo_epg` then Aika Stream)

**Status:** Approved — 2026-09-24 (brainstorming: skip Cloudflare; country picker A; `airo_epg` then consume)
**Date:** 2026-09-24
**Product:** Aika Stream (`feature_iptv`) consumes published `airo_epg` via `platform_epg`
**Council:** media-intelligence-architect (`airo_epg` / `platform_epg`); flutter-architect (`feature_iptv`); chief-security-officer (Play / privacy sentence)
**Follows:** BYOC XMLTV (`2026-09-02-byoc-xmltv-system-guide-design.md`), catalog R2 (`2026-09-07-epg-source-catalog-design.md`)
**Out of this spec:** thinner split handle, compact `TvFontMode`, resolution browse filter, timezone `naiveOffset` (`airo_epg` 1.1.0 on `feat/xmltv-naive-offset`), Cloudflare R2 publish, moving `iptv-data` M3U pipeline, Play versionCode bump

## Objective

Picking a country in Settings / browse loads that country's EPGShare01 gzip (India → `epg_ripper_IN1.xml.gz`, ~4 MB), not the 192 MB `ALL_SOURCES` dump. Parse must not OOM. The allow-list and size guards live in published `airo_epg`; Aika Stream only picks the country and downloads.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Shard host | `https://epgshare01.online/epgshare01/` country gzips only. No Cloudflare, no R2 manifest, no `IPTV_DATA_MANIFEST_URL` for this cut. |
| Country key | `channelFiltersProvider.country` (`iptv_filter_country`). Same value as Settings country tile and first-run country prompt. |
| Locale fallback | None. Empty country → do not download. Last good system guide stays until a new country fetch succeeds. |
| User paste | If a **user** XMLTV URL is saved, skip country auto-fetch. Paste still wins (priority 0). Country fetch is `XmltvSourceKind.system` (priority 1) only when no user source is configured. |
| Filename rule | Static allow-list in `airo_epg`, not a directory crawl. Per ISO-3166 alpha-2, the **largest** `epg_ripper_{CC}{N}.xml.gz` on the 2026-09-23 index (so `IN`→`IN1`, `US`→`US2`, `CA`→`CA2`, `BE`→`BE2`, `SA`→`SA2`, `TR`→`TR3`). `GB` and `UK` both → `UK1`. |
| Banned | `ALL_SOURCES`, `guide_ALL`, `US_LOCALS`, `DUMMY_CHANNELS`, provider-only slugs (`PEACOCK`, `PLEX`, …). Never auto-load those. |
| Compressed cap | **16 MiB** gzip (covers `PL1` ~8.2 MiB with headroom). Fail before inflate. |
| Uncompressed cap | **80 MiB** while streaming gzip. Fail if exceeded. |
| `airo_epg` version | **1.2.0**. Do not collide with unpublished timezone **1.1.0**. Airo `platform_epg` pins `airo_epg: ^1.2.0` after pub.dev. |
| HTTP in `airo_epg` | None. No Dio. Package resolves URI + rejects unsafe URLs/sizes. Aika Stream downloads with existing `XmltvSourceRefreshService`. |
| Channel ids | Overlay-only on the user’s playlist (existing Guide). No remap pipeline in this cut. Mismatched `tvg-id` stays a Match-EPG problem, not a download problem. |
| Play | Do not ship `ALL_SOURCES` or a stream catalogue. Compiled pattern is country-shard XMLTV the user opted into by picking a country. Privacy: one sentence. |

## Non-goals

- Fetching or parsing `epg_ripper_ALL_SOURCES1.xml.gz`.
- Cloudflare object-store shards, `epg_catalog.json`, or enabling `IPTV_DATA_MANIFEST_URL`.
- Crawling the EPGShare01 directory at runtime.
- Moving Python `iptv-data` (M3U sanity) into `airo_epg`.
- Streaming SAX parse rewrite (byte caps + country files are the OOM fix). `readAsString` stays for files that pass the caps.
- Handle paint, compact fonts, resolution chips.
- Publishing `airo_epg` 1.1.0 timezone in the same cut.

## Why this shape

The world file OOMs because decompress + `File.readAsStringSync()` materializes hundreds of MB. EPGShare01 already splits by country; India is ~4 MB gzip. Cloudflare remapping is extra ops and is unset on Play anyway. Putting the allow-list in `airo_epg` keeps Airo lean and gives other consumers the same safety. Country picker is the opt-in the user already uses; locale auto-fetch was rejected so a GB phone with no picker does not surprise-download `UK1`.

## Approaches considered

1. **Country picker → EPGShare01 allow-list in `airo_epg`** — chosen.
2. **Cloudflare R2 `guide_XX` + catalog sheet** — rejected for this cut: extra host, Play dart-define unset, user already has shards on EPGShare01.
3. **Locale / SIM country auto-fetch** — rejected (user chose A).
4. **Paste-only + size error** — rejected as the only fix: testers still have no working default guide.

## Architecture

```text
Settings / browse country picker
        │ channelFiltersProvider.country  (null → no fetch)
        ▼
Aika Stream (no user XMLTV URL?)
        │ Epgshare01CountryShard.resolve(country)
        ▼
airo_epg 1.2.0
        │ Uri or XmltvShardUnavailable
        │ XmltvIngestGuard.assertSafeUrl / assertSafeFile
        ▼
XmltvSourceRefreshService.refresh(url, kind: system)
        │ Dio download, 16 MiB / 80 MiB caps, then existing gzip + fromXmltvFileNative
        ▼
MutableXmltvCompactEpgRepository  (system priority 1)
        ▼
Guide overlay on playlist channels
```

## Components

### `airo_epg` 1.2.0 (https://github.com/DevelopersCoffee/airo_epg)

New public surface (names can match this shape):

- `Epgshare01CountryShard.resolve(String countryCode) → Uri`
  - Trim, upper-case. `GB` → same URI as `UK`.
  - Look up the frozen slug table (below). Build
    `https://epgshare01.online/epgshare01/epg_ripper_{slug}.xml.gz`.
  - Unknown or empty → throw `XmltvShardUnavailableException`.
- `XmltvIngestGuard.assertSafeUrl(Uri url)`
  - HTTPS or HTTP only.
  - Reject path/query containing `ALL_SOURCES`, `guide_ALL`, `US_LOCALS`, `DUMMY_CHANNELS` (case-insensitive).
- `XmltvIngestGuard.assertSafeLength({required int compressedBytes, int? uncompressedBytes})`
  - compressed > 16 MiB or uncompressed > 80 MiB → `XmltvIngestTooLargeException`.
- Export from `airo_epg.dart` / `platform_epg.dart`. Tests in that repo. CHANGELOG 1.2.0. Publish to pub.dev.

**Slug table** (largest two-letter country gzip on the 2026-09-23 index; `GB` aliases `UK`):

`AE1 AL1 AR1 AT1 AU1 BA1 BB1 BE2 BG1 BR1 CA2 CH1 CL1 CO1 CR1 CY1 CZ1 DE1 DK1 DO1 EC1 EG1 ES1 FI1 FR1 GR1 HK1 HR1 HU1 ID1 IE1 IL1 IN1 IT1 JM1 JP1 KE1 KR1 KZ1 LT1 LU1 LV1 MN1 MT1 MX1 MY1 NG1 NL1 NO1 NZ1 PA1 PE1 PH2 PK1 PL1 PT1 RO1 RS1 SA2 SE1 SG1 SK1 SV1 TH1 TR3 UK1 US2 UY1 VN1 ZA1`

Updating the table is an `airo_epg` minor when EPGShare01 adds or renames a country file. Airo does not scrape the index.

### `platform_epg` (Airo shim)

- Bump `airo_epg: ^1.2.0`. Re-export only.

### `feature_iptv`

- After country is set (picker save / first-run prompt) and there is **no** user XMLTV config: `resolve` + `refresh(..., kind: system)`.
- Clearing country does **not** clear the last system guide and does **not** fetch.
- Changing country from IN → US replaces the system source with `US2` on success; failure keeps the previous system guide (`_recordFailureKeepingExistingUrl`).
- `refresh()` calls `assertSafeUrl` **before** `dio.download`. After download, `assertSafeLength` on file length; during gzip, stop if uncompressed bytes exceed 80 MiB.
- Advanced paste of `ALL_SOURCES` fails with a short message: pick a country in Settings; do not use the world file.
- Receive timeout for these downloads: **120s** (4–8 MB on slow TV Wi-Fi). Existing 30s is too tight.
- Do not add a second country control. Do not enable R2 catalog as the default path.
- Privacy / Play listing: one sentence that choosing a country downloads a programme-guide file for that country from a public XMLTV host. Do not name a stream catalogue.

## Runtime flow

1. User has a playlist. Country is empty → Guide has no system fetch. Paste still works if the URL passes the guard.
2. User picks India → `IN1` (~4 MB) downloads as system source → Guide fills for matching `tvg-id`s.
3. User pastes a provider XMLTV → country auto-fetch stops; refresh uses the paste URL (still guarded).
4. User pastes `.../epg_ripper_ALL_SOURCES1.xml.gz` → fail before download/inflate. Existing working source kept.
5. User picks a country with no shard (e.g. `XX`) → `XmltvShardUnavailableException`; copy: no guide file for that country; paste still available.

## Error handling

| Case | Result |
| --- | --- |
| Country null / blank | No auto-fetch. |
| Country not in table | Typed unavailable; keep last good system guide. |
| `ALL_SOURCES` / `US_LOCALS` URL | Typed too-large/banned; no download. |
| Compressed > 16 MiB | Fail before gzip. |
| Uncompressed > 80 MiB | Abort gzip; delete temps. |
| HTTP 404 | Same as today’s refresh failure. |
| Parse throw / OOM after caps | Treat as refresh failure; do not persist the new URL as working. |
| User source present | Skip country fetch entirely. |

No crash dialog. Sheet / Guide banner shows the typed message.

## Testing

**`airo_epg` (TDD, no network)**

- `IN` → URI ends with `epg_ripper_IN1.xml.gz`.
- `in` / `GB` → `UK1` for GB; IN case-insensitive.
- `US` → `US2`, not `US1` / `US_LOCALS`.
- `ZZ` → unavailable.
- `assertSafeUrl` rejects ALL_SOURCES and US_LOCALS; accepts `IN1` URI.
- Length helper rejects 16 MiB + 1 compressed and 80 MiB + 1 uncompressed.

**`feature_iptv`**

- Country `IN`, no user source → `refresh` invoked with the `IN1` URI, `kind: system`.
- Country null → refresh not invoked for system country fetch.
- User source saved → country `IN` does not call country fetch.
- Paste ALL_SOURCES → throws before Dio (guard), previous config kept.
- Gzip over uncompressed cap → failure path, temps deleted (existing finally block).

Do not require a live EPGShare01 fetch in CI. Optional golden: a tiny fixture gzip under the cap.

## Files (expected)

- `../airo_epg/lib/src/epgshare01_country_shard.dart` (new)
- `../airo_epg/lib/src/xmltv_ingest_guard.dart` (new)
- `../airo_epg/lib/airo_epg.dart`, `CHANGELOG.md`, `pubspec.yaml` `1.2.0`
- `packages/platform_epg/pubspec.yaml` pin
- `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart`
- Country-change fetch from `ChannelFiltersNotifier.setCountry` after persist. First-run prompt already calls `setCountry`, so it must not start a second download.
- Tests as above
- `PRIVACY.md` + Aika Stream Play listing / gate note (one sentence)
- Do not edit `iptv_guide_r2.yml` or split-view handle code

## Success

On a device with an India country pick and no pasted XMLTV, Guide loads from `epg_ripper_IN1.xml.gz` without OOM. Pasting the 192 MB ALL_SOURCES URL fails fast with copy pointing at the country picker. `airo_epg` 1.2.0 is on pub.dev and `platform_epg` consumes it. Cloudflare is unused for this path.
