# Airo TV v2.0.0.1 Requirements Review

**Status:** Draft  
**Date:** 2026-07-13  
**Source:** `docs/features/airo-tv/PRD_SOURCE_v2.0.0.1.md`

## Requirement Inventory

### Core Product PRD

| Area | Requirement | Disposition for v2.0.0.1 |
| --- | --- | --- |
| Positioning | BYOC only; Airo TV never provides content | Must-have |
| Vision | AI-powered personal TV interface | Principle, not v2.0.0.1 scope |
| Users | casual users, sports fans, power users, families | Keep as personas |
| Content sources | M3U, Xtream, Jellyfin, Plex, Emby, local, NAS, SMB, FTP/SFTP, WebDAV, DLNA | Start with M3U/Xtream and existing BYOC packages; defer the rest |
| Credential storage | encrypted storage and offline cache | Must-have contract before source expansion |
| Playlist intelligence | parse, normalize, dedupe, health check, EPG match, classify, recommend | Split: parse/normalize now; AI classification/recommendations later |
| Voice AI | remote button, natural language commands, intent categories | Defer implementation; define provider interface later |
| AI search | semantic and natural-language search over metadata, teams, events, time, countries | Defer AI; support basic search and delegation contract first |
| Live match finder | rank working streams by quality, latency, language, event | Later premium feature |
| AI catch-up | summaries from captions, subtitles, audio transcription | Later premium feature |
| Recommendations | local recommendation engine with history, favorites, time, genres | Later, after profile and privacy contracts |
| Smart EPG | matching, providers, fallback, missing metadata repair | Compact EPG now; full smart EPG later |
| Profiles | adult, kids, guest, sports, movies, anime with favorites/history/restrictions | Basic profile contract now; full profile UX later |
| Parental AI | contextual genre/time/language/age rules | Later security and family-safety review |
| Video player | HLS, MPEGTS, DASH, RTMP, MKV, MP4, AVI, HDR, Dolby, subtitles, PiP, recording, timeshift | HLS/MPEG-TS/MP4 baseline now; recording/timeshift later |
| Channel health | latency, bitrate, availability, resolution, failover, ranking | Basic playback failure and fallback now; proactive health later |
| Offline AI | Gemma, Phi, Llama, Mistral for search/recommendations/summaries/voice | Not for legacy TVs; defer to AI routing workstream |
| Premium | unlimited playlists, voice AI, catch-up, recommendations, cloud sync, widgets, themes, no ads | Monetization model only; no paywall implementation in v2.0.0.1 |
| Cloud | encrypted sync for profiles, favorites, history, settings, metadata; never upload videos/credentials/habits/voice | Contract later; must preserve prohibitions now |
| Security | encrypted credentials, local AI, no analytics by default, biometric lock, private mode, encrypted sync | Security constraints are must-have |
| Compliance | no playlists, channels, pirated content, or illegal-service recommendations | Must-have |
| Performance | cold start <2s, voice <500ms, channel switch <1s, 100k parse <15s, memory <400MB | Use as targets, not immediate acceptance for all profiles |
| Success metrics | playback success, voice accuracy, parsing success, premium conversion, retention | Define analytics events before measuring |

### Volume 6: Cloud Playback Orchestration and Continuity

| Area | Requirement | Disposition for v2.0.0.1 |
| --- | --- | --- |
| Architecture principle | hybrid local-first and cloud-assisted orchestration | Must-have contract |
| Cloud boundary | cloud coordinates devices, commands, state, transfer, authorization, recovery, audit, and revocation | Must-have contract |
| Media path | controller and cloud service must not proxy receiver media by default | Must-have |
| Same-network fallback | direct LAN control and playback continue when cloud is unavailable | Must-have |
| Device registry | stable device records, account binding, platform, app/protocol version, capabilities, trust state, last seen | Phase 1D |
| Device identity | generated crypto identity, secure key storage, duplicate handling, reset, rename, revoke, key rotation | Phase 1D |
| Presence | expiring leases, adaptive heartbeat, platform lifecycle states, privacy-safe visibility | Phase 1D |
| Persistent channel | secure WebSocket or future equivalent with reconnect, snapshot recovery, credential refresh, and push fallback | Contract now; provider later |
| Playback session state | universal session snapshot with receiver-authoritative actual state and service-authoritative membership/order | Phase 1D |
| Desired vs actual | controllers may request state optimistically but must reconcile to receiver-confirmed state | Must-have |
| Command envelope | globally unique command IDs, expected revisions, expiry, idempotency, acknowledgements, typed results | Must-have |
| Deduplication | same command delivered through LAN and cloud executes once | Must-have |
| Conflict resolution | deterministic receiver/controller/server arbitration, parental/profile restrictions, stale-command handling | Phase 1D |
| Playback transfer | two-phase prepare/ready/commit/abort; failed transfer leaves source playing | Contract now; implementation later |
| Media identity | stable media/source/resolver identity instead of raw URL as canonical state | Must-have |
| Playback tickets | receiver-bound, session-bound, short-lived, single-use, revocable, encrypted, redacted | Must-have contract |
| Continue watching | profile/media/source progress with revisions, completion rules, sync controls, and local-only behavior | P1 contract |
| Device picker | merge local and cloud device records with trust, proximity, capability, update, and permission state | P1 contract |
| Remote control | cross-network control, transfer, stop forgotten playback, remote wake, profile/device permissions | Later premium gate |
| Local-only mode | no cloud presence, no remote control, local progress unless exported, same-network paired control still works | Must-have |
| Backend components | Device Registry, Presence, Session, Command Router, State Distribution, Ticket, Notification services | Interface docs now; provider later |
| Storage model | devices, expiring presence, playback sessions, controllers, short-retention commands, progress | Interface docs now |
| Security | device-scoped tokens, rotating refresh, replay protection, rate limits, revocation, security history | Must-have before implementation |
| Privacy | minimize persisted data; settings for discovery, progress, retention, recommendations, diagnostics | Must-have |
| Observability | command latency, presence health, reconnects, handoff, conflicts, dedup, cloud/local ratio, revocation speed | Define schema before release |
| Performance | local commands <150ms, cloud preferred <500ms, state <500ms, presence <5s, recovery <3s, drift <500ms | Targets, not claims until measured |

### Volume 7: Legacy Android TV Support

| Area | Requirement | Disposition for v2.0.0.1 |
| --- | --- | --- |
| Baseline | initial Android baseline API 26; stretch lower only after certification | Must-have |
| Product principle | old TVs act as lightweight playback receivers | Must-have |
| Support tiers | fully supported, legacy optimized, experimental extended | Must-have |
| Capability over version | runtime profile, not OS version alone | Must-have |
| Device profiling | API, CPU, RAM, storage, GPU, codecs, network, remote, thermal | Phase 1/2 |
| Dynamic reclassification | low memory, storage, thermal, network, decoder failures can force constrained mode | Must-have contract |
| Legacy Receiver Mode | simplified home, direct playback, D-pad, compact EPG, phone remote | MVP target |
| Legacy home | continue watching, live now, favorites, recent, paired status, phone search, current program, settings, diagnostics | MVP target |
| Companion-first discovery | phone resolves content, TV plays secure media reference | Contract now; implementation next |
| Feature matrix | limit AI, multi-view, recording, full EPG on legacy devices | Must-have |
| Dependency governance | every dependency declares API floor, native architecture, size, memory, background behavior, shrinker needs, decoder assumptions, maintenance, TV issues | Must-have |
| Direct playback | phone must not proxy internet-hosted content | Must-have |
| Native decoding | decoded frames must not pass through Dart memory | Must-have for implementation |
| Baseline codecs | H.264/AAC/HLS/MPEG-TS/MP4/subtitles | MVP target |
| Playback fallback | decoder configuration, alternate backend, backup stream, reduced resolution, then compatibility error | Must-have contract |
| Local phone streaming | byte-range HTTP 206, expiry, tokens, cancellation | Later unless local phone file streaming is in MVP |
| Phone battery protection | no transcoding by default, efficient file reads, expiry shutdown, critical battery/thermal rejection | Required before local phone serving |
| Flutter UI optimization | no heavy blur, previews, parallax, huge posters | MVP target |
| Animation policy | essential, optional, disabled-in-legacy animation classes | MVP target |
| Widget optimization | rebuild boundaries, selectors, stable keys, long-list virtualization, artwork cancellation | MVP target |
| Focus performance | D-pad, defined focus, no full rebuilds, response targets | MVP target |
| Memory/storage | one player, small image cache, compact EPG, preserve favorites/progress | MVP target |
| Memory pressure response | clear off-screen images, stop enrichment/probing, unload optional screens, preserve playback | Must-have |
| Low-storage mode | remove temp files, reduce artwork, expire EPG, disable downloads/recording/models, preserve user state | Must-have |
| Network reliability | packet loss, bounded reconnect, backup sources, bitrate reduction, local-vs-provider failure | MVP target |
| Network recovery | bounded reconnect, failover, quality reduction | MVP target |
| Distributed EPG/search/AI | offload to phone, desktop, home node, or cloud | Contract now |
| Background work | defer heavy jobs during playback | Must-have |
| Binary optimization | ABI splits, optional modules, shrinking | Release workstream |
| Store distribution | Google Play TV, Amazon Appstore, direct APK rules and update safety | Release workstream |
| Restricted trust mode | legacy boxes receive short-lived tickets, not credentials | Must-have |
| Certification | certified, compatible, experimental, unsupported | QA workstream |
| Certification tests | install, cold start, focus, HLS/VOD, decoding, subtitles, pairing, recovery, memory, storage, sleep/wake, thermals | QA workstream |
| Performance targets | cold start <5s, cached home <2.5s, focus <100ms, LAN command <300ms, direct playback <3s where source permits | Targets until measured |
| Graceful degradation | low RAM/storage, missing codecs, weak Wi-Fi/GPU, old patch, no cloud, multicast blocked all get useful alternatives | Must-have |
| Acceptance | install, launch, D-pad, pairing, playback, memory, compact EPG, secure credentials | Use as implementation exit criteria |

### Volume 8: Modular Product Profiles

| Area | Requirement | Disposition for v2.0.0.1 |
| --- | --- | --- |
| Product profiles | Full, Standard, Lite Receiver, Embedded Receiver, Experimental Legacy | Must-have |
| Shared core | identity, auth, sessions, media ids, command protocol, security, errors, capabilities | Must-have architecture |
| Optional modules | EPG, search, AI, recording, downloads, multi-view, diagnostics, cloud continuity | Define dependency graph |
| Profile manifests | included modules, excluded modules, navigation, permissions, budgets, guarantees, support level | Must-have |
| Build-time composition | separate app entrypoints and feature bundles | Phase 1 |
| Compile-time vs runtime control | exclude heavy modules at build time; adapt remaining features at runtime | Must-have |
| Capability contract | publish playback, search, EPG, AI, resolution, decoder, cloud capabilities | Must-have |
| Dependency graph | invalid combinations blocked | Phase 1 |
| Module lifecycle | initialization cost, memory/storage budget, permissions, background tasks, shutdown, flags, fallback | Must-have |
| Shared interfaces | EPG, Search, AI providers with profile-specific implementations | Phase 1/2 |
| Delegation | task ids, timeouts, versioned results, encrypted payloads, cancellation, fallback | Contract now |
| Remote views | compact search results and EPG slices | Lite MVP |
| Feature negotiation | validate media/source/action compatibility before handoff or delegation | Must-have |
| Version compatibility | old/new controllers and receivers, optional fields, migration windows, security retirements | Must-have |
| Navigation per profile | no unavailable sections exposed | MVP target |
| UI component tiers | rich, standard, lightweight variants | Mobile UI workstream |
| Data ownership | define local, remote, sync ownership by profile | Contract now |
| Legacy modes | standalone lite, companion-assisted, receiver-only, home-node-assisted | Contract now |
| Permission minimization | constrained builds request only required permissions | Must-have |
| Binary isolation | heavy native libraries excluded from Lite/Receiver builds | Must-have |
| Release channels | Full stable, Lite stable, Receiver stable, legacy experimental, vendor-specific, internal certification | Release decision |
| Store strategy | single adaptive app vs Full/Lite apps vs device-targeted delivery | Release decision |
| Account experience | one account and entitlement model across editions | Later |
| Upgrade/downgrade migration | preserve account, favorites, recent, progress, device pairing, essential settings | Contract now |
| Reliability boundaries | profile guarantees and exclusions | Must-have |
| Testing | module, composition, cross-profile, protocol compatibility, delegation failure tests | QA workstream |
| Packaging | recommend Airo TV, Airo TV Lite, Airo Receiver | Release decision |

### Volume 9: Analytics and Privacy Telemetry

| Area | Requirement | Disposition for v2.0.0.1 |
| --- | --- | --- |
| Principle | measure product outcomes, not private media | Must-have |
| Data minimization | category and bucket values over raw text | Must-have |
| Non-blocking | analytics never delays playback or UI | Must-have |
| Vendor independence | no direct Firebase calls in feature modules | Must-have |
| Architecture | typed events, privacy filter, consent gate, buffer, providers | Phase 1 |
| Domains | acquisition, onboarding, usage, playback quality, device ecosystem, subscription, reliability | Define schemas incrementally |
| Event taxonomy | stable snake_case names with schema versions | Must-have |
| Envelope | installation id, session id, platform, profile, app version, consent | Must-have |
| Installation ID | random anonymous ID, resettable, not advertising ID/MAC/serial/fingerprint | Must-have |
| Media privacy | safe, restricted, prohibited classifications | Must-have |
| Prohibited data | stream URLs, signed URLs, M3U URLs, credentials, auth headers, cookies, local IPs, file paths, raw voice/search, playlist contents | Must-have |
| AI analytics | no raw queries; use intent category, confidence bucket, processing location | Later but contract now |
| Pairing/handoff | measure completion and failure without media title or URL | MVP target |
| Legacy telemetry | device tier, memory pressure, decoder fallback, delegated search | MVP target |
| Product-edition analytics | reduced event set for Lite and Embedded Receiver | Must-have |
| Consent model | separate operational, product analytics, crash reporting, personalized analytics | Must-have |
| Privacy controls | analytics, crash reporting, personalized recs, viewing sync, AI cloud, diagnostics upload, reset ID | Must-have |
| Manual screen tracking | semantic screen events; avoid automatic route names and content titles | Must-have |
| Offline queue | bounded, priority-based, delete optional events after opt-out | Phase 1 |
| Upload scheduling | defer during buffering, memory pressure, overheating, metered network, low battery, constrained mode, recording/import | Must-have |
| Playback KPIs | time to first frame, join failure rate, rebuffer ratio, failover recovery, decoder failure | MVP target |
| Feature adoption | eligible users, exposure, first use, success, repeat use, failure, retention correlation | Contract now |
| User properties | subscription tier, product profile, platform category, device tier, consent, cloud/local-only state only | Must-have |
| Crash reporting | redacted stack/native crash data grouped by version, profile, decoder, device tier | P1 contract |
| SDK selection | Firebase optional adapter; self-hosted/no-op/local diagnostics supported | Must-have architecture |
| Schema registry | owner, purpose, retention, allowed/prohibited params, dashboard need, tests | P1 contract |
| Retention | raw product/crash 30-90 days, aggregates by policy, voice/query/media IDs not collected by default | P1 policy |
| Data access | least privilege, audited, revocable, separated environments | P1 policy |
| Experimentation | stable assignment, eligibility, guardrails, kill switch, no security/deceptive subscription tests | P1 contract |
| Remote config | rollout, education, thresholds, legacy triggers, sampling; cannot override consent/security/build/entitlement | P1 contract |
| Sampling | sample high-frequency UI/network events; never sample purchase/security/revocation/severe crash/corruption/deletion | P1 contract |
| Dashboards | executive, playback, legacy, ecosystem, subscription | Later |
| Alerts | playback, crash, memory, pairing, handoff, subscription, EPG, protocol mismatch | Later reliability phase |
| Tests | schema, redaction, consent, queue, sampling, reset, provider outage, privacy patterns, disabled/local-only modes | Must-have before analytics release |

## v2.0.0.1 Acceptance Cut

v2.0.0.1 should be considered ready when the team has:

- saved and reviewed the full source PRD;
- approved the scope cut between Now, Next, and Later;
- documented product profiles and capability boundaries;
- documented the Lite Receiver MVP and legacy-device certification path;
- documented optional cloud orchestration boundaries, device identity,
  presence, command/session revisioning, playback tickets, remote permissions,
  and local-only behavior;
- documented legacy Android TV support tiers, API 26 baseline policy, runtime
  device profile, Legacy Receiver Mode, dependency governance, restricted trust,
  and device certification gates;
- documented product profile manifests, module lifecycle manifests,
  composition validation, delegation, remote views, profile navigation, release
  channels, and cross-profile compatibility testing;
- documented analytics event contracts, consent/local-only behavior,
  prohibited fields, schema registry, bounded queues, crash redaction, retention,
  experimentation guardrails, and provider independence;
- opened implementation issues with deterministic use cases and automation
  flows;
- confirmed the release-line base is latest `origin/main`;
- recorded the tag policy decision: `v2.0.0.1` is a planning milestone label,
  while public Git release tags remain semantic v2 tags such as `v2.0.0`,
  `v2.0.1`, and `v2.1.0`.

## Requirement Conflicts and Corrections

- The source says "no analytics by default" and later proposes Google Analytics.
  Resolution: analytics must be consent-gated, vendor-neutral, and disabled by
  local-only mode. Firebase can only be an adapter.
- The source lists broad content protocols. Resolution: start with the existing
  BYOC M3U/Xtream path and expand sources only after credential, storage, and
  compliance contracts exist.
- The source asks for AI everywhere. Resolution: legacy TVs must not bundle
  heavy AI runtimes; AI routes through companion, desktop, home node, cloud, or
  rules fallback.
- The source asks for maximum Android reach. Resolution: support is constrained
  by device certification and security, not by Flutter compatibility alone.
- The source includes recording/timeshift and multi-view. Resolution: defer
  until storage, rights, background execution, billing, and platform policy are
  reviewed.
- The source lists exact performance goals for all devices. Resolution: split
  targets by product profile; legacy devices prioritize stable playback over
  rich UI.
- Volume 6 proposes cloud remote control, but the product is local-first.
  Resolution: cloud orchestration is optional, provider-neutral, and must never
  be required for same-network control or receiver-direct playback.
- Volume 6 needs command and progress sync, but privacy rules prohibit raw
  media data. Resolution: store stable media/source IDs and redacted state, not
  full URLs, credentials, provider passwords, or unpermissioned viewing titles.
- Volume 7 aims for maximum device reach, but reach cannot override security or
  reliability. Resolution: API 26 is the starting baseline; lower versions and
  weak devices remain Experimental until dependency, media, security,
  distribution, and real-device certification gates pass.
- Flutter compatibility does not prove TV readiness. Resolution: certification
  must include hardware decoding, D-pad focus stability, memory pressure, low
  storage, long playback, network recovery, and secure storage evidence.
- Volume 8 could be misread as runtime feature flags only. Resolution:
  compile-time exclusion and runtime capability control are separate gates;
  runtime flags must never expose modules absent from the build.
- Volume 8 recommends multiple product editions, but separate listings can
  confuse users. Resolution: choose the store strategy only after validating
  binary size, device targeting, account entitlements, support cost, and update
  policy.
- Volume 9 allows Firebase-backed analytics, but Firebase is not the
  architecture. Resolution: all feature modules use the vendor-neutral
  analytics contract; Firebase, self-hosted, local diagnostics, and no-op are
  adapters.
- Current placeholder analytics can include raw channel names. Resolution:
  debug analytics must not be promoted to production until typed schemas and
  prohibited-field tests reject raw media identifiers.

## Implementation Blockers

- No GitHub issue number is attached to this request.
- No physical Android 8/9 test-device inventory is documented here.
- No product decision exists for separate app listings vs targeted delivery.
- No approved subscription and billing provider path is documented.
- No analytics provider adapter has been selected, and selection should not
  precede the shared analytics contract.
- No analytics schema registry, consent implementation, bounded queue,
  crash-redaction contract, or retention policy exists yet.
- Existing playback debug analytics can include channel names and must be
  replaced or blocked before production telemetry.
- No cloud orchestration provider or backend ownership model has been selected,
  and selection should not precede the Volume 6 service boundary.
- No device identity, revocation, playback-ticket, or command-dedup threat
  model is documented yet.
- No Android 8/9 physical certification inventory is documented yet.
- No dependency governance audit proves the effective API 26 floor yet.
- No Legacy Receiver Mode contract or certification automation exists yet.
- No product profile manifest or module lifecycle manifest schema exists yet.
- No composition validator or cross-profile compatibility suite exists yet.
- No release-channel or store-listing decision exists for Airo TV, Airo TV Lite,
  and Airo Receiver.
- No legal/compliance review is attached for Stalker Portal, recording,
  timeshift, or provider-specific integrations.
