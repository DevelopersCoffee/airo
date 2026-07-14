# Airo TV Volume 5 Gap Analysis

**Source:** `/Users/udaychauhan/.codex/attachments/5c1636f1-d66c-4c5a-8cbb-b515a64bd242/pasted-text.txt`  
**Duplicate source verified:** `/Users/udaychauhan/.codex/attachments/dd85e91a-cb79-4375-8b85-4d1d5308f2a0/pasted-text.txt`  
**Date:** 2026-07-13  
**Scope:** Native media engine, local protocol, data infrastructure,
background workers, performance budgets, and constrained-device architecture.

## Executive Summary

Volume 5 defines the performance architecture Airo TV needs before it can scale
to large IPTV/VOD libraries, low-powered TV devices, local phone-to-TV control,
distributed EPG processing, stream intelligence, and high-bitrate playback. Its
central requirement is a clean split: Flutter owns product experience and
application coordination, while native/background services own video decoding,
probing, large parsing, EPG ingestion, search-index construction, crypto,
network service hosting, and other intensive work.

The current repository has useful foundations: modular Flutter packages,
`video_player`-based IPTV playback, Cast session abstractions, Drift/sqflite
storage, background database creation, a basic M3U parser, offline/sync
abstractions, Cast proxy tests, app-level performance logging, and AI memory
budget logic. It does not yet have a native media engine abstraction, media
probing, large streamed import pipeline, Airo TV media database schema, search
index architecture, Protobuf local protocol, secure WebSocket transport,
distributed EPG worker, resource scheduler, shared Airo media error taxonomy,
benchmark harness, or device-class certification suite.

The biggest product implication is that Airo TV cannot rely on Flutter widgets,
`SharedPreferences`, and `video_player` alone for the Volume 5 goals. The plan
needs a performance foundation track before claiming support for 100,000-item
libraries, high-bitrate constrained-TV playback, or real-time local protocol
sync.

## Current Repository Fit

| Requirement area | Current evidence | Fit |
| --- | --- | --- |
| Flutter UI/application layer | App shells, TV shell, Riverpod feature providers, modular packages | Partial |
| Existing playback | `VideoPlayerStreamingService` uses `video_player`; Cast controller abstractions exist | Partial |
| Native bridge patterns | MethodChannel/EventChannel usage exists for AI, Cast, background sync, device info | Partial |
| Local database foundation | Drift and sqflite dependencies; `NativeDatabase.createInBackground` is used | Partial |
| Offline/sync foundation | `OfflineRepository`, `SyncService`, outbox, sync metrics | Partial |
| Playlist import | `M3UParserService` fetches and parses user M3U playlists | Minimal |
| Playback metrics | `StreamingMetrics`, buffer status, app performance logger | Minimal |
| AI memory budgeting | `MemoryBudgetManager` exists for local model loading | Partial but AI-specific |
| Native media engine | No MPV, FFmpeg, LibVLC, Media3, AVFoundation, or platform media-engine abstraction found | Missing |
| Media probing | No shared probe cache or codec/container/HDR/audio/subtitle inspector found | Missing |
| Protobuf protocol | No Protobuf dependency or Airo protocol schema found | Missing |
| Secure WebSocket transport | No Airo WebSocket protocol dependency or service found | Missing |
| Distributed EPG processing | `platform_epg` is placeholder-level; no worker/snapshot/transfer pipeline found | Missing |
| Media database schema | Existing app DB is finance/meeting/sync oriented, not Airo TV media library oriented | Missing |
| Performance benchmark harness | No representative Airo TV import/search/playback benchmark suite found | Missing |

## Major Gaps

### 1. Native Media Engine Is Missing

Volume 5 requires a `MediaEngine` abstraction that can use native backends such
as MPV, FFmpeg-assisted processing, LibVLC, Android Media3/MediaCodec,
AVFoundation/VideoToolbox, and protected playback where required.

Current state:
- IPTV playback is implemented through `video_player`.
- `IPTVStreamingService` is channel-centric and does not expose the Volume 5
  `MediaEngine` contract.
- Cast support is remote-device control, not a native playback backend.

Gap:
- No `MediaEngine` interface with `open(MediaRequest)`, track selection,
  diagnostics, source replacement, playback rate, and backend-agnostic state.
- No native texture/surface ownership contract.
- No hardware/software decoder fallback policy.
- No backend selection by platform, stream type, codec, DRM/protection, or
  device profile.
- No crash-isolated media process option for desktop/heavy workloads.

Planning impact:
- Volume 5 should reinforce the Volume 3 `PlaybackEngine` item and extend it
  into a native media-engine spike before broader playback claims are made.

### 2. Flutter UI Isolation Is Not Guaranteed

Volume 5 states that no network, database, parsing, AI, or media operation may
block Flutter's UI isolate.

Current state:
- Drift opens the native database in the background.
- The M3U parser loads the full response as a string and splits it into lines.
- Search/filter behavior is largely provider/UI-side for IPTV lists.
- There is no Airo TV job queue or worker-isolate contract.

Gap:
- No explicit UI-isolate budget enforcement.
- No import worker pipeline.
- No cancellation contract for parser/indexer/probe jobs.
- No scheduler that pauses work during playback, memory pressure, low power,
  or heavy TV navigation.

Planning impact:
- Large playlist import, EPG ingestion, search indexing, and stream health must
  become worker-managed services before large-library acceptance criteria are
  credible.

### 3. Large Playlist Processing Is Not Scalable Yet

Volume 5 targets 50,000 live channels and 100,000 VOD entries with streamed
parsing, progress, cancellation, batch writes, deduplication, classification,
search indexing, partial usability, and diagnostics.

Current state:
- `M3UParserService.fetchPlaylist()` downloads a full playlist response.
- `parseM3U()` splits the entire content into memory and returns a full list.
- Parsed cache is stored back into `SharedPreferences` as simplified M3U text.

Gap:
- No streamed parser.
- No import state machine.
- No progress/cancellation.
- No partial library availability.
- No batch database writes into a media schema.
- No import diagnostics model.
- No 50k/100k/250k benchmark tests.

Planning impact:
- The existing parser is suitable as a prototype, not as the Volume 5 import
  pipeline.

### 4. Airo TV Media Database Architecture Is Missing

Volume 5 requires indexed stores for media library data, user state, operational
cache, and secure data, with migration, compaction, corruption detection,
pagination, streaming results, export/restore, and benchmark-based DB choice.

Current state:
- The app has Drift tables for finance, meeting, sync, and outbox data.
- `core_data` has sqflite and secure-storage abstractions.
- There is no dedicated Airo TV media-library schema for channels, movies,
  series, episodes, sources, playlists, categories, EPG mappings, stream health,
  probe results, or search indexes.

Gap:
- No media database schema.
- No FTS/token index strategy.
- No media migration plan.
- No operational cache separation for images, stream health, probe results, and
  failed request history.
- No representative DB benchmark harness.

Planning impact:
- Volume 2 universal media models need a storage design and benchmark suite
  before implementation.

### 5. Search Architecture Is Still UI/List-Oriented

Volume 5 requires exact, prefix, token, normalized, alias, fuzzy, semantic, and
history-ranked search across large datasets with sub-500ms targets.

Current state:
- IPTV providers expose search query state and filter channel lists.
- Edge intelligence can resolve some IPTV intents.
- There is no shared media search index package.

Gap:
- No indexed search service for 100k+ items.
- No normalized title/alias/provider/team/actor/language/country index.
- No incremental result streaming.
- No search benchmark fixture.
- No local privacy controls for history-based ranking.

Planning impact:
- Search should be split from UI state and treated as a background-indexed
  service.

### 6. Local Discovery And Protocol Are Not Implemented

Volume 5 overlaps Volume 3 by requiring local discovery, secure WebSockets, and
versioned binary protocol schemas.

Current state:
- Cast discovery/session code exists.
- iOS Info.plist has Bonjour service entries for Cast-related local networking.
- No Airo-specific mDNS/DNS-SD, WebSocket, or Protobuf package was found.

Gap:
- No Airo service advertisement schema.
- No secure WebSocket transport.
- No Protobuf envelope, playback command, playback state, health update, EPG
  sync, acknowledgement, or compatibility tests.
- No sequence numbers, replay protection, schema-version test suite, or
  generated code sharing across Flutter/native/desktop.

Planning impact:
- The Phase 1A connected-device protocol should explicitly include binary schema
  generation and compatibility tests, not only JSON-style command envelopes.

### 7. Real-Time State Synchronization Is Missing

Volume 5 requires event-based and periodic playback state updates with targets:
play/pause under 150ms, seek/track changes under 250ms, timeline drift under
500ms, and LAN recovery under 3 seconds.

Current state:
- In-process streams exist for player and Cast state.
- Volume 4 planning added route health events.

Gap:
- No cross-device state sync protocol.
- No authoritative playback clock model.
- No drift projection/correction algorithm.
- No reconnection/resume replay behavior.
- No performance tests for local command/state latency.

Planning impact:
- State sync should be measured as part of the local protocol, not handled as a
  UI polling problem.

### 8. Distributed EPG Processing Is Missing

Volume 5 requires capable nodes to download, decompress, parse, normalize,
compact, and transfer EPG snapshots or incremental updates to constrained TVs.

Current state:
- `platform_epg` is not a real EPG processing platform yet.
- Prior plans include compact EPG but not a distributed worker pipeline.

Gap:
- No EPG role model: downloader, parser, compressor, cache host, consumer.
- No compact binary snapshot format.
- No incremental EPG transfer protocol.
- No integrity validation or schema compatibility checks.
- No TV-side bounded query cache.

Planning impact:
- Compact EPG MVP should remain current/next only until the distributed EPG
  architecture is designed and benchmarked.

### 9. Stream Intelligence Is Not Worker-Managed

Volume 5 defines smart link pruning, health states, backup-source ranking,
predictive warm-up, and failover integration.

Current state:
- Playback has basic metrics and live-edge handling.
- Volume 2/4 plans mention health and route ranking.

Gap:
- No stream health score model.
- No cooldown and failure classification policy.
- No privacy-safe diagnostics for provider credentials and signed URLs.
- No predictive warm-up scheduler.
- No provider-rule checks to avoid consuming short-lived URLs.

Planning impact:
- Stream intelligence should be a background job class with strict resource and
  privacy gates.

### 10. Background Job Scheduler Is Too Generic

Volume 5 defines job types and resource arbitration for playlist refresh, EPG
refresh, metadata enrichment, stream health, search indexing, DB compaction,
cache cleanup, model download, device sync, and recording prep.

Current state:
- `BackgroundSyncService` wraps platform background sync via MethodChannel.
- It is sync-oriented and has basic interval/network/charging options.

Gap:
- No unified Airo TV scheduler.
- No priority classes for active playback recovery, pairing security, import,
  EPG, health checks, warm-up, or cache cleanup.
- No resource arbitration with player buffering, memory pressure, overheating,
  multi-view, heavy navigation, recording, or poor network.

Planning impact:
- Background sync should not be stretched into the media job scheduler. A
  dedicated scheduler contract is needed.

### 11. Memory And Storage Budgets Are Not Media-Wide

Volume 5 requires explicit budgets for Flutter heap, native media heap, image
cache, database cache, EPG cache, video buffers, protocol buffers, and
background tasks.

Current state:
- `core_ai` has an AI-specific `MemoryBudgetManager`.
- The app has model storage usage views.
- No media-wide memory profile or low-memory mode contract was found.

Gap:
- No TV class memory budgets.
- No low-memory mode for playback/UI/EPG/import/cache as a coordinated state.
- No storage usage categories for playlist DB, EPG cache, images, subtitles,
  recordings, downloads, diagnostics, temporary files.
- No policy for evicting operational caches before user data.

Planning impact:
- Device capability work needs resource budgets for media, not only AI.

### 12. Shared Error And Observability Model Is Incomplete

Volume 5 requires a shared `AiroError` taxonomy with category, severity,
retryability, user message key, source/session context, and redaction rules.

Current state:
- `core_domain` has generic failure types.
- Cast has its own error codes.
- Playback uses error strings in `StreamingState`.
- App logger has a generic performance log method and buffered logs.

Gap:
- No shared media/platform error taxonomy.
- No redaction-enforced diagnostics for signed URLs, credentials, voice
  content, local IPs, or viewing history.
- No local-only diagnostics export contract for Airo TV.
- No performance metric schema for frame timing, query latency, import speed,
  protocol RTT, player startup, rebuffering, failover, memory, and decoder
  fallback.

Planning impact:
- Observability must be privacy-safe and typed before analytics/telemetry work
  consumes these events.

### 13. Benchmark Device Classes And Tests Are Missing

Volume 5 requires benchmark classes for constrained TV, standard TV, mobile,
and desktop, plus performance, protocol, and media test suites.

Current state:
- Some widget and unit tests exist around IPTV/Cast/live-edge behavior.
- No Airo TV benchmark harness for large import/search/playback/protocol
  workloads was found.

Gap:
- No 10k/50k/100k/250k playlist benchmarks.
- No "scroll while import runs" test.
- No EPG refresh during playback test.
- No phone remote during 4K playback test.
- No protocol compatibility/replay/oversized payload suite.
- No media matrix for HLS/DASH/MPEG-TS/MP4/MKV/H.264/HEVC/AV1/subtitles/HDR.

Planning impact:
- Certification cannot be asserted until benchmark fixtures and device-class
  pass/fail gates exist.

## Required Plan Changes

| Priority | Plan addition | Reason |
| --- | --- | --- |
| P0 | Native media engine spike | Validates backend, texture/surface, diagnostics, and decoder fallback strategy |
| P0 | Media database benchmark harness | Prevents premature DB choice for large media libraries |
| P0 | Large playlist worker pipeline | Required for 50k/100k library imports without UI stalls |
| P0 | Shared Airo media error taxonomy | Required for user-safe errors, retries, diagnostics, and analytics |
| P0 | Performance instrumentation schema | Required before claiming frame, playback, search, import, and protocol targets |
| P1 | Protobuf local protocol schema | Required for high-frequency local state and command sync |
| P1 | Secure WebSocket transport | Required for paired device state and control |
| P1 | Distributed EPG worker contract | Required before large EPG support on constrained TVs |
| P1 | Resource scheduler | Required for background work to respect playback, memory, battery, and thermal state |
| P1 | Device-class benchmark matrix | Required for constrained TV certification |

## Recommended Scope Adjustment

1. Keep Volume 5 implementation out of a UI-first MVP until the foundation
   spikes are complete.
2. Treat the current `video_player` service as an adapter candidate, not the
   native media-engine abstraction.
3. Treat the current M3U parser as a prototype, not the scalable import
   pipeline.
4. Select media storage through representative benchmarks, not by reusing the
   existing app database by default.
5. Make performance budgets measurable before accepting the Volume 5 production
   readiness criteria.

## Acceptance Gaps To Add

- A 100,000-item import can run without sustained UI frame degradation.
- Media parsing emits progress, supports cancellation, and commits batches.
- Search over 100,000 media items responds under the agreed target on supported
  devices.
- Playback does not pass decoded frames through Dart memory.
- Media diagnostics redact signed URLs, credentials, local addresses where
  practical, and viewing history.
- Protocol schemas reject replay attempts, oversized payloads, invalid tokens,
  and incompatible schema versions.
- A constrained TV profile can release optional caches and AI models while
  preserving active playback.
- EPG current/next can show before full EPG processing completes.
- Background health checks pause when playback buffers or the device enters
  memory/thermal pressure.
- Benchmarks run against Class A, B, C, and D device definitions.

## Final Assessment

Volume 5 is the architecture that determines whether Airo TV can scale beyond a
small IPTV demo. The current codebase has enough modular shape to host the work,
but the performance-critical systems are not yet in place. The next planning
step should be to define native media, media storage, import workers, protocol
schemas, resource scheduling, and benchmark gates as platform contracts before
large-library or constrained-device promises move into implementation.
