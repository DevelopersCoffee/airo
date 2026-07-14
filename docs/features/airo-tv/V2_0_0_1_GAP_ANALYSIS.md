# Airo TV v2.0.0.1 Gap Analysis

**Status:** Draft  
**Date:** 2026-07-13  
**Source PRD:** `/Users/udaychauhan/.codex/attachments/c09e8ca7-61d7-4a52-b71d-0d2a24998c55/pasted-text.txt`  
**Planning docs:** `docs/features/airo-tv/V2_0_0_1_PLAN.md`, `docs/features/airo-tv/V2_0_0_1_REQUIREMENTS_REVIEW.md`, `docs/features/airo-tv/V2_0_0_1_FEATURE_PACKET.md`  
**Review method:** Static repository review plus PRD requirement comparison. No code tests were run.

## Executive Summary

Airo already has a useful media foundation for a V2 Airo TV Lite path:

- Android TV entrypoint: `app/lib/main_tv.dart`
- BYOC M3U import and local cache: `packages/platform_playlist_import`
- IPTV channel model and rule-based classification: `packages/platform_channels`
- TV browsing screen and 10-foot UI shell: `packages/feature_iptv`
- local playback abstraction using `video_player`: `packages/platform_media`, `packages/platform_player`
- Cast sender/controller contracts: `packages/platform_player`
- local recent history: `packages/platform_history`
- TV focus utilities: `app/lib/core/tv`
- AI/device capability primitives: `packages/core_ai`

The gaps are not small polish gaps. The PRD asks for an AI-powered, privacy-first,
multi-profile media operating system across TVs, mobile, desktop, and legacy
receivers. The current codebase is closer to a BYOC IPTV app with early TV and
Cast support.

The immediate recommendation is to make v2.0.0.1 a foundation milestone:
product profiles, capability contracts, encrypted source storage, receiver
pairing/playback tickets, analytics abstraction, and legacy certification. Full
AI search, voice, recommendations, catch-up, cloud sync, recording, and
multi-source media integrations should remain out of the first implementation
slice.

## Gap Severity

| Level | Meaning | Release impact |
| --- | --- | --- |
| P0 | Blocks safe implementation of Airo TV MVP | Must resolve before implementation or launch claim |
| P1 | Required for first useful Lite/TV release | Can be sequenced after P0 contracts |
| P2 | Premium or expansion capability | Defer until MVP proves activation and playback reliability |

## Current Coverage Snapshot

| Capability | Current state | Evidence | Gap |
| --- | --- | --- | --- |
| Android TV entrypoint | Partial | `app/lib/main_tv.dart` initializes a TV-only entrypoint and registers IPTV | No product profile manifest or Lite/Full/Receiver split |
| BYOC no-default-content posture | Partial/good | `M3UParserService.fetchPlaylist` returns empty when no playlist URL exists | Debug playlist seeding must stay release-safe |
| M3U import | Partial/good | M3U fetch, URL validation, parsing, dedupe, cache exist | Cache and source URL use SharedPreferences, not encrypted storage |
| Xtream support | Missing | No code references beyond docs | PRD MVP says M3U and Xtream |
| Jellyfin/Plex/Emby/SMB/WebDAV/DLNA | Missing | No provider adapters found | Defer behind source adapter contract |
| Playlist intelligence | Partial | Rule-based category inference and dedupe exist | No health checks, EPG matching, metadata repair, logo fetching, AI classification |
| TV UI | Partial | `IptvTvScreen` has TV shell, search dialog, categories, player panel, recent filter | Not profile-aware; no compact EPG, pairing status, diagnostics, or receiver modes |
| D-pad/focus | Partial | `TvFocusable`, TV focus utilities, TV screen buttons | No certification flow or latency/perf assertions |
| Playback | Partial | `VideoPlayerStreamingService`, Cast media adapter, `video_player` dependency | No Media3/native decoder inventory, codec fallback matrix, bounded retry policy, or certification |
| Cast | Partial | Cast controller, Cast request model, local HTTP proxy | This is Cast sender support, not secure Airo receiver pairing/handoff |
| Voice search | Stub | `MockVoiceSearchService` returns empty results | No platform speech recognition, permission model, or AI routing |
| AI search/recommendations | Experimental/partial | Edge IPTV assistant can parse intents through rule/native backend | Not integrated as product search; no privacy contract, model lifecycle, or companion delegation |
| Profiles | Missing | No Airo TV profile model found | Adult/kids/guest/sports profiles not implemented |
| Parental AI | Missing | No profile restriction engine found | Requires security/family-safety review |
| Favorites/recent | Partial | `platform_history` stores recent channels locally; `platform_favorites` package exists | Favorites/profile sync and cross-device progress missing |
| EPG | Minimal | `platform_epg` package exists | No compact current/next EPG contract or ingestion path found |
| Cloud sync | Missing | app has core sync folder but no Airo TV sync contract | PRD cloud sync requires encrypted metadata-only sync |
| Analytics | Missing | No `firebase_analytics` dependency or shared `AnalyticsService` found | Must design before measuring success metrics |
| Monetization | Missing | No billing dependency found | Premium model is only conceptual |
| Legacy certification | Missing | No certification docs/tests/devices in Airo TV area | Required before Android 8/9 support claims |

## P0 Gaps

### GAP-001: Product Profiles Are Not Implemented

**Requirement:** Full TV, Standard TV, Lite Receiver, Embedded Receiver, and
Experimental Legacy profiles with build-time and runtime feature control.

**Current state:** The repo has a TV entrypoint and feature registry, but no
typed product profile model, no capability manifest, and no composition tests.

**Impact:** Without profiles, legacy support becomes scattered conditionals. It
also becomes possible for runtime flags to expose features that are absent,
unsafe, or too heavy for a device.

**Required work:**
- Add `ProductProfile` and `DeviceCapabilities` contracts.
- Add per-profile feature manifests.
- Add composition validation for included modules, permissions, navigation, and
  native dependencies.
- Define Lite Receiver guarantees and exclusions.

**Owner:** Framework Agent with Media Agent and Release and DevEx review.

### GAP-002: Source Secrets Are Not Protected Enough

**Requirement:** Credential storage, encrypted storage, secure keychain, and
privacy-first handling of user-owned playlists.

**Current state:** M3U playlist URL and cached playlist data are persisted in
SharedPreferences. M3U URLs often embed usernames, passwords, tokens, or signed
URLs. Recent history also stores channel objects locally.

**Impact:** This is a privacy and security blocker for broad BYOC support,
especially Xtream, provider credentials, and legacy Android devices.

**Required work:**
- Move content source secrets to `core_data` secure storage or a dedicated media
  source vault.
- Separate safe local metadata from secret values.
- Add redaction helpers for logs, crashes, analytics, and support bundles.
- Define deletion/export flows for playlist URL, cache, recent, favorites, and
  profile data.

**Owner:** Security and Privacy Agent with Framework Agent.

### GAP-003: Receiver Pairing and Playback Tickets Are Missing

**Requirement:** Legacy TVs should pair securely, receive direct playback
references or short-lived playback tickets, and avoid storing full credentials
when restricted.

**Current state:** Cast sender abstractions exist, but there is no Airo device
pairing, QR pairing, trust model, playback-ticket contract, or receiver-only
mode.

**Impact:** The Lite Receiver and Embedded Receiver product profiles cannot be
implemented safely. Companion-assisted search and handoff remain conceptual.

**Required work:**
- Define `TrustedDevice`, `PairingSession`, `PlaybackTicket`, and
  `ReceiverTrustMode`.
- Add QR pairing flow and revocation.
- Add capability negotiation before playback handoff.
- Ensure restricted receivers never receive full provider credentials.

**Owner:** Framework Agent and Security and Privacy Agent with Media Agent.

### GAP-004: Analytics Architecture Is Missing

**Requirement:** Typed analytics events, consent gate, privacy filter, no-op
provider, optional vendor adapters, playback quality telemetry, and prohibited
field validation.

**Current state:** No shared analytics package or `firebase_analytics`
dependency was found. The PRD success metrics cannot be measured safely yet.

**Impact:** Adding Firebase directly later would violate the PRD's vendor-neutral
and privacy-first architecture. Without analytics, activation, playback success,
pairing success, and legacy stability cannot be measured.

**Required work:**
- Add a vendor-neutral `AnalyticsService` contract.
- Add typed event schemas for onboarding, playback, pairing, handoff, and
  legacy mode.
- Add consent/local-only mode and bounded event queue.
- Add automated prohibited-field tests for URLs, headers, credentials, search
  text, voice transcripts, local paths, and media titles.

**Owner:** Framework Agent and Security and Privacy Agent.

### GAP-005: Xtream Is In MVP Requirements But Not Implemented

**Requirement:** Phase 1 PRD says BYOC playlist support includes M3U and Xtream.

**Current state:** M3U exists. Xtream provider adapters, credential storage,
API models, EPG handling, and tests are absent.

**Impact:** The PRD MVP cannot be claimed as delivered if Xtream remains absent.

**Required work:**
- Decide whether Xtream is in the first code MVP or deferred from v2.0.0.1.
- If included, define an encrypted credential model and API client.
- Add deterministic tests with mocked Xtream endpoints.
- Keep all provider URLs and credentials out of analytics/logs.

**Owner:** Media Agent with Security and Privacy review.

### GAP-006: Legacy Certification Program Is Not Operational

**Requirement:** Android 8/9 support, device tiers, memory budgets, D-pad
navigation, codec certification, long playback, low-storage, and network
recovery testing.

**Current state:** There are docs and some TV code, but no Airo TV certification
matrix, no physical device inventory, no benchmark gates, and no pass/fail
records.

**Impact:** The product cannot responsibly claim Android 8/9 support.

**Required work:**
- Create certification matrix and device inventory.
- Define Certified, Compatible, Experimental, Unsupported outcomes.
- Add smoke automation for install, launch, D-pad, playback, pairing, network
  recovery, memory pressure, and low storage.
- Require physical Android TV/Fire TV evidence for certification.

**Owner:** QA Automation Agent with Release and DevEx.

## P1 Gaps

### GAP-007: Playback Backend Is Not Yet Legacy-Grade

**Requirement:** Native hardware decoding, codec inventory, HLS/MPEG-TS/MP4
baseline, fallback strategy, network recovery, and strict memory behavior.

**Current state:** `video_player` is available and streaming services exist, but
there is no codec inventory, no product-profile decoder policy, no backend
fallback chain, and no long-session certification.

**Required work:**
- Add playback capability scanner.
- Define supported stream/container/codec matrix per profile.
- Add bounded retry/failover policy.
- Add startup latency and rebuffer metrics once analytics exists.

### GAP-008: Compact EPG Is Not Built

**Requirement:** Lite receivers need current and next program data without full
XMLTV parsing or long EPG history.

**Current state:** `platform_epg` exists, but no compact EPG repository,
ingestion path, delegated EPG slice, or UI integration was found.

**Required work:**
- Define `CompactEpgRepository`.
- Store only visible/current/next windows for Lite.
- Add fallback UI when EPG is unavailable.
- Add delegated EPG slice contract for phone/desktop/home node.

### GAP-009: Search Is Basic, Not AI-First

**Requirement:** Natural-language and semantic search by team, actor, event,
country, genre, quality, language, time, and mood.

**Current state:** TV search filters channel name and group. Edge intelligence
has a natural-language assistant, but it is not the product search contract and
does not solve privacy, delegation, or legacy constraints.

**Required work:**
- Define `SearchProvider` interface: local prefix, local indexed, companion,
  cloud, and composite.
- Keep raw query local unless explicit cloud AI is enabled.
- Add result ranking and result-count/intent telemetry without query text.

### GAP-010: Voice Search Is Only A Stub

**Requirement:** Hold remote button and speak naturally.

**Current state:** `MockVoiceSearchService` simulates states and returns empty
results.

**Required work:**
- Define per-platform speech provider.
- Add microphone permission model and TV remote input policy.
- Route recognized text through the privacy-safe search provider.
- Add fallback to phone voice input for Lite Receiver.

### GAP-011: Profiles, Kids Mode, and Parental Controls Are Missing

**Requirement:** Adult, kids, guest, sports, movies, anime profiles with
favorites, history, restrictions, recommendations, watch progress, and voice
profile; AI parental rules later.

**Current state:** No Airo TV profile storage or restriction engine found.

**Required work:**
- Define `MediaProfile`, `ProfileRestriction`, and `ProfileStorage`.
- Separate profile-scoped history/favorites from device-level history.
- Add PIN/lock and kids-safe navigation before AI parental control.

### GAP-012: Cloud Sync and Multi-Device Continuity Are Missing

**Requirement:** Optional encrypted sync for profiles, favorites, history,
settings, and playlist metadata; never upload videos, credentials, viewing
habits, or voice recordings by default.

**Current state:** No Airo TV cloud sync contract or cross-profile sync was
found.

**Required work:**
- Define sync data classes and privacy categories.
- Add encrypted metadata-only sync contract.
- Add conflict resolution for favorites/progress/profiles.
- Add local-only mode.

### GAP-013: Subscription and Premium Entitlements Are Missing

**Requirement:** Free and Premium tiers with AI features, cloud sync,
multi-device, no ads, recording, timeshift, themes, widgets, and playlist
cleanup.

**Current state:** No billing dependency or entitlement model was found.

**Required work:**
- Decide billing platforms by product: Google Play, Amazon, Apple, web, or
  deferred.
- Add entitlement contract independent of product edition.
- Avoid gating core playback behind premium.

## P2 Gaps

| Gap | Why defer |
| --- | --- |
| AI catch-up summaries | Needs captions/transcripts, model routing, privacy review, and quality evaluation |
| Live match finder | Needs event metadata, EPG/event matching, stream health ranking, and legal-safe copy |
| Recommendations | Needs profile/history contract and privacy-safe local signals |
| Recording and timeshift | Needs storage, rights, background execution, device capacity, and app store policy review |
| Multi-view | Needs decoder-count profiling and TV-specific performance budget |
| Rich premium UI/themes/widgets | Should wait until Lite/Standard profile boundaries are stable |
| Jellyfin/Plex/Emby/SMB/WebDAV/DLNA | Requires source adapter contract, credential storage, and per-provider tests |
| Stalker Portal | Requires explicit legal/compliance approval before engineering |

## Module-by-Module Gap View

| PRD module | Status | Main gap |
| --- | --- | --- |
| Module 1: Content Sources | Partial | M3U only; secure storage and Xtream/provider adapters missing |
| Module 2: Playlist Intelligence | Partial | Dedup/category exists; health, EPG, metadata, AI classification missing |
| Module 3: Voice AI | Missing | Stub only; no platform speech or AI command route |
| Module 4: AI Search | Partial/experimental | Basic search and edge assistant exist; no product search provider contract |
| Module 5: Live Match Finder | Missing | No event/EPG/team matching or stream ranking |
| Module 6: AI Catch-Up | Missing | No captions/transcripts/summarization path |
| Module 7: Recommendations | Missing | No local recommendation engine or profile signals |
| Module 8: Smart EPG | Missing/early | No compact/full EPG implementation path |
| Module 9: Profiles | Missing | No media profile model or profile-scoped storage |
| Module 10: Parental AI | Missing | Needs non-AI restrictions first |
| Module 11: Video Player | Partial | Basic player exists; broad codec/native fallback/certification missing |
| Module 12: Smart Channel Health | Missing | No latency/bitrate/availability probing or auto-failover |
| Module 13: Offline AI | Partial foundation | core AI exists; TV-safe AI routing and profile gating missing |

## Recommended Implementation Sequence

### Step 1: Lock Scope and Security Boundaries

- Decide whether v2.0.0.1 is docs-only, contract-only, or includes a Lite
  Receiver code MVP.
- Use the recorded version naming policy: `v2.0.0.1` is a planning milestone
  label, and public Git release tags remain semantic v2 tags.
- Move source secrets out of SharedPreferences before adding Xtream or provider
  credentials.
- Define prohibited analytics/log/crash fields now.

### Step 2: Build Profile and Capability Foundation

- Add `ProductProfile`, `DeviceCapabilities`, feature manifests, and
  composition tests.
- Define Lite Receiver navigation and excluded modules.
- Ensure runtime flags cannot expose absent build-time modules.

### Step 3: Build Lite Receiver MVP

- Keep the initial TV scope narrow: BYOC source, direct playback, D-pad UI,
  recent/favorites, basic search, compact EPG placeholder, diagnostics, and
  fallback errors.
- Add QR pairing and playback-ticket contract only after security review.
- Validate on physical Android TV/Fire TV devices.

### Step 4: Add Measurement Safely

- Add analytics abstraction with no-op provider first.
- Add onboarding, playback, pairing, handoff, and legacy-mode events.
- Reject URLs, credentials, raw queries, voice text, local paths, and media
  titles in tests.

### Step 5: Expand Intelligence

- Add search provider contract.
- Route voice/search through local, companion, home-node, or cloud providers.
- Add recommendations and catch-up only after profiles, history, privacy, and
  model routing are stable.

## Immediate Backlog

| ID | Priority | Backlog item | Owner |
| --- | --- | --- | --- |
| GAP-001 | P0 | Add ProductProfile and DeviceCapabilities contract issue | Framework Agent |
| GAP-002 | P0 | Replace playlist URL/cache secret storage strategy | Security and Privacy Agent |
| GAP-003 | P0 | Define pairing, trust, and playback-ticket issue | Framework Agent |
| GAP-004 | P0 | Define AnalyticsService and prohibited fields issue | Framework Agent |
| GAP-005 | P0 | Decide Xtream inclusion for first MVP | Media Agent |
| GAP-006 | P0 | Create legacy device certification matrix | QA Automation Agent |
| GAP-007 | P1 | Define playback backend and codec fallback matrix | Media Agent |
| GAP-008 | P1 | Define compact EPG repository and UI slice | Media Agent |
| GAP-009 | P1 | Define SearchProvider contract | AI Agent |
| GAP-010 | P1 | Replace mock voice search with platform provider plan | AI Agent |
| GAP-011 | P1 | Define media profile and restriction model | Media Agent |
| GAP-012 | P1 | Define encrypted cloud sync contract | Framework Agent |
| GAP-013 | P1 | Define premium entitlement model | Release and DevEx Agent |

## Go/No-Go Assessment

**Go for:** Airo TV Lite planning, profile/capability contracts, secure storage
work, BYOC M3U hardening, compact TV shell improvements, and analytics
abstraction.

**No-go for now:** Full Airo TV PRD launch, AI-first marketing claims, Android
8/9 support claims, cloud sync, premium subscriptions, recording/timeshift,
multi-view, Stalker Portal, and broad provider integrations.

The highest-leverage next move is not adding another visible feature. It is
closing the P0 platform gaps so the product can safely expand without weakening
privacy, compliance, or legacy-device reliability.
