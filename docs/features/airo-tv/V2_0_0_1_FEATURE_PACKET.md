# Airo TV v2.0.0.1 Feature Packet

**Primary owner agent:** Media Agent  
**Review agents:** Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent, Mobile UI Agent, AI Agent  
**Layer:** Mixed  
**Sprint:** V2 Airo TV planning and foundation  
**Parent roadmap:** V2 modular media platform  

## Critical Agent Gate

**Problem:** Airo TV requirements currently combine a full AI media platform,
legacy Android support, modular product profiles, and analytics governance. The
team needs an implementation-ready v2 scope that preserves BYOC compliance,
privacy, playback reliability, and modular boundaries.

**User / actor:** BYOC media user on Android TV, Fire TV, mobile companion,
desktop companion, or constrained receiver hardware.

**Framework or application layer:** Mixed. Product profiles, capabilities,
protocols, analytics contracts, security boundaries, and build composition are
framework-level. TV home, content browsing, playback UX, empty states, and
profile-specific copy are application-level.

**Owning agent:** Media Agent.

**Reviewing agents:** Framework Agent for capability and protocol contracts;
Security and Privacy Agent for credential, analytics, local-network, cloud, and
legacy-device trust boundaries; QA Automation Agent for deterministic flows and
certification; Release and DevEx Agent for V2 branch, app profiles, target SDK,
ABI splits, and store distribution; Mobile UI Agent for TV focus and profile
specific UX; AI Agent for delegated AI/search interfaces.

**Impacted modules/files:** `packages/feature_iptv`,
`packages/platform_player`, `packages/platform_playlist`,
`packages/platform_playlist_import`, `packages/platform_epg`,
`packages/platform_favorites`, `packages/platform_history`,
`packages/platform_media`, `packages/core_ai`, `packages/core_ui`,
future `core_protocol`, future `product_capabilities`, future
`feature_analytics`, app TV entrypoints, Android build profiles, docs under
`docs/features/airo-tv`.

**Base branch/worktree:** confirmed from latest `origin/v2`: yes. `git fetch
origin main v2` completed on 2026-07-14. Current branch
`codex/next-v2.0.0.0` is based on `origin/v2` at `5fef3498`.

**Open questions:** App listing strategy, first physical legacy test devices,
billing provider, and compliance review for Stalker Portal, recording,
timeshift, and provider-specific integrations.

**Decision:** Ready for issue-scoped implementation after the derivative issue
packet is present. `v2.0.0.1` remains a planning milestone label; public release
tags remain semantic v2 tags from the release-line policy.

## Cross-Agent Contract

**Provider agent:** Framework Agent.

**Consumer agent:** Media Agent, Mobile UI Agent, AI Agent, QA Automation Agent,
Release and DevEx Agent.

**Interface/API:** Product profile declaration, device capability contract,
playback session contract, pairing/handoff contract, analytics event contract,
and delegated operation contract.

**Input shape:**
- user-provided content source reference;
- device profile scan;
- controller capabilities;
- playback request;
- optional compact remote view request;
- typed analytics event.

**Output shape:**
- profile-specific navigation and feature availability;
- direct playback session or restricted playback ticket;
- compact EPG/search/favorites/recent view;
- redacted analytics event or no-op decision;
- fallback error with actionable user message.

**State changes:**
- local content-source metadata and encrypted credentials where permitted;
- favorites, recent items, playback progress, profile settings;
- paired-device trust records;
- compact EPG cache;
- bounded analytics queue when consent permits;
- device capability profile.

**Errors:**
- unsupported codec;
- companion unavailable;
- source unreachable;
- decoder failure;
- low memory;
- low storage;
- permission denied;
- trust level insufficient;
- analytics disabled;
- protocol version mismatch.

**Permissions:**
- request only permissions required by the selected product profile;
- receiver-only builds must not request microphone, camera, broad file access,
  recording, or media library permissions unless those modules are included.

**Privacy/redaction:**
- never collect or upload stream URLs, signed URLs, M3U URLs, Xtream
  credentials, provider usernames/passwords, authentication headers, cookies,
  local network addresses, local file paths, raw voice recordings, voice
  transcripts, raw search text, private playlist contents, or full viewing
  history by default.

**Persistence:**
- local-first for credentials, favorites, recent, compact EPG, playback
  progress, capability profile, and diagnostics;
- cloud sync is optional and requires encrypted sync and consent contracts.

**Versioning/migration:**
- protocol fields must be forward compatible with unknown fields ignored;
- profile capabilities must include schema version;
- `v2.0.0.1` is a planning milestone label, not a public Git release tag;
- public builds must be tagged from `v2` with repository V2 semver tags such as
  `v2.0.0`, `v2.0.1`, and `v2.1.0`.

**Tests required:**
- profile composition tests;
- capability negotiation tests;
- BYOC no-bundled-content tests;
- D-pad and focus tests;
- playback fallback tests;
- analytics redaction and consent tests;
- legacy certification smoke tests;
- build-profile dependency and permission scans.

## Deterministic Use Cases

### UC-001: BYOC first launch

**Actor:** First-time Airo TV user.

**Preconditions:** No content source configured.

**Trigger:** User opens Airo TV Lite or Full TV profile.

**Happy path:** App shows a BYOC setup state and does not display bundled
channels, playlists, or provider recommendations.

**Alternate paths:** User can pair a companion device or add a supported
playlist URL.

**Failure paths:** Invalid source is rejected with a local error; no fallback
first-party content is fetched.

**Data created/updated/deleted:** None until user adds a source or pairs a
device.

**Privacy expectations:** No media source is inferred or uploaded.

### UC-002: Lite Receiver handoff

**Actor:** User with a phone companion and an old Android TV.

**Preconditions:** TV is paired and classified as Lite Receiver.

**Trigger:** User selects content on phone and sends it to TV.

**Happy path:** Phone prepares a compatible playback ticket; TV validates
capabilities, starts direct playback, and continues after the phone disconnects.

**Alternate paths:** If source codec is incompatible, controller chooses an
alternate source or explains the limitation.

**Failure paths:** If TV trust is restricted, it receives only a short-lived
ticket and never receives full provider credentials.

**Data created/updated/deleted:** Playback session, recent item, progress, and
optional redacted handoff event.

**Privacy expectations:** No raw stream URL appears in analytics or crash logs.

### UC-003: Legacy device capability profile

**Actor:** Android 8/9 TV user.

**Preconditions:** App launches on a low-memory TV device.

**Trigger:** First launch capability scan completes.

**Happy path:** App classifies device by capability, applies Lite Receiver mode,
hides unavailable features, limits artwork, and disables heavy background work.

**Alternate paths:** User can view diagnostics or choose stricter low-memory
settings.

**Failure paths:** If security or playback requirements fail, device is marked
Compatible, Experimental, or Unsupported rather than Certified.

**Data created/updated/deleted:** Local device capability profile.

**Privacy expectations:** No unique hardware fingerprint is uploaded.

### UC-004: Compact EPG on Lite Receiver

**Actor:** Lite Receiver user browsing live TV.

**Preconditions:** User has an authorized playlist and optional EPG source.

**Trigger:** User opens Guide or Live.

**Happy path:** TV displays current and next program data for favorites,
recent, or visible channels without loading full XMLTV into memory.

**Alternate paths:** Companion or home node can supply compact EPG slices.

**Failure paths:** If EPG is unavailable, TV still displays playable channel
cards with basic metadata.

**Data created/updated/deleted:** Compact EPG cache and last refresh timestamp.

**Privacy expectations:** Full EPG source URL is not uploaded to analytics.

### UC-005: Analytics disabled mode

**Actor:** Privacy-conscious user.

**Preconditions:** App has optional analytics available.

**Trigger:** User disables product analytics or enters local-only mode.

**Happy path:** Optional event collection stops immediately, queued optional
events are deleted, playback continues normally, and provider failure is
isolated.

**Alternate paths:** Required operational data for security or subscription may
continue under separate policy.

**Failure paths:** If analytics adapter throws, the app falls back to no-op and
does not affect playback.

**Data created/updated/deleted:** Optional analytics queue deleted; local
diagnostics retained only if permitted.

**Privacy expectations:** Consent is enforced technically, not only in UI.

### UC-006: Unsupported premium feature hidden

**Actor:** User on Lite Receiver.

**Preconditions:** Device has one decoder, no AI runtime, and low memory.

**Trigger:** App renders navigation and settings.

**Happy path:** Multi-view, on-device AI, recording, downloads, and rich
previews are absent. Equivalent delegated or explanatory alternatives appear
where useful.

**Alternate paths:** If a companion is available, search or AI entry points may
route to companion processing.

**Failure paths:** Runtime flags cannot expose modules absent from the build.

**Data created/updated/deleted:** None.

**Privacy expectations:** Feature visibility does not leak user media data.

## Automation Flow

### AUTO-001: BYOC packaged-content scan

**Given:** V2 TV application package and IPTV/media packages.

**When:** Host-only static scan runs.

**Then:** No first-party playlist assets, channel lists, provider URLs, or
reviewer-specific content fallbacks are present.

**Fixtures:** Repository source tree.

**Mocks/stubs:** None.

**Assertions:** Packaged config references only user-supplied content paths or
empty setup states.

**Cleanup:** None.

### AUTO-002: Product profile composition

**Given:** Full TV, Standard TV, Lite Receiver, Embedded Receiver, and
Experimental Legacy profile declarations.

**When:** Composition validation runs.

**Then:** Each build includes only approved modules, permissions, navigation
entries, and native dependencies.

**Fixtures:** Profile manifests and feature dependency graph.

**Mocks/stubs:** Fake modules for build validation.

**Assertions:** Lite build excludes AI runtime, recording, downloads,
multi-view, full EPG parser, and broad media permissions.

**Cleanup:** None.

### AUTO-003: Capability negotiation

**Given:** Controller offers 4K HEVC media and Lite Receiver reports 1080p
H.264, one decoder, no AI runtime.

**When:** Handoff is prepared.

**Then:** Routing selects compatible H.264 source or returns an unsupported
media explanation before current playback stops.

**Fixtures:** Fake media source list and fake device capabilities.

**Mocks/stubs:** Fake controller, fake receiver, fake playback router.

**Assertions:** Unsupported handoff is rejected safely; compatible handoff uses
restricted playback ticket.

**Cleanup:** Reset fake sessions.

### AUTO-004: D-pad focus stability

**Given:** Lite Receiver home with delayed artwork loading.

**When:** Rapid D-pad navigation occurs while thumbnails load.

**Then:** Focus target remains stable, focus movement stays under target
latency, and poster loading does not rebuild the full screen.

**Fixtures:** Fake home sections, delayed image loader.

**Mocks/stubs:** Fake image cache and focus event driver.

**Assertions:** Focus restores after playback and dialogs return focus to the
invoking control.

**Cleanup:** Dispose focus nodes.

### AUTO-005: Playback fallback

**Given:** Baseline HLS H.264/AAC source, alternate stream, and simulated
decoder/network failures.

**When:** Playback start or mid-stream recovery fails.

**Then:** App attempts bounded retry, authorization refresh, alternate source,
quality reduction, and then clear compatibility error without uncontrolled
loops.

**Fixtures:** Fake stream endpoints and error sequence.

**Mocks/stubs:** Fake playback backend and clock.

**Assertions:** Playback state is preserved; retry count is bounded; active
playback remains top resource priority.

**Cleanup:** Close fake player.

### AUTO-006: Analytics privacy filter

**Given:** Typed events containing safe fields, restricted fields, and
prohibited values that resemble URLs, headers, search text, media titles, local
paths, and credentials.

**When:** Analytics validation runs.

**Then:** Safe events pass, restricted events require policy justification, and
prohibited fields are rejected in development and stripped or dropped in
production.

**Fixtures:** Event schema registry and sample payloads.

**Mocks/stubs:** No-op provider and fake provider.

**Assertions:** Feature modules cannot call vendor SDK directly; disabled mode
deletes optional queued events immediately.

**Cleanup:** Reset event queue.

### AUTO-007: Legacy certification smoke

**Given:** Physical or approved test device profile for Android 8/9.

**When:** Certification smoke runs.

**Then:** App installs, launches, pairs, navigates with D-pad, plays baseline
H.264/AAC media, recovers from brief Wi-Fi interruption, and avoids repeated
out-of-memory crashes.

**Fixtures:** Baseline media fixture, test EPG slice, fake companion.

**Mocks/stubs:** Device-only mocks limited to network and companion services.

**Assertions:** Certification level is recorded as Certified, Compatible,
Experimental, or Unsupported.

**Cleanup:** Remove test source, pairing, and local caches.

## Implementation Boundaries

- Framework files: future capability/protocol/analytics packages, existing
  platform media/player/playlist/EPG/favorites/history packages.
- Application files: TV shell, IPTV feature UX, profile-specific navigation,
  settings, copy, empty states, and pairing entry points.
- Tests: host-only unit/widget tests, package composition tests, static scans,
  and physical-device certification for legacy Android.
- Docs: this feature packet, requirements review, release plan, release notes,
  and any ADR for profile/capability contracts.
- Verification environment: host-only tests for contracts and privacy; physical
  Android TV/Fire TV devices for legacy certification. Android Emulator is not
  required and should not be used for certification unless explicitly approved.
