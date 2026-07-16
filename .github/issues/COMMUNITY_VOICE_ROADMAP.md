# Airo TV V2 Community Voice Triage

## Decision Summary

This roadmap converts community requests into a v2 milestone plan that fits the current Airo TV release line. The current milestone is not an "AI media operating system" rewrite. It is a Play Store-safe, bring-your-own-content IPTV player with stronger performance, provider diagnostics, reliability, search, smart playlist cleanup, metadata caching, program guide usability, and TV usability.

**Adopt now:** community requests that improve user-provided playlist playback, provider capability/health visibility, large playlist handling, local search, smart playlist filtering, EPG/program guide performance, logo cache performance, diagnostics, captions, and D-pad usability.

**Defer:** requests that require accounts, cloud sync, household identity, DVR storage permissions, server-hosted-account provider integrations (e.g. Dispatcharr), multi-provider failover, full AI routing, or playback-engine rewrites. (BYOC-shaped provider adapters — Xtream/Stalker/Jellyfin, still user-supplied credentials — are adopted bounded under CV-018, not deferred.)

**Do not adopt for v2:** Docker/Home Server mode. It is a different product surface with server security, packaging, support, and release obligations.

**2026-07-16 update:** Two competitive gap analyses — AerioTV (Dispatcharr/Xtream/M3U, full guide, VOD, DVR, multiview, Google Drive sync) and StreamVault (Xtream/Stalker/Jellyfin, EPG grid with search/overrides, catch-up, DVR, offline downloads, plugins, TV Input Framework, 25 locales) — were triaged together and added CV-018 through CV-024, plus a slice-2 follow-on to CV-015. Provider adapters, VOD listing, the EPG grid, favorites, TV settings, and remote UX fit the BYOC model and were adopted bounded (issues [#823](https://github.com/DevelopersCoffee/airo/issues/823)–[#828](https://github.com/DevelopersCoffee/airo/issues/828)). Multiview and localization are tracked but deferred ([#829](https://github.com/DevelopersCoffee/airo/issues/829), [#830](https://github.com/DevelopersCoffee/airo/issues/830)). Everything requiring an account, cloud sync, background recording, or third-party metadata — the majority of both competitors' claimed surface — stays out, consistent with this roadmap's existing local-first decision, not overlooked.

## Current V2 Scope

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent, Mobile UI Agent
**Layer:** Mixed
**Sprint:** V2 Play Store readiness and IPTV performance hardening
**Parent packet:** `docs/features/iptv/PLAY_STORE_V2_FEATURE_PACKET.md`

### Critical Agent Gate

**Problem:** Community feedback points to IPTV pain around crashes, slow large playlists, provider confusion, playlist clutter, weak search, slow or missing program guides, stale metadata, unreadable TV UI, and unclear playback failures. We need to absorb the useful parts without breaking the v2 BYOC and Play Store compliance posture.
**User / actor:** Android mobile or TV user who supplies an authorized M3U/M3U8 playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent for reusable parsing/cache/player contracts, Security and Privacy Agent for playlist URL and network behavior, QA Automation Agent for deterministic evidence, Mobile UI Agent for TV UX, Release and DevEx Agent for cost-aware validation.
**Impacted modules/files:** `rust/airo_core`, `packages/platform_playlist_import`, `packages/platform_playlist`, `packages/platform_epg`, `packages/platform_player`, `packages/platform_streams`, `packages/platform_history`, `packages/platform_favorites`, `packages/feature_iptv`, benchmark tooling.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes. Current workspace is on `v2`.
**Open questions:** Final device evidence and Play Console artifacts remain release tasks. External provider, cloud account, and server mode decisions are explicitly outside this milestone.
**Decision:** Ready for the adopted bounded issues below. Deferred issues must not be implemented until re-triaged.

## Milestone Triage

| ID | Community request | V2 decision | Current milestone slice |
| --- | --- | --- | --- |
| CV-001 | Self-healing playback and diagnostics | Adopt bounded | Add diagnostics states, retry policy, explicit error taxonomy, and optional overlay. No decoder/plugin rewrite. |
| CV-002 | Cross-device cloud sync | Defer | Keep v2 local-first and BYOC. Revisit after account/privacy and sync schema decisions. |
| CV-003 | Device migration and license pairing | Defer | Not required for Play Store v2. Needs auth, entitlement, and token security design. |
| CV-004 | DVR/background recording | Defer | Storage, background execution, SMB, and recording rights are too large for current milestone. |
| CV-005 | Local AI semantic media layer | Defer | Depends on Offline LLM roadmap. Current v2 can expose structured search inputs only. |
| CV-006 | Universal search | Adopt bounded | Implement fast local search across user playlist, EPG, favorites, and history only. No YouTube/Plex/Jellyfin/DLNA. |
| CV-007 | Personalized home | Defer | Use existing Media Hub/home issues. Do not redesign app home for v2 release hardening. |
| CV-008 | Accessibility UI and persistent captions | Adopt bounded | Add TV font modes, D-pad surf mode, caption preference persistence. No online subtitle downloader. |
| CV-009 | Plugin media engine | Defer | Keep internal provider contracts stable. No public/community plugin runtime in v2. |
| CV-010 | Massive playlist engine | Adopt now | Extend existing Rust M3U/EPG work, worker boundaries, benchmark gates, and virtualized IPTV lists. |
| CV-011 | Home Server and Docker mode | Do not adopt for v2 | Park as future product research only. No Docker/server work in this milestone. |
| CV-012 | Provider capability, health, and metadata cache | Adopt bounded | Cache user-derived EPG/logo metadata, measure provider/source health, and show capability reports. No multi-provider failover or bypass behavior. |
| CV-013 | Household profiles | Defer | Requires identity/profile schema and parental control policy. Not part of current BYOC hardening. |
| CV-014 | Decoupled playback abstraction | Defer | Full Rust FFI/GPU texture path is too risky. Current v2 only documents engine diagnostics and adapter seams. |
| CV-015 | Program guide timeline | Adopt bounded | Build a windowed, virtualized EPG guide using existing Rust XMLTV/current-next boundaries. No Xtream/Stalker, server sync, custom RenderObject requirement, or AI guide queries. |
| CV-016 | Playback track selection and VOD timeline | Adopt bounded | Add audio/subtitle track controls, VOD duration/seek behavior, and single-session connection lifecycle checks. No transcoding or native playback rewrite. |
| CV-017 | Smart playlists and canonical channels | Adopt bounded | Let users collapse huge BYOC playlists into local rule-based packages and canonical channel aliases. No AI setup, provider marketplace, or cloud migration. |
| CV-018 | Provider adapter contracts (Xtream, Stalker, Jellyfin) | Adopt bounded | All three are still user-supplied URL + credentials against a server the user already has access to — no Airo-hosted account, same BYOC shape as M3U. Add a typed `ContentSource`/adapter contract so M3U, Xtream, Stalker, and Jellyfin share one capability model. No Dispatcharr, no provider marketplace. [Issue #823](https://github.com/DevelopersCoffee/airo/issues/823). |
| CV-019 | Local VOD listing over BYOC sources | Adopt bounded | Parse VOD entries already present in user-supplied M3U/Xtream sources and list them with local continue-watching from existing history. No TMDB/provider metadata enrichment, no offline downloads — those reintroduce an external API dependency or storage/DRM complexity this milestone explicitly avoids. [Issue #824](https://github.com/DevelopersCoffee/airo/issues/824). |
| CV-015b | Full EPG grid UI, guide search, XMLTV source management | Adopt bounded | Follow-on to CV-015 slice 1 (data layer, shipped). Wires the existing windowed-guide repository into a real horizontal-timeline grid with virtualization, proportional block widths, current-time indicator, search, and manual channel-to-EPG-id overrides. [Issue #825](https://github.com/DevelopersCoffee/airo/issues/825), parent [#819](https://github.com/DevelopersCoffee/airo/issues/819). |
| CV-021 | Favorites and hidden categories with persistence | Adopt bounded | `platform_favorites` is still the unmodified package template. Build a real local data layer plus a real TV Favorites screen (currently a placeholder), distinct from CV-017's rule-based smart playlists. [Issue #826](https://github.com/DevelopersCoffee/airo/issues/826). |
| CV-022 | TV settings and provider management screen | Adopt bounded | TV Settings route is currently a literal placeholder. Real screen: theme switcher, playback/accessibility preferences, source list/management once CV-018 lands. Parental-control PIN locking explicitly deferred, not silently dropped. [Issue #827](https://github.com/DevelopersCoffee/airo/issues/827). |
| CV-023 | TV remote UX: numeric entry, button remap, TV Input Framework | Adopt bounded | Extends the unified `TvFocusable`/`TvInputHandler` infra with numeric channel jump, colored-button remapping, and Android TIF sync. [Issue #828](https://github.com/DevelopersCoffee/airo/issues/828). |
| CV-020 | Local multiview | Defer | Multiple simultaneous local tiles is BYOC-compatible in principle, but needs CV-001's diagnostics/resource guardrails proven first so N streams don't silently degrade playback. Revisit after CV-001 and CV-016 ship. [Issue #829](https://github.com/DevelopersCoffee/airo/issues/829) (tracking only). |
| CV-024 | TV localization coverage | Defer | Tracked so it isn't lost, not release-blocking for Play Store v2 hardening. [Issue #830](https://github.com/DevelopersCoffee/airo/issues/830) (tracking only). |

## Adopted Issue Order

1. **CV-010: Large Playlist Engine**
   - Reason: Existing v2 work already includes Rust `airo_core` M3U/XMLTV parsing, worker boundaries, and benchmark tooling.
   - Outcome: 30k+ playlist import stays off the UI thread, search stays fast, scrolling stays stable.

2. **CV-001: Playback Diagnostics**
   - Reason: Community complaints about buffering and black screens are release-critical.
   - Outcome: Users see actionable failure states and automatic retries for transient failures.

3. **CV-012: Metadata Cache and Safe Stream Policy**
   - Reason: Provider unreliability, stale metadata, and "is it my provider or app?" confusion are repeated community pain points.
   - Outcome: User-derived metadata is cached locally, and users get local capability/health reports with privacy-safe diagnostics.

4. **CV-006: Local IPTV Search**
   - Reason: Search is high-value without adding external providers or account dependencies.
   - Outcome: Search indexes playlist, EPG, favorites, and history from user-provided data.

5. **CV-015: Program Guide Timeline**
   - Reason: The attached NodeCast review shows the useful ideas are windowed guide loading, virtualized rendering, local indexes, and repaint-only current-time updates.
   - Outcome: Users can browse a performant guide from local user-derived XMLTV/EPG data without Flutter parsing the full guide or rendering every cell as a widget.

6. **CV-008: TV Accessibility and Captions**
   - Reason: D-pad usability, readability, and caption persistence are core TV quality bars.
   - Outcome: Remote-first navigation and persistent caption preferences work predictably.

7. **CV-016: Playback Track Selection and VOD Timeline**
   - Reason: NodeCast issues repeatedly show user frustration when multi-audio, subtitles, VOD duration, seek controls, and stream connection cleanup are missing or unclear.
   - Outcome: Existing playback-engine track/duration seams become user-facing controls with deterministic tests.

8. **CV-017: Smart Playlists and Canonical Channels**
   - Reason: Reddit product feedback shows users mostly want less clutter and a consistent cable-TV experience over a huge, unreliable provider feed.
   - Outcome: Users can build a small local "My TV" view using deterministic filters and aliases without editing the raw playlist.

9. **CV-018: Provider Adapter Contracts** — [Issue #823](https://github.com/DevelopersCoffee/airo/issues/823)
   - Reason: Two independent comparisons (AerioTV, StreamVault) both flag provider depth as the single largest capability gap that still fits the BYOC model — user-supplied credentials against a server the user already controls access to, not an Airo-hosted account.
   - Outcome: M3U, Xtream, Stalker, and Jellyfin sources share one `ContentSource` capability contract; no new account, sync, or marketplace surface.

10. **CV-019: Local VOD Listing** — [Issue #824](https://github.com/DevelopersCoffee/airo/issues/824)
    - Reason: BYOC sources (M3U/Xtream) already carry VOD entries; listing them locally with existing history-based continue-watching closes a real gap without adding a cloud metadata dependency.
    - Outcome: Users browse VOD from their own source without Airo fetching or caching third-party metadata.

11. **CV-015b: Full EPG Grid UI** — [Issue #825](https://github.com/DevelopersCoffee/airo/issues/825)
    - Reason: CV-015 slice 1 (data layer) shipped, but the guide screen is still a current/next list, not the windowed timeline both comparisons expected.
    - Outcome: Real virtualized guide grid with proportional block widths, current-time indicator, search, and manual EPG-match overrides.

12. **CV-021: Favorites and Hidden Categories** — [Issue #826](https://github.com/DevelopersCoffee/airo/issues/826)
    - Reason: `platform_favorites` has no real data layer yet and the TV route is a placeholder — a directly-requested, simpler feature than CV-017's rule engine.
    - Outcome: Favorite/hide channels and groups with real local persistence.

13. **CV-022: TV Settings and Provider Management** — [Issue #827](https://github.com/DevelopersCoffee/airo/issues/827)
    - Reason: TV Settings is a literal placeholder today; both comparisons note settings/provider-management is thin-to-nonexistent.
    - Outcome: Real theme/playback/accessibility settings and source management, once CV-018 exists.

14. **CV-023: TV Remote UX** — [Issue #828](https://github.com/DevelopersCoffee/airo/issues/828)
    - Reason: Numeric channel entry and remote button remapping are common TV-client expectations Airo lacks.
    - Outcome: Numeric jump-to-channel, colored-button remapping, Android TV Input Framework sync.

## Explicit Non-Goals For Current V2

- No bundled, default, first-party, or reviewer-specific IPTV sources.
- No Docker, NAS, Raspberry Pi, Unraid, or Home Server packaging.
- No cloud sync, account-required onboarding, or entitlement migration.
- No background DVR, SMB/NFS recording, broad storage permission, or recording-rights workflow.
- No public plugin marketplace or arbitrary community code execution.
- No YouTube, Plex, Jellyfin, DLNA, podcast, or external provider aggregation.
- No Stalker provider implementation. Xtream is scoped separately under CV-018; still no Xtream/Stalker work inside the program-guide slice itself.
- No online subtitle provider integration.
- No AI/SLM program-guide query execution.
- No AI/SLM smart-playlist rule generation in the current slice.
- No provider marketplace, provider scoring marketplace, multi-provider automatic failover, or automatic provider replacement workflow.
- No Dispatcharr or any server-hosted-account provider model — that reintroduces an account/identity surface this milestone stays local-first to avoid.
- No DVR (local or server-side), recording scheduler, or comskip-style processing — see CV-004.
- No Google Drive, iCloud, or any cloud AppData sync for configs, favorites, watch progress, or reminders — see CV-002.
- No third-party VOD metadata (TMDB or otherwise) — see CV-019; VOD listing stays limited to what the user's own source already provides.
- No multiview product surface until CV-020's prerequisites (CV-001, CV-016) ship.
- No server-side transcoding, hardware encoder selection, or FFmpeg pipeline work in the current playback-control slice.
- No promise to bypass provider, ISP, CORS, DRM, paywall, or geo restrictions.
- No full playback-engine rewrite, custom GPU texture pipeline, or required custom EPG RenderObject in this milestone.

## Cross-Agent Contract

**Provider agents:** Framework Agent, Media Agent.
**Consumer agents:** Media Agent, Mobile UI Agent.
**Interface/API:** Existing BYOC playlist path plus bounded additions in platform packages: Rust parsing/benchmark APIs, local source capability/health APIs, local search index APIs, smart playlist rule APIs, canonical channel identity APIs, program-guide window APIs, playback diagnostics models, playback track/timeline controls, metadata cache services, and TV accessibility state.
**Input shape:** User-entered HTTP(S) playlist URLs, user-derived playlist rows, XMLTV/EPG files, local filtering rules, user playback events, user-selected audio/subtitle/caption/accessibility settings.
**Output shape:** Parsed channel entries, source capability reports, source health snapshots, canonical channel records, filtered package views, indexed local search records, guide window slices, cache metadata, playback diagnostic states, retry decisions, track lists, duration/seek state, TV UI state.
**State changes:** Local-only playlist cache, local source health snapshots, local smart playlist rules, local canonical alias records, local EPG/logo cache, local search index, local history/favorites, local audio/subtitle/caption/accessibility preferences.
**Errors:** Invalid playlist URL, network timeout, provider 401/403/429/5xx, decode unsupported, cache quota exceeded, malformed M3U/XMLTV, missing caption track.
**Permissions:** Internet for user-specified playlist/media URLs. No broad storage permission, no background recording permission, no account permission, no server discovery permission.
**Privacy/redaction:** Playlist credentials and full URLs are user data. Logs and diagnostics must redact credentials and query strings unless the user explicitly exports a diagnostic bundle.
**Persistence:** Local app data only for current milestone. No cloud replica.
**Versioning/migration:** Existing v2 BYOC cache behavior remains compatible. New caches must be rebuildable and safe to clear.
**Tests required:** Focused package tests, Rust unit/benchmark tests, host-only static checks, and TV widget tests where UI is touched.

## Deterministic Use Cases

### UC-001: Fresh BYOC install remains empty
**Actor:** Google Play reviewer or first-time user.
**Preconditions:** No playlist URL saved.
**Trigger:** Open IPTV.
**Happy path:** App shows setup state and does not fetch or display channels.
**Failure paths:** None; no remote source is inferred.
**Data created/updated/deleted:** None.
**Privacy expectations:** No playlist, account, or provider data leaves the device.

### UC-002: Large user playlist imports without UI stall
**Actor:** User with an authorized large playlist.
**Preconditions:** User supplies a valid HTTPS M3U URL containing tens of thousands of entries.
**Trigger:** Save and import playlist.
**Happy path:** Parsing runs through Rust/worker boundaries, cache is updated, and UI remains responsive.
**Failure paths:** Malformed rows are skipped with stats; failed fetch leaves prior user-derived cache if present.
**Data created/updated/deleted:** Local playlist cache and index are updated.
**Privacy expectations:** URL credentials are redacted from logs and diagnostics.

### UC-003: Playback failure gives a recoverable state
**Actor:** User watching a playlist channel.
**Preconditions:** Channel URL is user-provided and playback starts.
**Trigger:** Stream stalls, times out, or returns an HTTP error.
**Happy path:** Diagnostics record the failure class, retry allowed transient failures, and show a clear user-facing state.
**Failure paths:** Persistent failures stop retrying and explain the likely cause.
**Data created/updated/deleted:** Local diagnostic event only.
**Privacy expectations:** Diagnostic copy does not expose credentials.

### UC-004: Search uses only local user-derived data
**Actor:** User searching on TV or mobile.
**Preconditions:** Playlist and optional EPG data have been imported by the user.
**Trigger:** User enters a search query.
**Happy path:** Results come from local playlist, EPG, favorites, and history indexes.
**Failure paths:** Empty index returns an empty state.
**Data created/updated/deleted:** Optional local search index records.
**Privacy expectations:** Search query is not sent to external media providers.

### UC-005: Program guide browses a visible window
**Actor:** Android TV user browsing the guide.
**Preconditions:** User-derived playlist and optional XMLTV/EPG data have been imported.
**Trigger:** User opens Guide.
**Happy path:** App loads only visible channel rows and a bounded time window around the viewport, paints a current-time indicator, and keeps focus/navigation responsive.
**Failure paths:** Missing EPG shows channel rows with an unavailable guide state; stale EPG shows stale state and refresh affordance.
**Data created/updated/deleted:** Local guide window cache/index.
**Privacy expectations:** Guide source URL is redacted and no external provider is queried.

### UC-006: VOD exposes duration and track controls
**Actor:** User watching a VOD item from their own playlist.
**Preconditions:** Playback engine reports duration and available audio/subtitle tracks.
**Trigger:** User opens playback controls.
**Happy path:** User can see total duration, seek within valid bounds, and switch audio/subtitle tracks.
**Failure paths:** Missing tracks hide unavailable controls; failed track selection reports a user-safe error.
**Data created/updated/deleted:** Local playback preference only.
**Privacy expectations:** Track labels and media URLs are not logged with credentials.

### UC-007: Smart playlist hides clutter
**Actor:** User with a large provider playlist.
**Preconditions:** Imported playlist contains live TV, VOD, radio, adult groups, duplicate variants, and multiple languages.
**Trigger:** User creates a local package such as "My TV" with English, live-only, no adult, no radio, and minimum 720p filters.
**Happy path:** UI shows a small filtered channel set while preserving the raw imported playlist.
**Failure paths:** Empty package shows rule summary and lets the user relax filters.
**Data created/updated/deleted:** Local smart playlist rule and canonical alias state.
**Privacy expectations:** Rules remain local and do not contact provider or external services.

### UC-008: Provider health explains buffering
**Actor:** User watching a live event.
**Preconditions:** User-provided source has recent playback and metadata request metrics.
**Trigger:** Stream buffers or fails.
**Happy path:** Airo shows whether provider response, network, decode, or segment latency is the likely cause.
**Failure paths:** Insufficient samples show "not enough data" instead of guessing.
**Data created/updated/deleted:** Local redacted provider health snapshot.
**Privacy expectations:** Credentials and raw URLs are redacted.

## Automation Flow

### AUTO-001: Community scope guard
**Given:** Community issue files.
**When:** Static doc review runs.
**Then:** Current-milestone issues do not reference Docker, external media providers, cloud account sync, online subtitle providers, or bundled playlists as acceptance criteria.
**Fixtures:** `.github/issues/community-voice-*.md`.
**Mocks/stubs:** None.
**Assertions:** Non-goals remain explicit.
**Cleanup:** None.

### AUTO-002: Large playlist benchmark
**Given:** Generated M3U fixture with 30,000 entries.
**When:** Rust and package benchmark harnesses run.
**Then:** Parser/index path stays within the issue budget and produces deterministic stats.
**Fixtures:** Generated local playlist fixture.
**Mocks/stubs:** Local file input, no external network.
**Assertions:** Entry count, skipped count, duration, and memory envelope.
**Cleanup:** Remove generated fixture.

### AUTO-003: BYOC search
**Given:** Local playlist, EPG, favorites, and history fixtures.
**When:** User searches for channel, program, and group terms.
**Then:** Results are ranked from local data only.
**Fixtures:** Package-local test records.
**Mocks/stubs:** No external providers.
**Assertions:** Result ordering, timeout behavior, and empty state.
**Cleanup:** Reset local index.

### AUTO-004: TV accessibility
**Given:** TV viewport and D-pad input fixtures.
**When:** Font mode, surf mode, and caption preferences change.
**Then:** Focus remains visible, text fits, channel surfing works, and caption preference persists.
**Fixtures:** Widget tests and fake playback engine.
**Mocks/stubs:** Fake caption tracks and fake channel list.
**Assertions:** Focus traversal, state persistence, and no overflow.
**Cleanup:** Reset preferences.

### AUTO-005: Program guide windowing
**Given:** Local playlist and XMLTV fixtures with thousands of channels and guide programs.
**When:** Guide opens and scrolls by channel and time.
**Then:** Repository returns only requested channel/time windows and UI keeps bounded widget/render counts.
**Fixtures:** Generated playlist and XMLTV fixtures.
**Mocks/stubs:** Fake guide repository and fake clock.
**Assertions:** Window bounds, current-time indicator position, focus traversal, no full-guide load.
**Cleanup:** Reset fake repository.

### AUTO-006: Playback controls
**Given:** Fake playback engine with duration, seekable state, audio tracks, and subtitle tracks.
**When:** User opens controls, seeks, and changes tracks.
**Then:** UI calls the playback engine once per user action and updates selected track/duration state.
**Fixtures:** Fake VOD playback state.
**Mocks/stubs:** Fake playback engine.
**Assertions:** Track selection, seek bounds, duration label, single active session.
**Cleanup:** Dispose fake engine.

### AUTO-007: Smart playlist rules
**Given:** Local playlist fixture with English, non-English, VOD, radio, adult, duplicate, HD, and SD channels.
**When:** Smart playlist rules run.
**Then:** The filtered package contains only matching live channels and preserves canonical aliases for duplicates.
**Fixtures:** Package-local playlist fixture.
**Mocks/stubs:** No network and no model.
**Assertions:** Included/excluded channel ids, alias grouping, empty-state rule summary.
**Cleanup:** Reset local rules.

### AUTO-008: Provider health report
**Given:** Fake source metrics for API latency, playlist fetch, EPG fetch, segment timing, buffer events, and HTTP failures.
**When:** Provider health evaluator runs.
**Then:** It emits a bounded capability report, health score, likely-cause hints, and redacted diagnostics.
**Fixtures:** Fake metric samples.
**Mocks/stubs:** Fake clock and no network.
**Assertions:** Capability flags, health score class, likely cause, redaction.
**Cleanup:** Reset fake metric store.

## Validation Policy

- Prefer host-only package tests, Rust tests, benchmark scripts, and static scans.
- Do not intentionally trigger broad GitHub Actions matrices for these issue slices.
- Android device evidence is release validation, not a reason to block bounded package work.
- Android Emulator use remains opt-in only when the issue explicitly accepts `AIRO_ALLOW_ANDROID_EMULATOR=true`.

## Issue Handling

- Adopted issues should be implemented as small PRs, one bounded contract per PR.
- Deferred issues should remain closed or parked until a future roadmap accepts their product surface.
- CV-011 should not be opened for implementation in v2.
- Each implementation agent must read `AGENTS.md`, `docs/agents/AGENT_POLICY.md`, and the issue file before writing feature code.
