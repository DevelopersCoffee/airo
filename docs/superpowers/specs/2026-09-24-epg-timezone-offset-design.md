# Spec: EPG timezone offset (device zone for naked XMLTV)

**Status:** Approved — 2026-09-24 (brainstorming: goal, runtime, failures)
**Date:** 2026-09-24
**Product:** Aika Stream (`feature_iptv`; Guide + XMLTV ingest via `platform_epg` → `airo_epg`)
**Follows:** Slice 1 settings, resume-on-TV, sleep timer
**Out of this spec:** CV-016, Library live peek, Settings offset row, IANA picker, per-source override

## Objective

Guide clock labels match the sofa clock for XMLTV files that omit `+ZZZZ`. Stored programmes stay UTC. Stamps that already include an offset are unchanged.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Canonical store | UTC `DateTime` on `CompactEpgProgram.startsAt` / `endsAt`. Display still uses `.toLocal()`. |
| Naked stamps (`YYYYMMDDHHmmss` with no `+ZZZZ`) | Interpret civil time in the **device zone** using `DateTime.now().timeZoneOffset` at ingest, then convert to UTC. |
| Tagged stamps (`… +0530`, `… +0000`, `… -0400`) | Existing parse. Ignore device offset. |
| Settings | None. No Sources / Playback / Accessibility row. |
| Zone source | Dart `DateTime` on the device (`timeZoneOffset` / `timeZoneName`). Do not add a new timezone package. |
| DST | Offset at **ingest** (current system date), not a historical IANA conversion per programme date. |
| After a zone change | Next XMLTV refresh (manual Refresh or existing schedule) re-downloads and re-parses. No timezone-change listener in this slice. |
| Default / missing offset arg | `naiveOffset == null` keeps today's behavior (naked stamp = UTC) for other `airo_epg` consumers. Aika Stream always passes the device offset. |
| Layer | Parse contract in `airo_epg` (ICAST bump). `feature_iptv` `XmltvSourceRefreshService` supplies the offset. `platform_epg` pins the new `airo_epg`. |

## Non-goals

- User-picked hour offset, IANA list, or per-XMLTV-source override.
- Display-only label shift that leaves now/progress/reminders on the old instants.
- Rewriting XMLTV text with regex before parse.
- Duplicating the timestamp parser inside `feature_iptv`.
- Adding `timezone` / `flutter_timezone` to `feature_iptv`.
- Caption/audio language (CV-016) or live peek.

## Why this shape

Naked XMLTV is the lie: ingest treats missing `+ZZZZ` as UTC, then Guide does `.toLocal()`, so a file written in the sofa's civil time shows shifted by the device UTC offset. Files that already carry `+ZZZZ` are already correct; shifting them again would double-apply.

A Settings picker is the wrong sofa control when the TV already knows its zone. `DateTime.now().timeZoneOffset` is that zone. Parse-time conversion keeps Guide now-line, progress, and reminders aligned with the labels.

The parser lives in published `airo_epg`, not in `feature_iptv`. Threading `naiveOffset` through `parseXmltvTimestamp` and `fromXmltv*` is the ICAST bump TODOS already called out. Today `fromXmltvFileNative` still converts raw `start`/`stop` strings with the Dart `parseXmltvTimestamp`; that is the live path to change. Rust `parse_xmltv_timestamp_epoch_seconds` must take the same rule when native ingest stops being a Dart fallback.

## Approaches considered

1. **`airo_epg` naive-offset at parse** — chosen.
2. **Duplicate parse in `feature_iptv`** — rejected: two parsers vs Rust / `airo_epg`.
3. **Rewrite naked stamps to `+ZZZZ` in the worker** — rejected: regex on large files, easy to corrupt.
4. **Manual UTC / UTC+5:30 Sources control** — rejected in brainstorming: device zone is the source of truth; no Settings row.

## Architecture

```text
Device DateTime.now().timeZoneOffset
        │
        ▼
XmltvSourceRefreshService.refresh
        │ fromXmltvFileNative(..., naiveOffset: offset)
        ▼
airo_epg parseXmltvTimestamp
        │ tagged +ZZZZ → existing UTC conversion
        │ naked        → civil time in naiveOffset → UTC
        ▼
CompactEpgProgram (UTC)
        │
        ▼
Guide UI .toLocal()  (unchanged)
```

## Components

### `airo_epg`

- `parseXmltvTimestamp(String value, {Duration? naiveOffset})`
  - Tagged: unchanged (offset in the string wins).
  - Naked + `naiveOffset == null`: UTC civil (today).
  - Naked + `naiveOffset`: `DateTime.utc(civil).subtract(naiveOffset)` (same sign convention as `+HHMM` in the current parser: east of UTC subtracts).
- Thread `naiveOffset` through `fromXmltv`, `fromXmltvFileNative`, `fromXmltvCurrentNextFileNative`, and `_fromNativeResult`.
- Keep `xmltv_parser.dart`'s `_parseXmltvTimestamp` in lockstep if it still converts programmes.
- Rust `parse_xmltv_timestamp_epoch_seconds` in `airo_core`: optional naive offset seconds; default 0 = UTC. Same tagged-wins rule. Land with the Dart bump even if Airo still hits the Dart fallback.

### `platform_epg`

- Bump `airo_epg` constraint to the published version that includes `naiveOffset`.
- Re-export only; no second parser.

### `feature_iptv`

- `XmltvSourceRefreshService.refresh` passes `naiveOffset: DateTime.now().timeZoneOffset` into `fromXmltvFileNative`.
- Do not persist an offset pref.
- Do not add UI to `XmltvSourceSheet` / TV Sources.
- Existing download / gzip / checksum workers unchanged. Offset is a `Duration` argument, not a parse-on-main change.

## Runtime flow

1. User has an XMLTV URL. Refresh downloads (existing worker) and parses with the current device offset.
2. Naked `20260715200000` on a UTC+5:30 TV becomes `14:30Z`. Guide shows 8:00 PM local.
3. Tagged `20260715200000 +0000` stays `20:00Z` even on that TV. Guide shows local-from-UTC.
4. User Refresh on the XMLTV sheet: full re-download + parse with whatever `timeZoneOffset` is now.
5. User travels or the OS DST flag flips: labels stay on the last ingest until the next refresh.

## Error handling

| Case | Result |
| --- | --- |
| Unparseable stamp | Same as today (`null` / skip / default duration). |
| Download or checksum failure | Same as today; keep last good Guide. |
| `naiveOffset` omitted | Naked = UTC (library default). |
| Native parse fallback | Dart `parseXmltvTimestamp` still applies `naiveOffset`. |
| Zone changes mid-session | No live shift; wait for next refresh. |

No toast for timezone. Guide looking right after refresh is the signal.

## Testing

TDD in `airo_epg` first, then a narrow `feature_iptv` refresh test.

- Naked `20260715090000` + `Duration(hours: 5, minutes: 30)` → `03:30Z`.
- Naked + `null` → `09:00Z`.
- Tagged `20260715090000 +0000` + device `+5:30` → still `09:00Z`.
- Tagged `20260715143000 +0530` + any `naiveOffset` → still `09:00Z`.
- `XmltvSourceRefreshService` test: `fromXmltvFileNative` / repository seam receives a non-null `naiveOffset` equal to a injected clock's `timeZoneOffset`.

Do not wait on a full Guide widget pump to prove parse math.

## Files (expected)

- `airo_epg` (separate repo, then pub): `parseXmltvTimestamp`, ingest factories, existing timestamp tests.
- `airo_core` `rust/.../xmltv.rs` timestamp helper + tests (same rule).
- `packages/platform_epg/pubspec.yaml` — pin.
- `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart` + refresh tests.
- Do not edit Settings hub, TV Sources chrome, or `bedtime_mode_provider`.

## Success

On a Fire TV in India, a provider XMLTV with naked local stamps shows 8:00 PM as 8:00 PM on the Guide axis and detail row after refresh. The same file with `+0000` on those stamps still shows as UTC converted to IST. There is no new Settings tile. A Pixel in the same zone gets the same ingest rule from the shared refresh service.
