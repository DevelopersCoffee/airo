# Airo TV Volume 2 Gap Analysis

**Status:** Draft  
**Date:** 2026-07-13  
**Source PRD:** `/Users/udaychauhan/.codex/attachments/c2e15728-f98a-401b-8aa3-8527e94362d0/pasted-text.txt`  
**Volume:** Media Platform, Smart Infrastructure and AI Experience  
**Review method:** Static repository review plus comparison against existing Airo TV planning docs. No code tests were run.

## Executive Summary

Volume 2 changes Airo TV from an IPTV app into a universal personal media
platform. The current repository is not at that architecture yet.

Current strengths:

- `packages/feature_iptv` provides IPTV screens, providers, TV UI, search,
  playback wiring, and Cast integration.
- `packages/platform_playlist_import` has M3U import, parsing, deduplication,
  and local cache.
- `packages/platform_channels` has an `IPTVChannel` model with category,
  language, quality URL, header, source, and alternate-name fields.
- `packages/platform_media` and `packages/platform_player` provide playback
  and Cast abstractions.
- `packages/platform_streams` has a live-edge detector that can support live vs
  VOD detection and DVR-window reasoning.
- `app/lib/features/media_hub` has an early `UnifiedMediaContent` model for
  music and IPTV.
- `core_data` already depends on `flutter_secure_storage`, which can be reused
  for source credential storage.

Main gap:

Airo does not yet have a source-agnostic platform model. Most production code is
still shaped around `IPTVChannel`, M3U playlists, and TV/music discovery. Volume
2 requires a shared `MediaItem` and `MediaSource` platform with source adapters,
metadata enrichment, search, health, EPG, recording, and offline cache across
IPTV, VOD, personal files, media servers, browser casting, FAST channels, and
security cameras.

Recommendation:

Do not start Volume 2 by adding Plex, SMB, cameras, or AI metadata repair
directly into `feature_iptv`. First create the universal media contracts in a
platform package, then migrate IPTV into those contracts as the first adapter.

## Severity Legend

| Level | Meaning | Release impact |
| --- | --- | --- |
| P0 | Blocks source-agnostic media platform work | Must resolve before claiming Volume 2 foundation |
| P1 | Required for a useful first universal media release | Can follow P0 contracts |
| P2 | Premium or expansion feature | Defer until platform contracts and MVP sources work |

## Current Coverage Snapshot

| Volume 2 area | Current state | Evidence | Gap |
| --- | --- | --- | --- |
| Universal media abstraction | Partial and app-local | `app/lib/features/media_hub/domain/models/unified_media_content.dart` maps music and IPTV only | No platform-level `MediaItem`, `MediaSource`, `MediaAsset`, or capability contract |
| IPTV sources | Partial | M3U import exists in `platform_playlist_import`; M3U8 playback can flow through stream URLs | Xtream missing; Stalker future; no source adapter interface |
| VOD | Partial playback only | Player has seek methods; `UnifiedMediaContent` has duration and resume fields | No movie/series/episode model, poster metadata, collections, or episode resume store |
| Catch-up TV | Very early | `platform_streams` has live-edge and DVR-window detection | No timeshift/replay/start-over source contract or archived program model |
| FAST channels | Missing | No provider adapters found for Pluto, Samsung TV Plus, Tubi, Plex TV, Roku Channel | Need legal/public-source registry and separate categorization |
| Personal media | Missing | App has file-picker dependency, but no media indexing package | No NAS/SMB/NFS/FTP/WebDAV/DLNA/USB indexing, metadata, subtitles, or folder monitoring |
| Media servers | Missing | No Plex/Jellyfin/Emby adapter code found | Auth, multiple servers, metadata sync, and search absent |
| Browser casting | Partial Cast sender | Cast sender and HTTP proxy exist | No inbound URL/share receiver via QR, clipboard, AirDrop, Nearby Share |
| Security cameras | Missing | No RTSP/RTMP/MJPEG/ONVIF media source found | Camera dashboard, PIP, motion hooks, and recording absent |
| Smart library | Partial | Media Hub discovery combines music and TV into card/grid UI | No cross-source taxonomy or deduped library sections |
| Metadata intelligence | Missing | Some Cast metadata and IPTV category inference exist | No metadata provider chain, AI repair, user approval, undo, or version history |
| Smart import wizard | Partial basics | Playlist source sheet exists; app has OCR/image dependencies | No QR secure-token flow, source detection, validation pipeline, OCR assistant, or provider-specific wizard |
| Health monitoring | Missing | No stream health score service found | No response/codec/bitrate/packet-loss probing or health history |
| Auto failover | Missing | Cast adapter rejects unsupported streams; player retry exists | No backup-source ranking or silent switch under 2 seconds |
| Stream ranking | Missing | IPTV model supports `qualityUrls` and `sources` | No ranking engine by health, latency, bitrate, language, region, or user history |
| Network diagnostics | Missing | Player error UI exists | No error classifier for DNS, provider overload, expired playlist, auth, geo-block, or audio failure |
| Sports intelligence | Missing | Basic sports category exists | No teams, leagues, schedules, match finder, commentary preference, or sports dashboard |
| EPG intelligence | Missing/stub | `platform_epg` currently contains only a template calculator | No timezone repair, duplicate program merge, category/image/episode repair |
| Smart recording | Missing | Meeting recording exists elsewhere, not media recording | No TV recording, conflict resolution, storage prediction, or series/team rules |
| Search everywhere | Partial local search | IPTV and Media Hub search title/subtitle/tags | No universal search index across sources or semantic/voice/image dimensions |
| Cross-source discovery | Missing | No cross-source identity model | No "one movie across NAS/Plex/playlist/USB" merge |
| Continue watching | Partial | Recently watched IPTV and Media Hub personalization exist | No cross-source progress model or cloud sync |
| Offline metadata cache | Missing | Playlist cache and recent history exist | No poster/description/genre/collection/EPG/embedding cache policy |
| AI error recovery | Missing | Basic errors only | No recovery advisor or automated fix suggestions |

## P0 Gaps

### GAP-V2-001: No Platform-Level Media Item Model

**Requirement:** Every source becomes a media item with metadata, categories,
recommendations, and playback.

**Current state:** `UnifiedMediaContent` exists in the app layer and only maps
music tracks plus IPTV channels. It stores a direct `streamUrl`, which is not
safe or flexible enough for provider-backed sources, secure tickets, local file
permissions, or media servers.

**Impact:** Universal search, cross-source merge, source-agnostic playback,
metadata enrichment, and recommendations cannot be implemented cleanly.

**Required work:**
- Create a framework-owned media model package, likely `core_media_models` or
  `platform_media_catalog`.
- Define `MediaItem`, `MediaSourceRef`, `MediaVariant`, `MediaMetadata`,
  `PlaybackRef`, `MediaCollection`, and `MediaProgress`.
- Keep raw URLs and credentials out of general UI models.
- Add migration adapters from `IPTVChannel` and music tracks.

**Owner:** Framework Agent with Media Agent review.

### GAP-V2-002: No Source Adapter Contract

**Requirement:** IPTV, VOD, personal media, media servers, browser casting, FAST,
and security cameras should plug into the same media abstraction layer.

**Current state:** Source handling is hardcoded around M3U/IPTV providers and
app-specific Media Hub providers.

**Impact:** Adding Plex, SMB, FAST, or cameras directly would create separate
parallel stacks and duplicate search/playback logic.

**Required work:**
- Define `MediaSourceAdapter` with capabilities: authenticate, validate,
  scan/index, search, resolve playback, refresh metadata, health check, revoke.
- Define source capability flags: live, vod, catchUp, files, camera, recording,
  subtitles, multipleVariants, remoteMetadata, localIndexing.
- Require each adapter to declare permissions, credential type, cache policy,
  and privacy classification.

**Owner:** Framework Agent and Media Agent.

### GAP-V2-003: Secure Source Credential Model Is Missing

**Requirement:** Source setup includes playlists, media servers, NAS protocols,
browser links, and cameras. These can contain passwords, tokens, local IPs, and
private paths.

**Current state:** Playlist URLs and cached playlist text currently use
SharedPreferences in media packages. `core_data` has `flutter_secure_storage`,
but the media source layer is not using it.

**Impact:** Volume 2 cannot safely add Xtream, Plex/Jellyfin/Emby, SMB/WebDAV,
FTP/SFTP, RTSP cameras, or QR setup until secrets are isolated and redacted.

**Required work:**
- Add `MediaSourceVault` using secure storage for secrets and a separate local
  metadata store for non-secret records.
- Add redaction for URLs, usernames, passwords, tokens, local paths, local IPs,
  and camera names.
- Add trust classes for full devices, Lite receivers, and restricted receivers.

**Owner:** Security and Privacy Agent.

### GAP-V2-004: Metadata Architecture Is Missing

**Requirement:** Generate posters, year, cast, genre, runtime, descriptions,
trailers, similar titles, collections, and repair incorrect metadata with AI,
confidence scoring, user approval, undo, version history, and overrides.

**Current state:** IPTV category inference and logo URL parsing exist. Media Hub
cards can display image/title/subtitle. No metadata provider chain or repair
history exists.

**Impact:** Smart Library, VOD, cross-source merge, AI collections, and search
quality will remain shallow.

**Required work:**
- Define `MetadataProvider` chain: embedded tags, local cache, TMDB/TVDB
  optional adapters, user override, local AI.
- Add metadata provenance, confidence, version history, undo, and manual
  override model.
- Add privacy gate for external metadata lookup; local filenames can reveal
  private interests.

**Owner:** Media Agent with Security and Privacy review.

### GAP-V2-005: Universal Search Index Is Missing

**Requirement:** Search everywhere across IPTV, movies, TV, NAS, Plex, Jellyfin,
USB, cloud, FAST, actor, genre, language, year, team, director, semantic, voice,
and future image search.

**Current state:** IPTV and Media Hub search are in-memory string filters.
Edge intelligence has a narrow IPTV assistant path, but not a general search
contract.

**Impact:** Airo cannot deliver the "one app for every media source" promise.

**Required work:**
- Define `MediaSearchProvider` and `MediaSearchIndex`.
- Support profile/product-specific providers: local prefix, local indexed,
  semantic local, companion delegated, cloud optional.
- Define privacy policy for raw query text and indexed metadata.
- Add result ranking and deduping across sources.

**Owner:** AI Agent and Media Agent.

### GAP-V2-006: EPG Package Is A Stub

**Requirement:** EPG intelligence repairs timezone, descriptions, categories,
images, episode numbers, genres, duplicates, and future summaries/previews.

**Current state:** `packages/platform_epg/lib/platform_epg.dart` contains only a
template `Calculator`.

**Impact:** Catch-up TV, sports schedule, smart recording, current/next guide,
and legacy compact EPG cannot be built from the existing package.

**Required work:**
- Replace stub with EPG domain models: `EpgProgram`, `EpgChannelMap`,
  `EpgSource`, `EpgWindow`, `EpgRepairSuggestion`.
- Add compact and full EPG repositories.
- Add timezone normalization, duplicate handling, source provenance, and repair
  confidence.

**Owner:** Media Agent.

### GAP-V2-007: Health Monitoring And Failover Are Missing

**Requirement:** Monitor response time, availability, resolution, codec, audio,
subtitles, latency, packet loss, bitrate, reconnect frequency, health score,
and switch backup streams with under 2 seconds interruption.

**Current state:** Player state has buffer/network concepts and `platform_streams`
has live-edge detection. There is no health score, stream probe scheduler,
backup-source registry, or failover router.

**Impact:** Volume 2's "automatic repair of unreliable playlists" is not
deliverable.

**Required work:**
- Add `StreamHealthService`, `HealthScore`, `StreamProbe`, and `FailoverPolicy`.
- Store health locally per user source, not globally.
- Integrate health with playback startup and mid-stream recovery.
- Add bounded background probing to avoid battery/network abuse.

**Owner:** Media Agent with QA Automation review.

### GAP-V2-008: Smart Import Wizard Is Not Built

**Requirement:** QR, clipboard, file, cloud, AirDrop, Nearby Share, URL, manual,
camera OCR, source detection, validation, logos, EPG fetch, playlist repair,
and under 20 second QR setup.

**Current state:** Basic playlist URL entry exists. App dependencies include
file picker, image picker, and ML Kit OCR, but there is no media-source wizard
or secure-token QR flow.

**Impact:** The "zero technical knowledge" setup promise remains unfulfilled.

**Required work:**
- Define `SourceImportSession`, `ImportMethod`, `SourceDetector`,
  `ValidationResult`, and `RepairPlan`.
- Add QR secure-token flow through a trusted companion, not raw credentials in
  the QR payload.
- Add OCR/email/PDF input as later adapters after credential redaction exists.

**Owner:** Media Agent and Security and Privacy Agent.

## P1 Gaps

### GAP-V2-009: VOD And Series Domain Model Missing

**Requirement:** Movies, TV shows, anime, documentaries, kids libraries,
posters, collections, continue watching, episode resume, and watch history.

**Current state:** Player can seek and Media Hub can represent duration and
resume position, but there is no movie/series/episode schema.

**Required work:**
- Add `Movie`, `Series`, `Season`, `Episode`, `LibrarySection`, and
  `WatchProgress`.
- Add source adapter mappings from files, Plex/Jellyfin/Emby, and playlists.

### GAP-V2-010: Personal Media Indexing Missing

**Requirement:** NAS, SMB, NFS, FTP, WebDAV, DLNA, USB, external drives,
automatic indexing, poster scraping, metadata generation, subtitle detection,
and folder monitoring.

**Current state:** No file/NAS indexer or protocol adapters found.

**Required work:**
- Add local file and removable-storage adapter first.
- Defer SMB/NFS/WebDAV/DLNA until credential vault and platform permissions are
  settled.
- Add subtitle scanner and file fingerprinting.

### GAP-V2-011: Media Server Integrations Missing

**Requirement:** Plex, Jellyfin, Emby with auth, multiple servers, offline sync
metadata, and unified search.

**Current state:** No server adapters found.

**Required work:**
- Start with Jellyfin or Plex only after source adapter contract is ready.
- Implement server auth, library scan, metadata sync, and playback resolution
  through `MediaSourceAdapter`.

### GAP-V2-012: Browser Casting Is Only Outbound Cast Today

**Requirement:** Accept URLs, HLS, DASH, MP4, browser share through QR,
clipboard, AirDrop, and Nearby Share.

**Current state:** Cast sender and local HTTP proxy exist. There is no inbound
share or browser-cast receiving flow.

**Required work:**
- Define inbound `SharedMediaIntent` and validation.
- Add QR/clipboard URL receiver.
- Add platform-specific share extensions later.

### GAP-V2-013: Continue Watching Is Not Cross-Source

**Requirement:** Track live TV, movies, series, local files, NAS, Plex, every
source, resume position, and cloud sync.

**Current state:** Recently watched IPTV and app-level Media Hub personalization
exist, mostly local and source-specific.

**Required work:**
- Move watch progress to the universal media model.
- Use source-stable IDs and fallback fingerprints.
- Add profile scope and optional encrypted cloud sync.

### GAP-V2-014: Network Diagnostics Are Not Classified

**Requirement:** Explain internet stable, provider overloaded, DNS issue,
playlist expired, authentication failed, geo-blocked, audio unavailable, and
suggest fixes.

**Current state:** Errors are mostly player/provider exceptions and UI messages.

**Required work:**
- Add error taxonomy and classifier.
- Map low-level Dio/player/decoder errors into user-facing recovery actions.
- Keep advanced diagnostics behind Advanced Mode.

### GAP-V2-015: Offline Metadata Cache Missing

**Requirement:** Cache posters, descriptions, genres, collections, EPG, voice
embeddings, and recommendations for fast startup and offline browsing.

**Current state:** Playlist cache and recent history exist. No general media
metadata cache policy exists.

**Required work:**
- Define cache budgets by product profile.
- Add eviction policy, offline mode, and privacy deletion path.
- Keep embeddings local unless explicit sync is enabled.

## P2 Gaps

| Area | Why defer |
| --- | --- |
| FAST public service integrations | Need legal/public-source policy and provider-specific terms review |
| Security cameras | Needs sensitive-data privacy model, ONVIF/RTSP stack, local network permissions, recording policy |
| Smart recording | Requires storage budget, rights policy, background execution, conflict resolution, and device certification |
| Sports intelligence | Needs sports entity model, schedule source, EPG matching, favorite teams, commentary metadata |
| AI collections | Requires metadata model, local recommendation signals, and privacy-safe AI routing |
| Cross-source automatic best-quality choice | Needs variants, health, codec/device capability, and user preference model |
| AI configuration assistant | Needs OCR/email/PDF ingestion plus secret redaction and user confirmation |
| AI error recovery | Needs stable error taxonomy and safe action model first |

## Volume 2 Requirement Matrix

| PRD section | Status | Main missing contract |
| --- | --- | --- |
| Universal Media Platform | Partial | Platform-level `MediaItem` and `MediaSourceAdapter` |
| IPTV | Partial | Xtream/Stalker and secure source vault |
| VOD | Missing | Movie/series/episode schema |
| Catch-up TV | Early | Timeshift/replay/start-over model |
| FAST Channels | Missing | Legal source registry and FAST adapter |
| Personal Media | Missing | File/NAS indexer and protocol adapters |
| Media Servers | Missing | Plex/Jellyfin/Emby adapters |
| Browser Casting | Partial | Inbound share/QR/clipboard receiver |
| Security Cameras | Missing | Camera source adapter and privacy policy |
| Smart Library | Partial | Cross-source taxonomy and library builder |
| Metadata Intelligence | Missing | Metadata provider chain and provenance |
| AI Metadata Repair | Missing | Repair suggestions, confidence, undo/version history |
| Smart Import Wizard | Partial | Source detector and import session model |
| QR Setup Flow | Missing | Secure companion token flow |
| AI Configuration Assistant | Missing | OCR/PDF/email parser with secret handling |
| Health Monitoring Engine | Missing | Stream health score and probe scheduler |
| Smart Auto Failover | Missing | Backup source registry and failover router |
| Stream Ranking Engine | Missing | Ranking policy and quality metrics |
| Smart Buffer Prevention | Missing | Network estimate and adaptive source selection |
| Network Diagnostics | Missing | Error taxonomy and recovery guidance |
| Sports Intelligence Layer | Missing | Sports entities, schedules, match finder |
| EPG Intelligence | Missing | Real EPG package implementation |
| Smart Recording | Missing | Recording rules and storage conflict model |
| Search Everywhere | Partial | Universal search index |
| Cross Source Discovery | Missing | Cross-source identity and merge |
| Multi-source Merge | Missing | Variant grouping and user choice |
| AI Collections | Missing | Collection generator and local signal model |
| Continue Watching Engine | Partial | Cross-source progress and sync |
| Offline Metadata Cache | Missing | Metadata cache and eviction policy |
| AI Error Recovery | Missing | Actionable recovery classifier |

## Recommended Build Order

### Phase 1: Universal Media Foundation

- Add platform media catalog package.
- Define `MediaItem`, `MediaSourceRef`, `MediaVariant`, `PlaybackRef`,
  `MediaMetadata`, `MediaCollection`, and `MediaProgress`.
- Define `MediaSourceAdapter` and source capability declarations.
- Migrate IPTV into this model as the first adapter.

### Phase 2: Safe Source Import

- Add encrypted source vault.
- Add source import session model.
- Add QR setup contract with secure short-lived tokens.
- Add validation and redaction tests.

### Phase 3: Metadata and Search

- Add metadata provider chain with provenance and user overrides.
- Add universal search provider and index.
- Add cross-source identity and merge rules.
- Add offline metadata cache budgets.

### Phase 4: Playback Reliability

- Add stream health engine.
- Add backup-source ranking.
- Add auto-failover policy.
- Add network diagnostic classifier.
- Add performance telemetry once analytics abstraction exists.

### Phase 5: Source Expansion

- Add Xtream if not already done.
- Add one VOD source path.
- Add one media server, preferably Jellyfin or Plex.
- Add local file indexing before NAS protocols.
- Defer cameras, recording, FAST, and sports intelligence until foundations are
  stable.

## Immediate Backlog

| ID | Priority | Backlog item | Owner |
| --- | --- | --- | --- |
| V2G-001 | P0 | Create universal media model package | Framework Agent |
| V2G-002 | P0 | Define media source adapter contract | Framework Agent |
| V2G-003 | P0 | Design media source vault and redaction policy | Security and Privacy Agent |
| V2G-004 | P0 | Replace app-local `UnifiedMediaContent` dependency with adapter-friendly model plan | Media Agent |
| V2G-005 | P0 | Replace `platform_epg` stub with real EPG domain spec | Media Agent |
| V2G-006 | P0 | Define smart import session and QR token flow | Media Agent |
| V2G-007 | P1 | Define metadata provider chain and override/version model | Media Agent |
| V2G-008 | P1 | Define universal search index and query privacy policy | AI Agent |
| V2G-009 | P1 | Define stream health and failover engine | Media Agent |
| V2G-010 | P1 | Define cross-source watch progress model | Media Agent |
| V2G-011 | P2 | Evaluate first media server adapter | Media Agent |
| V2G-012 | P2 | Evaluate FAST, cameras, and recording after legal/security review | Security and Privacy Agent |

## Go/No-Go Assessment

**Go for:** universal media contracts, source adapter design, secure source
vault, IPTV adapter migration, real EPG domain modeling, smart import session
design, metadata provider architecture, and search index design.

**No-go for now:** claiming a Universal AI Media OS, adding many provider
integrations directly, security cameras, smart recording, AI metadata repair,
AI sports intelligence, full FAST support, or cross-source automatic best-quality
selection.

Volume 2 is directionally strong, but it needs a platform foundation before it
can become implementation. The first engineering milestone should make IPTV one
source adapter inside a universal media model; every later source should reuse
that same contract.

