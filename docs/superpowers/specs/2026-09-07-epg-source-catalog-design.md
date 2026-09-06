# EPG source catalog + guide picker + viewer polish

- **Status:** approved for implementation
- **Branch/worktree:** `agent/media-intelligence/epg-source-catalog` (`airo-worktrees/epg-source-catalog`)
- **Owner council:** media-intelligence-architect (`platform_epg`, `feature_iptv`); chief-release-devops-officer reviews the workflow change
- **Related:** `.github/workflows/iptv_guide_r2.yml`, `iptv-data/src/epg_pw_remap.py`, `iptv-data/src/epg_publish_prefer.py`, `packages/platform_epg`, `packages/feature_iptv`

## Problem

The EPG pipeline publishes exactly one guide per country (`epg.pw`, IN by
cron default) to Cloudflare R2. The app's only way to point at a different
guide is `XmltvSourceSheet` — a raw-URL paste box with no catalog, no
search, no metadata. Two public guide mirrors, `iptv-epg.org/guides` and
`epgshare01.online`, each carry far more per-country coverage than the
current single source, but neither exposes an API — both are static file
dumps. The in-app guide viewer (`epg_touch_timeline_grid.dart`) already has
a live now-line, jump-to-now, and reminders, but has no search bar,
category filter, or favorites-only toggle — the TV variant has a search bar
the touch variant lacks entirely.

This spec covers three independently shippable milestones: widen the
pipeline's source pool, replace the raw-paste UX with a browsable catalog,
and close the touch-grid filter gap.

## Non-goals

- No new backend service. Everything stays static-file-in, static-file-out
  through the existing `iptv-data` Python pipeline and R2 bucket.
- No fetch of `epgshare01`'s `ALL_SOURCES` file (205MB) or any full-catalog
  dump — same reasoning as the existing `guide_ALL` device-fetch ban.
- No change to `MultiSourceEpgMerger` / `IncrementalMultiSourceEpgRepository`
  semantics — one winning source per country continues to be published
  under the existing single `guide_XX` manifest key. Multi-source ranked
  merging already exists in `platform_epg` for a future need; this work
  does not require exercising it.
- No redesign of `MobileFavoritesScreen` — M3 adds an inline favorites
  *filter* to the grid, not a replacement for the standalone screen.

## M1 — Pipeline: widen the source pool

**Sources added**, both fetched as plain HTTP GETs, same as the existing
`epg.pw` step:

- `iptv-epg.org`: one file per country at
  `https://iptv-epg.org/files/epg-{cc}.xml` (lowercase ISO-3166 alpha-2).
- `epgshare01.online`: one file per country/provider at
  `https://epgshare01.online/epgshare01/epg_ripper_{SLUG}1.xml.gz` (slug is
  a country code or provider name, e.g. `IN`, `US_LOCALS`, `PLEX`).

**Allow-list, not a crawl.** No new config file: both new sources accept
the exact same plain two-letter code the pipeline already uses for
`epg.pw` (`iptv-epg.org/files/epg-{cc}.xml`,
`epgshare01.online/epgshare01/epg_ripper_{CC}1.xml.gz` — confirmed against
real filenames on that host, e.g. `epg_ripper_IN1.xml.gz`,
`epg_ripper_AE1.xml.gz`). Reuse the workflow's existing `$COUNTRY`
input/cron value for all three fetches. Never enumerate a source's
directory listing and fetch everything it contains, and never fetch
epgshare01's `ALL_SOURCES` file (~205MB) — same reasoning as the existing
`guide_ALL` device-fetch ban.

**Selection logic.** `epg_publish_prefer.py`'s existing
`select_countries_to_publish` belongs to the *other*, heavier pipeline
(`iptv_sanity.yml`) and is untouched by this work. Add a new, separate
function, `select_best_source_per_country`, used only by
`iptv_guide_r2.yml`: given one directory per source (each already run
through `epg_pw_remap.remap_epg_pw_xmltv` — the function generalizes past
its name, since it keeps an id unchanged when it's already a catalog id
and only falls back to name-matching otherwise, so it's equally correct
for epgshare01/iptv-epg.org output that already ships iptv-org-style ids),
pick whichever source has the most `<programme>` elements for that
country. No regression guard against the previously-published guide:
`iptv_guide_r2.yml` has never had one (it republishes unconditionally
today), so this stays consistent rather than inventing new protective
complexity this cron never needed.

**Workflow.** `iptv_guide_r2.yml` gains one fetch+remap step per new
source (soft-fail: a 404 or timeout produces no file for that source,
never fails the job — reusing the existing gzip/checksum/leaked-id-guard
steps only for the winning candidate), then a scoring step
(`select-best-source` CLI subcommand) that picks the winner before the
existing R2 upload step runs. Keep the 20-minute job timeout.

**Catalog side-output.** The same scoring step writes
`iptv-data/output/current/epg_catalog.json`: one entry per published
country — `{countryCode, countryName, sourceId, programmeCount,
channelCount, updatedAt}` — sourced from data already computed during
scoring (no extra fetch). This file is uploaded to R2 alongside
`manifest.json` and is the only new artifact M2 depends on.

**Testing:** extend `iptv-data/tests/test_epg_publish_prefer.py` for the
N-way scoring (currently only covers the 2-way case), and add a unit test
for the catalog writer. No changes to `iptv_sanity.yml`'s heavier pipeline.

## M2 — App: curated guide picker

`XmltvSourceSheet` (`packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart`)
keeps its current "paste a URL" flow — BYOC XMLTV is a shipped feature and
must not regress — but demotes it to an "Advanced: custom URL" expandable
section at the bottom. Above it, a new "Browse guides" list:

- Backed by a new `epgCatalogProvider` in `guide_providers.dart` that fetches
  `epg_catalog.json` from the same R2 base URL the manifest already comes
  from (reuse `xmltv_source_refresh_service.dart`'s existing R2 base-URL
  resolution — do not hardcode a second URL constant).
- One row per catalog entry: flag (reuse whatever flag/country-icon widget
  `feature_iptv` already has for channel countries — check before adding a
  new one), country name, programme/channel counts, relative "updated"
  time.
- A `TextField` filters rows by country name/code client-side (the catalog
  is at most a few hundred rows — no server-side search needed).
- Selecting a row calls the already-shipped
  `XmltvSourceRefreshService.refreshSystemGuidesForCountries(manifestUrl:
  ..., countries: {entry.countryCode})` — the same method
  `airo_tv_bootstrap_io.dart` already uses to fetch a system guide shard —
  passing just that one country. No new URL-resolution or download code
  path; the catalog only supplies which country to ask for.

**Testing:** widget test for search-filters-rows and for
row-tap-triggers-refresh-with-expected-url; a fake/fixture
`epg_catalog.json` for the provider test.

## M3 — Viewer polish (touch grid)

`iptv_guide_screen.dart` already renders one shared search `TextField`
(wired to `guideSearchQueryProvider`) above whichever grid loads —
`EpgTimelineGrid` (TV) or `EpgTouchTimelineGrid` (phone) — so both
surfaces already have search; correct that. What's actually missing,
added to that same shared header so both grids get it for free:

- **Favorites-only toggle** — a filter chip that intersects
  `guideFilteredChannelsProvider`'s output with the existing favorites set
  (reuse whatever backs `MobileFavoritesScreen`'s favorite-channel list —
  do not create a second favorites store).
- **Category filter chips** — derive the chip set from the categories
  already present in the currently-loaded channel list (no new taxonomy);
  selecting a chip narrows `guideFilteredChannelsProvider`'s input the same
  way the search query does.

Both are additive filters composed into `guideFilteredChannelsProvider`
alongside the existing search/scope filtering, not a parallel filter
stack. Because the header lives once in `_IptvGuideScreenState.build()`,
adding the chips there gives both the TV and touch grid the same controls
in one change.

**Testing:** provider-level tests for chip/favorite/search composition
(pure logic, no widget pump needed); one widget test confirming the new
controls render in the shared header and narrow the visible channel list.

## Rollout / sequencing

M1 → M2 → M3, each its own PR: M1 has no Dart surface and can land and run
on its cron independently; M2 depends on M1's `epg_catalog.json` existing
in R2 (fall back gracefully — empty catalog list, custom-URL section still
usable — if the file is 404, since a fresh R2 bucket or a mid-rollout state
will hit this); M3 has no dependency on M1/M2 and could ship first if
sequencing needs to change, but is listed last because it's the
lowest-risk, most isolated change.

## Error handling

- Pipeline: any single source fetch failing excludes that candidate from
  scoring, never fails the job (see M1).
- App: `epgCatalogProvider` failure (network, 404, malformed JSON) degrades
  to an empty browse list with the custom-URL section still fully
  functional — never blocks the existing BYOC path.
