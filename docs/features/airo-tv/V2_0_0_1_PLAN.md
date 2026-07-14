# Airo TV v2.0.0.1 Plan

**Status:** Draft  
**Date:** 2026-07-13  
**Release line:** V2 modular, based on latest `origin/v2`  
**Source:** `docs/features/airo-tv/PRD_SOURCE_v2.0.0.1.md`  
**GitHub release tracker:** https://github.com/DevelopersCoffee/airo/issues/672  
**GitHub milestone:** `v2.0.0.1 - Airo TV Platform Hardening`  
**Planning decision:** Scope v2.0.0.1 as a foundation and validation milestone, not a full AI TV launch.

## Version and Branch Policy

- `v2.0.0.1` is an internal planning milestone label for Airo TV platform
  hardening.
- Public release tags remain semantic v2 tags from the release-line policy:
  `v2.0.0`, `v2.0.1`, `v2.1.0`, and later `v2.x.y` tags.
- The active next development branch is `codex/next-v2.0.0.0`, created from
  latest `origin/v2` on 2026-07-14.
- Issue-scoped implementation branches may be stacked from this next branch or
  created directly from latest `origin/v2`; release candidates must still be cut
  from `v2` after reviewed work merges back.
- Four-part labels such as `v2.0.0.0` and `v2.0.0.1` must not be published as
  immutable Git release tags unless the repository release policy is changed by
  Release and DevEx.

## Executive Decision

The pasted PRD defines a multi-release product, not a single patch release. It
now contains nine major bodies of work:

1. Core Airo TV product requirements: BYOC content sources, playlist
   intelligence, search, player, profiles, recommendations, AI, cloud sync, and
   monetization.
2. Volume 2: universal media sources, canonical media models, metadata,
   universal search, EPG, import, stream health, and smart infrastructure.
3. Volume 3: cross-platform Flutter architecture, connected-device nodes, local
   discovery, secure pairing, command sessions, playback abstraction, handoff,
   sync, adaptive UI, and platform validation.
4. Volume 4: Media Routing Engine, playback delegation, route optimization,
   media capability detection, secure last-resort phone streaming, playback
   ownership, smart buffering, and Edge Media Node readiness.
5. Volume 5: native media engine, local protocol, media database
   infrastructure, large playlist and EPG workers, performance budgets,
   observability, benchmark device classes, and constrained-device readiness.
6. Volume 6: optional cloud playback orchestration, device identity,
   registration, presence, command routing, universal playback sessions,
   secure playback tickets, remote network control, and continuity.
7. Volume 7: legacy Android TV support, constrained hardware modes, device
   certification, and graceful degradation.
8. Volume 8: modular product profiles, Lite and Receiver editions, capability
   contracts, delegation, and build-time feature composition.
9. Volume 9: analytics, playback telemetry, experimentation, privacy controls,
   schema governance, and dashboards.

v2.0.0.1 should establish the platform contracts needed to build Airo TV
without committing to all premium AI features at once.

## Product Goal

Create the first implementation-ready plan for Airo TV as a compliant,
privacy-first BYOC media product that can ship as modular V2 product profiles:
Full TV, Standard TV, Lite Receiver, Embedded Receiver, Mobile Companion,
Desktop, and Home Node.

## Non-Goals For v2.0.0.1

- Do not ship on-device LLM inference on TV hardware.
- Do not build catch-up summaries, proactive agents, or AI parental controls.
- Do not add Stalker Portal until compliance and legal review approve it.
- Do not implement recording, timeshift, multi-view, or transcoding.
- Do not make the phone the default media server; phone-hosted streaming is
  allowed only when the media exists only on the phone.
- Do not claim 100,000-item library support, high-bitrate constrained-TV
  playback, or large EPG readiness before performance benchmarks pass.
- Do not introduce vendor SDK calls directly inside feature modules.
- Do not collect raw channel names, playlist URLs, search text, voice
  recordings, provider credentials, local paths, or full viewing history.
- Do not make old Android support depend only on OS version; device capability
  and security posture must decide behavior.
- Do not make cloud orchestration required for same-network playback.
- Do not put media bytes, full media URLs, provider credentials, or transcoding
  inside the cloud orchestration service.

## v2.0.0.1 Scope

### Now: Foundation Contracts

| Workstream | Outcome | Primary modules |
| --- | --- | --- |
| Product profiles | Define Full, Standard, Lite Receiver, Embedded Receiver, Experimental Legacy | docs, build config follow-up |
| Product profile manifests | Define per-profile included modules, excluded modules, navigation, permissions, resource budgets, release channel, guarantees, and support level | future `product_capabilities`, `core_product_composition` |
| Capability contract | Devices publish playback, search, EPG, AI, storage, codec, and profile capabilities | future `core_protocol`, `product_capabilities` |
| Module lifecycle manifest | Define supported profiles, dependencies, initialization cost, memory/storage budget, permissions, background tasks, shutdown behavior, flags, and fallbacks | future `core_product_composition`, build tooling |
| Composition validator | Prevent invalid profile/module combinations and block runtime flags from exposing modules absent from a build | future `core_product_composition`, QA automation |
| Connected node protocol | Define node identity, privacy-safe capability advertisements, lifecycle states, and compatibility negotiation | future `core_protocol`, `product_capabilities` |
| Local discovery and pairing | Define mDNS/DNS-SD discovery, QR pairing, trusted-device storage, revocation, and scoped permissions | future `core_protocol`, `core_security`, `feature_pairing` |
| Command and session protocol | Versioned envelope for playback, navigation, text, AI, and device commands with deterministic results | future `core_protocol`, `core_sessions`, `feature_remote` |
| BYOC content model | Preserve user-provided playlist and media-source boundaries | `packages/feature_iptv`, `platform_playlist`, `platform_playlist_import`, `platform_media` |
| Media Routing Engine | Choose direct cloud, NAS/server, desktop, TV-local, or last-resort phone route before playback | future `core_media_routing`, `core_media_models`, `platform_player` |
| Media location and route tokens | Represent cloud URL, authenticated URL, LAN source, server item, local file, and temporary route without leaking credentials | future `core_media_models`, `core_security` |
| Playback ownership | Define which node owns pause, resume, seek, analytics, health, and recovery for each playback session | future `core_sessions`, `core_media_routing` |
| Cloud orchestration boundary | Define optional cloud coordination for device registry, presence, command routing, state sync, transfer arbitration, and recovery without proxying media | future `core_cloud_orchestration`, `core_sessions`, `core_security` |
| Device identity and presence | Define stable device records, secure keys, registration, trust state, expiring presence leases, capability updates, revocation, and local/cloud merge | future `core_device_identity`, `core_presence`, `feature_device_picker` |
| Universal session and command model | Define desired vs actual playback state, receiver-authoritative revisions, idempotent command IDs, expiry, deduplication, typed results, and conflict policy | future `core_playback_session`, `core_protocol`, `feature_remote_control` |
| Secure playback tickets | Define receiver-bound, session-bound, short-lived tickets for direct receiver playback without leaking source credentials | future `core_playback_ticket`, `core_security`, `core_media_models` |
| Cloud privacy controls | Define local-only mode, remote-control settings, progress-sync settings, retention controls, parental/profile restrictions, and prohibited telemetry fields | future `core_privacy`, `core_presence`, `feature_settings` |
| Playback engine abstraction | Separate the shared playback contract from the current IPTV/video_player implementation | `platform_player`, `platform_media`, future playback adapters |
| Native media and probing | Define media engine, media request, diagnostics, native surface, probing, and decoder fallback contracts | future `platform_media_engine`, `platform_media_probe` |
| Data and worker infrastructure | Define large playlist import, media database benchmark, search index, EPG worker, and background job contracts | future `core_media_data`, `platform_worker_jobs`, `platform_epg` |
| Performance budgets | Define UI, playback, networking, database, memory, storage, and benchmark-device targets | future `core_performance`, QA automation |
| Legacy device profiling | Define runtime device profiles, device tiers, constraint states, dynamic reclassification, and capability-over-version policy | future `core_device_profile`, `core_legacy_modes`, QA automation |
| Legacy Receiver Mode | Define lightweight TV navigation, compact data windows, delegated search/EPG/AI, reduced artwork, reduced motion, and unavailable-feature replacements | future `feature_legacy_receiver`, `feature_compact_epg`, `feature_remote` |
| Certification framework | Define certified, compatible, experimental, and unsupported levels with physical-device evidence and benchmark gates | future `platform_certification`, QA automation |
| Dependency governance | Audit Android API, native architecture, binary size, memory impact, background behavior, shrinker needs, and known TV issues for every dependency | Release and DevEx |
| Restricted receiver trust | Define when old devices receive only playback tickets, basic commands, and state reporting instead of full credentials or admin abilities | future `core_security`, `core_device_identity`, `core_playback_ticket` |
| Delegation framework | Define trusted-node task routing for search, EPG, metadata, AI, subtitles, source resolution, artwork, stream health, and transcoding | future `core_delegation`, `core_protocol`, `feature_remote` |
| Remote view model | Define compact, cacheable, expiring views for search results, current/next EPG, favorites, compact cards, and ranked backup streams | future `core_remote_views`, `feature_compact_epg`, `feature_basic_search` |
| Profile data ownership | Define which profile owns playlist index, EPG, favorites, progress, embeddings, stream health, artwork, thumbnails, and credentials | future `core_media_data`, `core_sync`, `core_security` |
| Local state sync contract | Define encrypted incremental sync, conflict policy, and handoff state before cloud sync | `core_data`, future `core_sessions`, future `feature_sync` |
| Playback-first receiver path | Lite profile supports pairing, direct playback, favorites, recent, compact EPG, remote control | `platform_player`, `feature_iptv`, app TV shell |
| Analytics abstraction | Typed, privacy-filtered, consent-gated events with no-op provider | future analytics package |
| Analytics schema governance | Define event envelope, schema registry, owners, purposes, allowed/prohibited fields, retention, dashboard need, and tests | future `core_analytics`, `core_event_schema` |
| Consent and local-only analytics | Separate operational data, product analytics, crash reporting, personalized analytics, diagnostics upload, and local-only mode | future `core_privacy`, `core_analytics`, `feature_settings` |
| Playback quality telemetry | Define startup, buffering, failover, decoder, bitrate, resolution, completion, pairing, handoff, and legacy-device metrics using buckets | future `core_analytics`, `platform_media`, `feature_analytics` |
| Analytics buffering and providers | Define bounded event queue, priorities, sampling, upload scheduling, no-op provider, local diagnostics provider, and optional vendor adapters | future `core_analytics`, `core_diagnostics` |
| Experimentation guardrails | Define experiment assignment, remote config, sampling, kill switch, guardrail metrics, and restrictions against overriding privacy/security/build composition | future `core_experimentation`, `core_remote_config` |
| Legacy certification model | Define certification levels, test matrix, and minimum criteria | docs plus QA automation issue |

### Next: Buildable MVP Slice

| Workstream | Outcome |
| --- | --- |
| Airo TV Lite shell | TV-first BYOC receiver with D-pad navigation and compact home |
| Device profiling | Runtime tier selection, codec inventory, memory/storage classification |
| Local discovery | Android phone discovers Android TV on LAN through a framework-owned discovery adapter |
| Secure pairing | QR pairing creates a trusted-device relationship with scoped permissions and revocation |
| Phone remote skeleton | Playback, navigation, text input, and now-playing commands use the shared command envelope |
| Media routing preflight | Direct IPTV/cloud playback is selected without starting a phone media server |
| Route ownership snapshot | Playback sessions record route, owner, source node, playback node, position, volume, audio, subtitles, and health |
| Cloud orchestration contract | Optional cloud command/state interfaces are fakeable and explicitly separate from media delivery |
| Local/cloud device merge | Device picker can merge trusted LAN and cloud records without exposing sensitive state |
| Legacy receiver mode | Android 8/9 constrained TVs receive lightweight UI, compact data, delegated search, and reduced animations |
| Product composition validator | Full, Standard, Lite, Embedded, and Experimental manifests can be validated for modules, permissions, navigation, capabilities, and native libraries |
| Delegated remote views | Lite Receiver consumes compact search and EPG views from a trusted node without loading full datasets |
| Certification harness | API 26 device evidence, focus tests, playback fixtures, memory/storage stress, and store-distribution checks are defined |
| Performance baseline | Import, search, playback, local command, and database targets are benchmarked on defined device classes |
| Handoff preflight | Destination validation succeeds before source playback stops |
| Compact EPG | Current and next program view with delegated or incremental import |
| Playback hardening | H.264/AAC baseline, HLS/MPEG-TS, decoder fallback, network recovery |
| Analytics phase 1 | Onboarding and playback events through shared abstraction only |

### Later: Premium Intelligence

| Capability | Gate |
| --- | --- |
| Natural-language search | Search provider and privacy-safe AI routing contract complete |
| Voice assistant | On-device or companion speech path validated per platform |
| Recommendations | Local signal model, retention policy, and profile controls approved |
| Catch-up summaries | Caption/transcript availability, privacy review, and model routing approved |
| Cloud sync | Encrypted sync contract and account entitlement model complete |
| Remote network control and cloud continuity | Cloud orchestration, device presence, remote permissions, push wake, local-only controls, and playback-ticket security review complete |
| Recording and timeshift | Storage, rights, background execution, and platform policy review complete |
| NAS, desktop relay, and Edge Media Node | Media routing contracts validated with source adapters and security review |

## Recommended Architecture

```text
apps/
  airo_tv_full
  airo_tv_lite
  airo_receiver
  airo_mobile
  airo_desktop
  airo_home_node

packages/
  core_identity
  core_device_identity
  core_security
  core_protocol
  core_sessions
  core_playback_session
  core_playback_ticket
  core_cloud_orchestration
  core_presence
  core_media_models
  core_media_routing
  core_media_data
  core_performance
  core_sync
  core_device_profile
  core_legacy_modes
  core_product_composition
  core_delegation
  core_remote_views
  core_analytics
  core_event_schema
  core_diagnostics
  core_experimentation
  core_remote_config
  product_capabilities
  platform_player
  platform_media_engine
  platform_media_probe
  platform_network_discovery
  platform_realtime_gateway
  platform_push
  platform_local_media_server
  platform_certification
  platform_worker_jobs
  platform_playlist
  platform_playlist_import
  platform_epg
  platform_favorites
  platform_history
  feature_pairing
  feature_discovery
  feature_remote
  feature_remote_control
  feature_device_picker
  feature_legacy_receiver
  feature_embedded_receiver
  feature_sync
  feature_route_inspector
  feature_diagnostics
  feature_compact_epg
  feature_full_epg
  feature_basic_search
  feature_advanced_search
  feature_iptv
  feature_recording
  feature_multiview
  feature_analytics
  feature_privacy_settings
```

The current repository already has several of these package families:
`core_ai`, `core_auth`, `core_data`, `core_domain`, `core_ui`,
`feature_iptv`, `platform_channels`, `platform_epg`, `platform_favorites`,
`platform_history`, `platform_media`, `platform_player`,
`platform_playlist`, `platform_playlist_import`, and `platform_streams`.

## Product Profiles

| Profile | Role | Includes | Excludes |
| --- | --- | --- | --- |
| Full TV | Modern TV app | full discovery, local indexing, rich EPG, profiles, stream failover, advanced diagnostics | unsupported hardware features only |
| Standard TV | Mid-range TV app | playback, limited EPG, favorites, search, profiles, phone remote, reduced visuals | heavy AI, long EPG history, multi-view by default |
| Lite Receiver | Android 8/9 and low-memory TV | pairing, direct playback, handoff, favorites, recent, current/next EPG, basic search, stream failover | local AI, recording, downloads, multi-view, full catalog index |
| Embedded Receiver | Thin playback target | activation, playback receiver, commands, now-playing UI, basic settings | browsing, search, source management |
| Experimental Legacy | Community or direct builds | baseline playback, pairing, basic diagnostics | support guarantees, full security claims |

## Delivery Phases

### Phase 0: Planning Lock

Deliver:
- Save raw PRD source.
- Approve this v2.0.0.1 scope.
- Open or update the GitHub issue with the feature packet.
- Use `v2.0.0.1` as the planning milestone label only; public Git release tags
  remain semantic v2 tags such as `v2.0.0`, `v2.0.1`, and `v2.1.0`.

Exit criteria:
- Owning agents and review agents are listed.
- Cross-agent contracts are documented.
- Deterministic use cases and automation flows are present.

### Phase 1: Capability and Profile Contracts

Deliver:
- `ProductProfile` model.
- `DeviceCapabilities` model.
- `AiroNode` and `CapabilityAdvertisement` models.
- capability negotiation contract for controller-to-TV handoff.
- feature dependency graph for build and runtime validation.
- product profile manifests for Full TV, Standard TV, Lite Receiver, Embedded
  Receiver, and Experimental Legacy.
- module lifecycle manifest schema for dependencies, budgets, permissions,
  background jobs, feature flags, fallback, and supported profiles.
- composition validator that rejects invalid module/profile combinations.
- profile navigation manifests that exclude unavailable sections.
- capability publication schema that reports compiled modules and runtime-safe
  capabilities.
- initial release-channel model for Full TV stable, Lite TV stable, Receiver
  stable, Legacy experimental, vendor-specific, and internal certification.
- no-op and fake implementations for tests.

Exit criteria:
- Product composition tests can verify modules and navigation entries per profile.
- Runtime flags cannot expose code absent from the build.
- Lite Receiver and Embedded Receiver manifests exclude heavy native modules,
  broad permissions, recording, multiview, local AI, downloads, and full EPG.
- Capability advertisements match profile manifests and runtime device
  capability.

### Phase 1A: Connected Device Foundation

Deliver:
- local discovery abstraction and fake adapter.
- mDNS/DNS-SD service metadata schema for `_airotv._tcp`.
- secure QR pairing challenge/response contract.
- trusted-device model with revocation and scoped permissions.
- versioned command envelope with typed command results.
- session coordinator for remote control, playback, text input, AI assistance,
  handoff, and admin sessions.

Exit criteria:
- Android phone and Android TV can be tested as the first connected-device pair
  through fake adapters and at least one real local discovery adapter.
- Discovery metadata contains no playlist URLs, profile names, credentials,
  viewing history, or device secrets.
- Standalone TV playback works when discovery, pairing, AI routing, and cloud
  sync are unavailable.

### Phase 1B: Media Routing Foundation

Deliver:
- `MediaLocation`, `MediaRouteCandidate`, `MediaRoutePlan`, and
  `MediaRouteDecision` contracts.
- deterministic route priority: direct cloud/IPTV, NAS/server direct, desktop
  relay, TV-local media, then phone-local temporary server.
- playback ownership model for phone, TV, desktop, tablet, cloud, and future
  Edge Media Node.
- compatibility preflight contract for media capabilities, device capabilities,
  bandwidth, DRM/protection, subtitles, HDR, and audio pass-through.
- secure temporary mobile server requirements, including authenticated expiring
  URLs, trusted-device scope, HTTP range support, HEAD, ETag, auto shutdown,
  battery/thermal gating, and LAN-only behavior.
- route health event schema for buffer, position, volume, audio, subtitles,
  playback speed, route health, and typed failures.

Exit criteria:
- A direct IPTV/cloud media item selects direct destination playback without
  starting a phone media server.
- A phone-local media item can select a temporary phone server only when trust,
  LAN, battery, thermal, and media-serving preflight checks pass.
- Route decisions can be unit-tested with fake devices, fake media locations,
  and fake network conditions without a player backend.

### Phase 1C: Performance Foundation

Deliver:
- native media-engine spike and backend-selection ADR.
- `MediaRequest`, `MediaDiagnostics`, media probing, and decoder fallback
  contracts.
- large playlist worker pipeline contract with progress, cancellation, partial
  availability, batch writes, and import diagnostics.
- media database benchmark harness for representative Airo TV datasets.
- search-index contract for exact, prefix, token, normalized, alias, fuzzy, and
  history-ranked search.
- shared Airo media error taxonomy and privacy-safe diagnostics schema.
- performance budget definitions for UI, playback, networking, protocol,
  database, memory, storage, and benchmark device classes.

Exit criteria:
- The team can benchmark 10,000, 50,000, 100,000, and 250,000 item datasets
  before selecting final storage/indexing implementation.
- A prototype import path proves that parsing and indexing do not block TV
  navigation.
- Playback architecture proves decoded frames are not copied through Dart in
  the intended production path.

### Phase 1D: Cloud Orchestration Boundary

Deliver:
- optional cloud orchestration service boundary for device registry, presence,
  command routing, state distribution, playback tickets, notifications, and
  recovery.
- `AiroDeviceRecord`, `DeviceRegistration`, `PresenceLease`, and
  `TrustState` contracts.
- universal playback-session model with receiver-authoritative actual state,
  controller-requested desired state, monotonic revisions, and snapshot
  recovery.
- command envelope with `commandId`, `sessionId`, sender, target, action,
  payload, expected revision, issue/expiry timestamps, idempotency, and typed
  command results.
- LAN/cloud route deduplication rules so the same command delivered over both
  paths executes once.
- secure playback-ticket contract for receiver-bound, session-bound,
  short-lived direct playback access.
- local/cloud device merge algorithm for the device picker.
- remote-control permission model, local-only mode, cloud progress-sync
  setting, and retention controls.
- backend storage-interface docs for devices, expiring presence, playback
  sessions, session controllers, short-retention commands, and media progress.

Exit criteria:
- Same-network receiver playback and local control remain usable when cloud
  orchestration is disabled or unavailable.
- Fake LAN and fake cloud transports can deliver the same command without
  duplicate execution.
- A fake revoked device is rejected for cloud commands and removed from trusted
  device selection.
- Receiver state wins over controller optimistic state for position, buffering,
  decoder errors, tracks, and completion.
- Playback tickets can be validated without logging full URLs, credentials, or
  provider secrets.

### Phase 2: Lite Receiver MVP

Deliver:
- TV home sections: Home, Live, Favorites, Recent, Search, Settings.
- QR pairing and phone remote implementation using the connected-device
  contracts from Phase 1A.
- playback delegation through the Media Routing Engine from Phase 1B.
- direct playback from user source or secure playback ticket.
- optional cloud orchestration remains off by default unless the account and
  device explicitly enable cloud discovery or remote control.
- performance instrumentation for import, search, playback startup, command
  acknowledgement, and UI frame health.
- compact EPG for current and next program.
- fallback messages for unsupported codecs and unavailable companion.

Exit criteria:
- Certified test device can install, launch, navigate with D-pad, pair, and play baseline H.264/AAC media.
- Large catalogs are not loaded into TV memory.
- Phone-hosted media serving is not used for direct URL media.
- Cloud orchestration is not required for same-LAN pairing, commands, or
  playback.
- Large-library claims are limited to the benchmarked dataset sizes and device
  classes that actually pass.

### Phase 3: Legacy Optimization

Deliver:
- runtime device profiling for Android API, TV platform, model class, CPU,
  RAM, storage, GPU, codec inventory, decoder count, network class, remote
  keys, thermal state, and security posture.
- legacy support tiers: Certified, Compatible, Experimental, Unsupported.
- Legacy Receiver Mode with lightweight home, compact EPG, phone-assisted
  search, favorites, recent, paired-device status, diagnostics, reduced
  artwork, reduced motion, and no on-TV heavy AI.
- dependency governance report for Android API floor, native architecture,
  binary size, memory impact, background behavior, shrinker requirements,
  hardware-decoder assumptions, maintenance status, and known TV issues.
- memory, storage, artwork, animation, widget rebuild, focus, networking, EPG,
  and background-job budgets by device tier.
- decoder inventory, media capability probing, backend fallback rules, and weak
  network recovery policy.
- restricted receiver trust mode for old or less secure devices.
- Google Play, Amazon Appstore, direct APK, and operator-box distribution
  matrix.
- certification matrix, device inventory, benchmark gates, and evidence
  templates.

Exit criteria:
- Android 8/9 devices can pass the minimum certification criteria on physical
  hardware before support is advertised.
- Lower-than-API-26 support remains experimental until dependency, security,
  media, distribution, and real-device certification gates pass.
- Unsupported or unavailable features are hidden or replaced with useful
  alternatives.
- Large catalogs are not loaded fully into constrained TV memory.
- D-pad focus remains stable during rapid input and artwork loading.
- Memory pressure preserves active playback and reduces nonessential caches.

### Phase 4: Analytics Foundation

Deliver:
- vendor-neutral `AnalyticsService` contract.
- typed event model and common event envelope.
- consent state for operational data, product analytics, crash reporting,
  personalized analytics, diagnostics upload, and local-only mode.
- no-op provider and local diagnostics provider.
- privacy filter and prohibited-field validation for URLs, auth headers,
  credentials, local paths, local IPs, raw queries, voice transcripts, channel
  names, media titles, playlist names, and provider secrets.
- bounded event queue with priorities, sampling, backoff, consent withdrawal
  deletion, and playback-aware upload scheduling.
- initial onboarding, playback, pairing, handoff, legacy-device, and feature
  adoption event schemas.
- schema registry with event owner, product purpose, allowed fields, prohibited
  fields, retention, dashboard requirement, and tests.
- crash-reporting adapter contract with redaction and opt-out behavior.
- local event inspector for development builds.

Exit criteria:
- No feature module imports Firebase or another vendor analytics SDK directly.
- Analytics disabled mode preserves normal playback.
- Prohibited fields are rejected.
- Existing debug analytics that include raw channel names are replaced or
  blocked by schema validation before production analytics is enabled.
- Analytics provider initialization failure falls back to no-op behavior.
- Local-only mode disables external analytics and crash upload unless the user
  explicitly exports diagnostics.

### Phase 4A: Playback, Reliability, and Experimentation Telemetry

Deliver:
- playback quality KPIs: time to first frame, join failure rate, rebuffer
  ratio, failover recovery rate, decoder failure, subtitle/audio failure,
  completion, and end reason.
- device ecosystem metrics for discovery, pairing, command route, handoff,
  session recovery, delegated tasks, and companion availability.
- profile-specific analytics policies for Full TV, Lite Receiver, Embedded
  Receiver, mobile, desktop, and home node.
- crash grouping by app version, product profile, device tier, playback backend,
  decoder family, memory pressure, and release.
- remote configuration contract with consent, entitlement, build-composition,
  security, and legacy-device guardrails.
- experimentation contract with stable anonymous assignment, eligibility,
  control group, primary metric, guardrails, minimum sample, remote stop, and
  no experiments on security controls.
- dashboard specs for executive, playback reliability, legacy device, device
  ecosystem, and subscription views.
- alert specs for playback failures, crash spikes, memory pressure, pairing,
  handoff, subscription purchase, EPG import, protocol mismatch, release
  regression, and device-class instability.

Exit criteria:
- Playback success and activation can be measured without raw media data.
- Experiments cannot override privacy, security, entitlement, or missing build
  modules.
- Dashboards distinguish eligible users from total users.
- Retention and deletion policy is documented before external provider rollout.

### Phase 5: Premium AI Readiness

Deliver:
- provider interfaces for search, AI routing, recommendations, and voice.
- companion/home-node/cloud delegation contract based on connected-node
  capability advertisements.
- local-only fallback rules.
- privacy disclosures for AI processing location.

Exit criteria:
- Natural-language search can be implemented without changing receiver contracts.
- Legacy devices delegate AI work instead of bundling an AI runtime.

## Priority Backlog

| ID | Priority | Item | Owner | Notes |
| --- | --- | --- | --- | --- |
| ATV-001 | P0 | Approve v2.0.0.1 feature packet | Media Agent | Blocks implementation |
| ATV-002 | P0 | Decide version tag policy | Release and DevEx | Docs use requested label, repo uses semver |
| ATV-003 | P0 | Define product profile and capability models | Framework Agent | Needed by all profiles |
| ATV-004 | P0 | Define Lite Receiver MVP shell | Media Agent, Mobile UI | TV navigation and playback-first UX |
| ATV-005 | P0 | Define analytics abstraction and prohibited fields | Security, Framework | No direct Firebase usage in feature modules |
| ATV-006 | P1 | Define pairing and playback-ticket contract | Framework, Security, Media | Required for companion-assisted search |
| ATV-007 | P1 | Define compact EPG contract | Media Agent | Current/next only for Lite |
| ATV-008 | P1 | Define legacy certification matrix | QA Automation | Physical device evidence required |
| ATV-009 | P1 | Define dependency governance checklist | Release and DevEx | Prevent unnecessary minSdk increases |
| ATV-010 | P2 | Define AI search delegation contract | AI Agent, Security | Enables later natural-language search |
| ATV-011 | P0 | Define connected-node protocol | Framework, Security | Node identity, lifecycle states, capability advertisements |
| ATV-012 | P0 | Define local discovery abstraction | Framework, Platform | mDNS/DNS-SD, fake adapter, privacy-safe metadata |
| ATV-013 | P0 | Define secure trusted-device model | Security, Framework | Pairing, scoped permissions, key rotation, revocation |
| ATV-014 | P0 | Define versioned command envelope | Framework, Media | Playback, navigation, text, AI, and device commands |
| ATV-015 | P0 | Define PlaybackEngine abstraction | Media, Platform | General contract before adding more playback backends |
| ATV-016 | P1 | Define local sync and handoff state contract | Framework, Data, Media | Incremental encrypted sync, conflicts, handoff preflight |
| ATV-017 | P1 | Define adaptive UI mode contract | UI, Media | Touch, remote, pointer, hybrid, density, accessibility |
| ATV-018 | P1 | Define cross-platform validation matrix | QA, Platform | Android, Android TV, iOS/iPadOS, desktop, Apple TV |
| ATV-019 | P0 | Define Media Routing Engine contract | Framework, Media | Direct source first, phone server last |
| ATV-020 | P0 | Define media location and route-token model | Media, Security | Cloud, LAN, server item, local file, temporary URL |
| ATV-021 | P0 | Define route scoring and decision logs | Framework, Media | Deterministic, explainable, privacy-filtered routing |
| ATV-022 | P0 | Define playback ownership model | Framework, Media, Analytics | Owner controls pause, seek, resume, health, analytics |
| ATV-023 | P0 | Define secure temporary mobile server contract | Security, Platform | Range, HEAD, ETag, expiry, trust scope, battery gates |
| ATV-024 | P1 | Define media capability detection contract | Media, Platform | Codec, container, HDR, bitrate, subtitles, audio |
| ATV-025 | P1 | Define route health event schema | Framework, Media | Event-driven state without polling |
| ATV-026 | P2 | Define Edge Media Node placeholder contract | Desktop, AI, Media | Future indexing, relay, recording, health, transcoding |
| ATV-027 | P0 | Define native media engine spike | Media, Platform | Backend options, surfaces, diagnostics, decoder fallback |
| ATV-028 | P0 | Define media database benchmark harness | Data, Media, QA | Representative large IPTV/VOD/EPG datasets |
| ATV-029 | P0 | Define large playlist worker pipeline | Data, Media | Streamed parsing, progress, cancellation, batch writes |
| ATV-030 | P0 | Define shared Airo media error taxonomy | Framework, Security, Media | Retryability, severity, user messages, redaction |
| ATV-031 | P0 | Define performance instrumentation schema | QA, Framework, Media | UI, playback, import, search, protocol, memory |
| ATV-032 | P1 | Define Protobuf protocol schemas | Framework, Platform | Envelope, commands, state, health, EPG sync |
| ATV-033 | P1 | Define secure WebSocket transport | Security, Framework | Local command and state sync baseline |
| ATV-034 | P1 | Define distributed EPG worker contract | Media, Data | Compact snapshots, incremental transfer, TV cache |
| ATV-035 | P1 | Define resource scheduler contract | Platform, Media | Background work respects playback and pressure |
| ATV-036 | P1 | Define benchmark device-class gates | QA, Platform | Constrained TV, standard TV, mobile, desktop |
| ATV-037 | P0 | Define cloud orchestration boundary | Framework, Security, Media | Coordinates devices, commands, state, and recovery without proxying media |
| ATV-038 | P0 | Define device identity and registration contract | Security, Framework | Stable IDs, secure keys, scoped tokens, duplicate handling, revocation |
| ATV-039 | P0 | Define device presence lease model | Framework, Platform | Expiring presence, adaptive heartbeat, lifecycle states, privacy-safe visibility |
| ATV-040 | P0 | Define universal playback session state | Framework, Media | Desired vs actual state, receiver authority, revisions, snapshot recovery |
| ATV-041 | P0 | Define command result, expiry, dedup, and conflict rules | Framework, Media, Security | LAN/cloud duplicate suppression and deterministic stale-command handling |
| ATV-042 | P0 | Define secure playback-ticket service contract | Security, Media | Receiver-bound, session-bound, single-use, short-lived, redacted |
| ATV-043 | P1 | Define local/cloud device merge contract | Framework, UI, Security | Device picker merges LAN and cloud records with trust and capability checks |
| ATV-044 | P1 | Define remote-control permissions and local-only mode | Security, Media, UX | Same-account remote, approval-required mode, child/profile restrictions |
| ATV-045 | P1 | Define cloud continue-watching progress model | Data, Media, Security | Profile/media/source progress with revisions, retention, and opt-out |
| ATV-046 | P1 | Define backend orchestration storage interfaces | Backend, Framework | Devices, presence, sessions, controllers, commands, progress |
| ATV-047 | P2 | Define push wake and notification fallback contract | Platform, Backend | Remote wake is platform-dependent and must not be assumed universal |
| ATV-048 | P0 | Define runtime legacy device profile | Platform, Framework, QA | API, RAM, storage, GPU, codecs, network, remote, thermals, security posture |
| ATV-049 | P0 | Define Legacy Receiver Mode contract | Media, UI, Platform | Lightweight home, compact EPG, delegated search, reduced artwork and motion |
| ATV-050 | P0 | Define dependency governance audit | Release and DevEx | Prevent accidental API floor, binary size, or TV compatibility regressions |
| ATV-051 | P0 | Define device certification program | QA, Platform, Release | Certified, Compatible, Experimental, Unsupported with evidence gates |
| ATV-052 | P0 | Define media capability and decoder probe matrix | Media, Platform, QA | H.264/AAC/HLS baseline, optional HEVC/AV1/HDR/4K proof by device |
| ATV-053 | P1 | Define legacy UI and focus performance budget | UI, QA | Rapid D-pad, focus restore, artwork loading, rebuild boundaries |
| ATV-054 | P1 | Define constrained memory/storage/resource scheduler | Platform, Data, Media | Playback priority, cache limits, low-storage mode, background deferral |
| ATV-055 | P1 | Define secure phone-local media server requirements | Security, Platform, Media | Real local file serving with Range, 206, expiry, cancellation, battery gates |
| ATV-056 | P1 | Define restricted receiver trust mode | Security, Framework, Media | Playback tickets only, no full credentials, no admin or billing actions |
| ATV-057 | P1 | Define legacy store and distribution matrix | Release, Legal, Platform | Google Play TV, Amazon Appstore, direct APK, operator boxes |
| ATV-058 | P2 | Define extended lower-API evaluation process | Platform, QA, Security | Below API 26 remains experimental until certification passes |
| ATV-059 | P0 | Define product profile manifest schema | Framework, Release, QA | Modules, navigation, permissions, budgets, guarantees, support level |
| ATV-060 | P0 | Define module lifecycle manifest schema | Framework, DevEx | Dependencies, init cost, memory/storage, background jobs, fallback, flags |
| ATV-061 | P0 | Define product composition validator | DevEx, QA, Framework | Reject invalid profile/module combinations and absent-module runtime flags |
| ATV-062 | P0 | Define profile-aware capability advertisement | Framework, Media, Security | Product profile, compiled modules, runtime-safe capabilities, unsupported reasons |
| ATV-063 | P0 | Define delegation task framework | Framework, Media, Security | IDs, timeout, encrypted payloads, versioned results, cancellation, dedup, fallback |
| ATV-064 | P1 | Define remote view model | Media, Data, UI | Compact search, EPG, favorites, cards, ranked streams with expiry/cache rules |
| ATV-065 | P1 | Define profile navigation manifests | UI, Media | Full, Lite, Embedded sections with no empty unavailable routes |
| ATV-066 | P1 | Define profile data ownership matrix | Data, Security, Media | Playlist, EPG, progress, favorites, credentials, thumbnails, stream health |
| ATV-067 | P1 | Define release channel and store listing strategy | Release, Product, Legal | Single adaptive app vs Full/Lite/Receiver listings vs targeted delivery |
| ATV-068 | P1 | Define cross-profile compatibility test suite | QA, Framework, Media | Full/mobile/Lite/Receiver handoff, old/new protocol, companion unavailable |
| ATV-069 | P0 | Define analytics service contract | Framework, Security, Privacy | Typed events, consent gate, no-op provider, no direct vendor SDK calls |
| ATV-070 | P0 | Define analytics event envelope and schema registry | Framework, Data, Product | Names, versions, owners, purpose, allowed/prohibited fields, retention |
| ATV-071 | P0 | Define analytics privacy filter tests | Security, QA | Reject URLs, credentials, auth headers, local paths/IPs, raw queries, titles |
| ATV-072 | P0 | Define consent and local-only analytics behavior | Privacy, Security, UX | Product analytics, crash, personalized, diagnostics, reset, queue deletion |
| ATV-073 | P0 | Define bounded analytics queue and provider behavior | Framework, Platform | Priorities, sampling, backoff, playback-aware uploads, provider outage no-op |
| ATV-074 | P1 | Define playback quality telemetry model | Media, Analytics, QA | Startup, buffering, failover, decoder, bitrate, resolution, completion |
| ATV-075 | P1 | Define pairing, handoff, and device ecosystem metrics | Framework, Media, Analytics | Discovery, routes, command latency, delegation, companion availability |
| ATV-076 | P1 | Define crash reporting adapter and redaction contract | Platform, Security, QA | Stack/native crash data with URL/header/path/title/search redaction |
| ATV-077 | P1 | Define analytics profiles by product edition | Product, Privacy, Framework | Full, Lite, Embedded, mobile, desktop, local-only event sets |
| ATV-078 | P1 | Define experimentation and remote config guardrails | Product, Security, Release | Assignment, kill switch, guardrails, no privacy/security/build override |
| ATV-079 | P1 | Define analytics retention and data access policy | Privacy, Data, Security | Retention periods, deletion workflow, least-privilege access |
| ATV-080 | P2 | Define analytics dashboards and operational alerts | Product, Analytics, SRE | Executive, playback, legacy, ecosystem, subscription, regression alerts |
| ATV-081 | P2 | Define self-hosted event gateway option | Backend, Privacy, Analytics | Schema validation, rate limits, retention, deletion, regional controls |

## Key Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Scope tries to ship full PRD in one release | Large schedule slip, unstable TV app | Treat v2.0.0.1 as contracts plus Lite MVP planning |
| Legacy support becomes scattered conditionals | Fragile code and high test cost | Use product profiles and build-time composition |
| Analytics violates privacy positioning | Store risk and user trust loss | Typed schema, consent gate, prohibited-field tests |
| Old TVs cannot protect credentials | Security incident | Restricted Receiver mode with short-lived playback tickets |
| AI features overload TVs | Playback regression | Delegate AI to phone, desktop, home node, or cloud |
| Direct Firebase coupling spreads | Vendor lock-in and platform gaps | Adapter behind analytics service only |
| Phone-hosted media lacks byte-range support | Seeking fails | Require HTTP 206 Partial Content implementation |
| Device support claims exceed real testing | Support burden and bad reviews | Certification levels: Certified, Compatible, Experimental, Unsupported |
| Local discovery leaks sensitive state | Privacy and trust incident | Broadcast only non-sensitive metadata and validate with prohibited-field tests |
| Pairing is built as UI without trust lifecycle | Unauthorized control or stale trusted devices | Framework-owned pairing protocol, key expiry, revocation, and scoped permissions |
| Command protocol becomes feature-specific | Remote, handoff, and AI delegation diverge | Versioned shared envelope with typed command results |
| Playback abstraction leaks IPTV assumptions | Desktop, files, RTSP, subtitles, and diagnostics become hard to add | Define `PlaybackEngine` before expanding backends |
| Platform parity is promised before validation | Failed iOS/desktop/Apple TV expectations | Android phone plus Android TV first; other platforms contract-only until validated |
| Phone becomes default media server | Battery drain, heat, fragile playback, poor user trust | Route engine must prefer direct cloud, NAS, desktop, or TV-local routes first |
| Existing Cast HTTP proxy is reused as mobile server | Unauthenticated local media exposure | Keep proxy compatibility-only until secure mobile-server contract is implemented |
| Route decisions are opaque | Hard-to-debug playback failures | Require privacy-filtered decision logs and deterministic fake tests |
| Compatibility is discovered after handoff | Failed playback and broken resume | Run route compatibility preflight before stopping source playback |
| Flutter isolate does heavy media work | Jank, input lag, dropped TV focus, poor playback | Move imports, EPG, probing, search indexing, crypto, and media work to worker/native services |
| Database is selected without benchmarks | Large libraries become slow or fragile | Benchmark representative datasets before selecting storage/index strategy |
| Native backend is chosen too early | Platform lock-in or poor constrained-TV playback | Run a media-engine spike and backend ADR before implementation |
| Diagnostics leak sensitive media data | Privacy and legal risk | Shared redaction schema for URLs, credentials, local addresses, and histories |
| Cloud orchestration becomes a media path | Bandwidth cost, privacy exposure, provider credential leakage, and playback fragility | Cloud service may route commands/state only; receiver must fetch media directly |
| Cloud becomes required for local playback | Local-first promise breaks and outages stop same-network use | Same-LAN control and playback are release gates with cloud disabled |
| Device identity or revocation is weak | Unauthorized remote control or stale trusted devices | Device-scoped tokens, secure keys, revocation tests, and trusted-device review |
| LAN and cloud commands both execute | Duplicate seek, stop, transfer, or recording actions | Globally unique command IDs, idempotency, expiry, and duplicate suppression |
| Presence leaks sensitive viewing state | Privacy incident for profiles, children, or shared households | Presence payload must be minimized and title/profile visibility permissioned |
| Remote control premium scope enters the MVP too early | Delays Lite Receiver foundation and increases backend risk | Keep Volume 6 production cloud features contract-only until security and entitlement gates pass |
| Android support is claimed by OS version only | Bad reviews, support burden, and unreliable playback on weak hardware | Capability profile and certification gate support claims |
| Dependency updates silently drop API 26 | Legacy strategy breaks late in release | Dependency governance audit and CI guard for effective API floor |
| Legacy Receiver Mode becomes only a theme | Old TVs still load heavy data, artwork, AI, and background jobs | Mode must control navigation, feature availability, data windows, cache budgets, and workers |
| Focus feels slow or unstable on remotes | TV UX becomes unusable despite working playback | Rapid D-pad tests, focus latency budget, and artwork loading stability tests |
| Phone media proxy is mistaken for local file server | Seeking, security, battery, and thermal behavior fail | Separate secure phone-local media server contract with verified `206 Partial Content` |
| Experimental devices are marketed as supported | Support obligations exceed engineering evidence | Certified/Compatible/Experimental/Unsupported labels with release gates |
| Old devices cannot protect credentials | Account or provider exposure | Restricted receiver trust, short-lived tickets, and no admin/billing/profile authority |
| Product profiles remain only naming | Legacy support devolves into scattered conditionals | Enforce profile manifests, module manifests, and composition validation |
| Runtime flags expose absent modules | Crashes, empty screens, and invalid support claims | Composition tests must prove absent modules cannot be routed to or enabled |
| Lite build still carries heavy native libraries | Startup, memory, install size, and API compatibility regressions | Native library and permission checks per profile |
| Capability ads overstate device behavior | Invalid handoffs and poor controller UX | Capability publication must include compiled modules, runtime safety, and unsupported reasons |
| Delegation lacks fallback | Lite/embedded devices become unusable without a helper node | Every delegated task needs timeout, cancellation, fallback, and user messaging |
| Multiple app listings confuse users | Support friction and account/subscription confusion | Decide store strategy with one-account entitlement and migration rules before release |
| Debug analytics become production analytics | Raw channel names, URLs, or search text leak | Typed schemas and prohibited-field tests must replace arbitrary map logging |
| Analytics blocks playback | Startup or buffering worsens on weak TVs | Enqueue under 5ms target, no startup dependency, bounded queue, deferred upload during playback stress |
| Vendor SDK coupling spreads | Fire OS, desktop, embedded, and local-only modes break | Feature modules call only shared analytics contract; vendors are adapters |
| Consent toggle only hides UI | Events remain queued or uploaded after opt-out | Consent must stop collection and delete optional queued events immediately |
| Crash telemetry leaks source details | URLs, headers, paths, titles, or provider data leave device | Crash redaction pipeline and tests before provider upload |
| Remote config enables unsafe behavior | Unsupported codecs, absent modules, or unentitled features activate | Remote config cannot override build composition, security, consent, or entitlement |

## Open Questions

- What exact semantic v2 tag will carry the first public artifact after this
  planning milestone: `v2.0.0`, `v2.0.1`, or a later semver tag?
- Which platforms are in the first implementation target: Android TV only, or Android TV plus mobile companion?
- Does v2.0.0.1 include a code MVP, or only specs and issue packets?
- What is the first physical Android 8/9 test device inventory?
- Is the first connected-device MVP explicitly Android phone plus Android TV?
- Which local discovery package or native adapter will own mDNS/DNS-SD on each
  platform?
- Which commands are allowed before a device is fully trusted?
- What is the minimum trusted-device permission set for Lite Receiver?
- Which direct media routes are in the first MVP: IPTV/cloud only, or also NAS
  and desktop-hosted files?
- What route signals are mandatory before v2.0.0.1 implementation: codec,
  container, HDR, audio, bandwidth, battery, thermal, or all of them?
- Should temporary phone-hosted streaming be implemented in v2.0.0.1 or remain
  contract-only until the security review is complete?
- What is the first acceptable Edge Media Node placeholder: desktop app,
  home-server package, or only a capability schema?
- Which native media backend should be spiked first: platform-native,
  MPV/FFmpeg, LibVLC, or `video_player` as a temporary adapter?
- What representative playlist, VOD, and EPG datasets define the benchmark
  harness?
- Is Protobuf required for v2.0.0.1 local protocol, or should JSON remain the
  temporary development transport until schema tooling lands?
- Which constrained TV devices define Class A benchmark gates?
- Are desktop, tablet, and Apple TV implementation targets for v2.0.0.1, or
  contract-compatible later phases only?
- Which billing path is expected for Premium: Google Play Billing, Amazon IAP, Apple IAP, or deferred?
- Is Stalker Portal explicitly out of scope until a legal review is complete?
- Which cloud provider, if any, owns encrypted sync and device discovery?
- Which cloud provider, if any, owns Volume 6 persistent connections and command
  routing: Firebase, custom WebSocket service, managed real-time database, or a
  provider-neutral gateway?
- Is Volume 6 implementation in v2.0.0.1, or are only contracts, fakes, and
  acceptance tests in scope?
- Are remote network control and cloud continue watching Premium by default?
- What is the first remote-control trust model: same account only, household
  sharing, explicit trusted-device invite, or approval-required per receiver?
- What exact behavior is required for device reinstall, factory reset, rename,
  key rotation, account change, and device transfer?
- Which push providers are allowed for Android TV, Android mobile, iOS,
  desktop, and web dashboard?
- What retention windows apply to command history, playback sessions, progress,
  security history, and diagnostics?
- Which local-only settings are default for child profiles and
  privacy-sensitive accounts?
- What exact Android 8/9 and Fire TV devices form the first certification
  inventory?
- What RAM, storage, codec, network, and security thresholds define Certified,
  Compatible, Experimental, and Unsupported?
- Is `pubspec_tv.yaml` the long-term build mechanism, or should TV profiles
  become first-class app targets?
- Which media backend should be the legacy certification baseline:
  `video_player` ExoPlayer, Android Media3, LibVLC, MPV, or a hybrid?
- Which codec and stream fixtures define baseline certification?
- Which dependencies currently raise or threaten the effective API 26 floor?
- What is the minimum secure-storage posture for old, rooted, or vendor-modified
  TV boxes?
- Which distribution channels are approved for experimental legacy builds?
- What evidence is required before marketing claims support for a device class?
- Should Airo TV Lite ship as a separate listing, device-targeted bundle, or
  adaptive mode inside one app?
- What manifest format should define product profiles and modules: Dart
  declarations, YAML, generated metadata, or a hybrid?
- Which modules are compile-time excluded for Lite Receiver and Embedded
  Receiver?
- Which permissions and native libraries are allowed per product profile?
- What is the first supported delegation host: phone, desktop, home node, or
  cloud?
- How do Full TV, Lite, Receiver, mobile, desktop, and home node version
  independently while preserving protocol compatibility?
- What migration guarantees are required when moving from Lite to Full or Full
  to Lite?
- Which release channel owns experimental legacy builds and vendor/operator
  editions?
- Which analytics provider is first: no-op only, Firebase adapter, self-hosted
  gateway, local diagnostics, or a combination?
- Where should the analytics schema registry live: repo YAML, Dart declarations,
  backend registry, or generated artifacts?
- What are the default analytics, crash-reporting, and diagnostics consent
  states by platform, region, profile, and child profile?
- Which Volume 9 events are required for v2.0.0.1 readiness versus later
  dashboards?
- What retention windows are approved for product events, crash data,
  performance aggregates, security events, and diagnostics?
- Who owns analytics data access approval, deletion workflows, and audit logs?
- What exact redaction patterns must be enforced for media URLs, provider
  domains, local IPs, file paths, media titles, channel names, and voice/query
  text?
- Which experiments are explicitly disallowed for subscription, entitlement,
  security, child profiles, and legacy-device optimization?

## Readiness Recommendation

Approve v2.0.0.1 as a planning and platform-contract milestone. The first
implementation milestone should be Lite Receiver MVP on the V2 modular branch,
with companion-assisted search planned but not required for standalone playback.
