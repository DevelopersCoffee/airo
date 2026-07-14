# Airo TV Volume 3 Gap Analysis

**Source:** `/Users/udaychauhan/.codex/attachments/a839c12f-79ec-42ca-a6de-bd73735f03f1/pasted-text.txt`  
**Date:** 2026-07-13  
**Scope:** Cross-platform architecture, connected devices, local-first pairing,
Flutter engineering, shared playback, sync, and adaptive UI.

## Executive Summary

Volume 3 moves Airo TV from a TV app into a connected media platform. The
current repository has useful pieces for that direction: a modular Flutter
workspace, Android TV entrypoint, Riverpod feature modules, IPTV playback,
basic TV focus widgets, local AI packages, and some sync metrics. It does not
yet have the core contracts Volume 3 depends on: connected node identity,
capability advertisement, local discovery, secure pairing, versioned command
protocols, shared session management, local-first state sync, or a
backend-agnostic playback engine.

The biggest planning correction is that "pairing and handoff" is too small as a
single backlog item. It needs to become a platform foundation track before the
Lite Receiver MVP can claim companion control, local AI delegation, trusted
devices, handoff, or cross-device sync.

## Current Repository Fit

| Requirement area | Current evidence | Fit |
| --- | --- | --- |
| Modular Flutter app | `melos.yaml`, `app/lib/main_tv.dart`, packages under `packages/` | Partial |
| Android TV shell | `app/lib/main_tv.dart`, `app/lib/core/tv`, `packages/feature_iptv/lib/presentation/tv` | Partial |
| IPTV playback | `packages/platform_player`, `packages/platform_media`, `video_player` backend | Partial |
| TV focus/navigation | `app/lib/core/tv/tv_focusable.dart`, IPTV TV screen focus wrappers | Partial |
| AI provider/model plumbing | `packages/core_ai`, `app/lib/core/ai`, IPTV edge-intelligence provider | Partial |
| Sync metrics | `app/lib/core/sync/sync_metrics.dart` | Minimal |
| Device discovery | No mDNS/DNS-SD/WebSocket dependencies found in app/package pubspecs | Missing |
| Secure pairing/trust | No connected-device pairing, trust store, revocation, or permission model found | Missing |
| Command protocol | Cast sender/proxy code exists, but no Airo local secure command envelope | Missing |
| Cross-platform playback engine | `IPTVStreamingService` exists, but it is channel-centric and video_player-specific | Missing |
| Local-first state sync | Outbox/metrics exist, but no trusted-device encrypted sync contract | Missing |

## Major Gaps

### 1. Connected Node Model Is Missing

Volume 3 requires every installation to advertise itself as a node with
capabilities such as playback, display, voice input, keyboard input, local AI,
media indexing, storage, remote control, diagnostics, recording, transcoding,
and metadata processing.

Current state:
- `core_ai` has device and AI model capability concepts.
- `feature_iptv` has hardcoded IPTV-specific execution context capabilities.
- The plan has a generic `DeviceCapabilities` row, but it does not yet cover
  node identity, capability freshness, privacy-safe advertising, or permission
  boundaries.

Gap:
- No shared `AiroNode`, `NodeCapability`, `CapabilityAdvertisement`, or
  `CapabilitySnapshot` contract.
- No lifecycle states for Available, Pairing, Connected, Busy, Sleeping,
  Offline, Incompatible, Update required, or Connection blocked.
- No separation between advertised non-sensitive metadata and authenticated
  private state.

Planning impact:
- Add a P0 connected-node protocol before QR pairing or phone remote work.

### 2. Local Discovery Transport Is Not Present

Volume 3 specifies local-first discovery using mDNS/DNS-SD with service
`_airotv._tcp`, local advertising/browsing, duplicate merging, stale-device
handling, local-network permission explanations, and fallback behavior.

Current state:
- No mDNS/DNS-SD, Zeroconf, Bonsoir, multicast DNS, or WebSocket dependency was
  found in app/package pubspec files.
- Existing Cast code is not a replacement because it targets cast sessions and
  media proxy behavior, not Airo node discovery.

Gap:
- No platform abstraction for discovery.
- No local service metadata schema.
- No discovery state machine.
- No iOS local-network permission UX.
- No privacy filter for broadcast metadata.

Planning impact:
- Discovery must be framework-owned and testable with fake adapters before any
  companion UX depends on it.

### 3. Secure Pairing and Trust Management Are Undefined

Volume 3 requires QR code pairing, numeric code pairing, same-account approval,
local confirmation, ephemeral session keys, mutual authentication, replay
protection, trusted-device storage, key rotation, revocation, and per-device
permissions.

Current state:
- The v2 plan lists "Pairing and handoff" and "QR pairing" but does not define
  trust lifecycle or permission scope.
- `core_data` includes secure-storage dependencies, but no Airo connected-device
  trust store was found.

Gap:
- No `TrustedDevice` model.
- No pairing challenge/response protocol.
- No session key rotation or expiry policy.
- No permission model for remote control, text input, voice, playback handoff,
  profile access, parental changes, or remote wake.
- No trusted-device management screen requirements.

Planning impact:
- Pairing cannot be scoped as UI only. It is a security contract shared by
  framework, media, profile, parental-control, and AI agents.

### 4. Local Command Protocol Is Missing

Volume 3 defines a versioned message envelope with protocol version, message ID,
session ID, source/target IDs, timestamp, type, payload, command category, and
deterministic command result states.

Current state:
- `platform_player` has Cast-related request/session models.
- `cast_http_proxy.dart` exposes local HTTP proxy behavior for cast workflows.
- There is no Airo-owned local command bus for secure phone-to-TV control.

Gap:
- No command envelope schema.
- No idempotency or replay protection.
- No command result taxonomy: Accepted, Completed, Rejected, Failed, Timed out,
  Unsupported, Permission required.
- No version negotiation.
- No command categories for playback, navigation, text, AI, and device control.

Planning impact:
- Phone remote, keyboard input, voice routing, handoff, and multi-device control
  should all use this protocol instead of direct feature calls.

### 5. Session Management Is Not Defined

Volume 3 defines separate session types for remote control, playback, AI
assistance, playlist transfer, handoff, multi-room, and admin. It also defines
multi-controller conflict rules and text-input locks.

Current state:
- Existing state is mostly feature-local: IPTV providers, player state, Cast
  state, sync metrics.
- No shared session coordinator was found.

Gap:
- No session ownership, expiry, sensitive re-authentication, or conflict policy.
- No UI contract for showing which controller is active.
- No recovery model after network loss.
- No deterministic command ordering when multiple controllers send input.

Planning impact:
- Add `core_sessions` as a real foundation package in the v2 plan, with fakes
  and tests before remote UI is built.

### 6. Playback Abstraction Is Too Narrow

Volume 3 requires a platform playback abstraction with open, play, pause, stop,
seek, volume, tracks, subtitles, playback speed, quality, diagnostics,
backend-specific implementations, detailed states, and typed error categories.

Current state:
- `packages/platform_player/lib/src/services/iptv_streaming_service.dart`
  defines `IPTVStreamingService` around IPTV channels.
- `packages/platform_media/lib/src/video_player_streaming_service.dart`
  implements that service using `video_player`.
- It has useful buffer metrics, live-edge detection, manual retry, and quality
  switching, but it does not expose a generalized `PlaybackEngine`.
- The implementation explicitly avoids automatic retry after errors.

Gap:
- No backend-agnostic engine interface.
- No typed `MediaOpenRequest` that can represent IPTV, file, SMB/WebDAV, RTSP,
  HLS, DASH, local preview, or protected playback.
- No track enumeration/selection contract beyond current quality controls.
- No diagnostics contract for decoder, codec, DRM/protection, audio/subtitles,
  network, and backend state.
- No formal error categories matching the PRD.
- No backup stream failover policy contract.

Planning impact:
- Treat the existing IPTV streaming service as an implementation candidate, not
  the shared platform contract.

### 7. AI Routing Is Not Connected-Device Aware

Volume 3 requires AI tasks to route by model availability, memory, thermal
state, battery, playback load, privacy, latency, and task complexity across
devices.

Current state:
- `core_ai` has local model/provider abstractions and runtime capability checks.
- `app/lib/core/ai/ai_router_service.dart` handles app-level AI provider status.
- `feature_iptv` has IPTV-specific edge intelligence and a hardcoded TV
  execution context.

Gap:
- No cross-device AI capability advertisement.
- No routing to phone, desktop, home node, or cloud based on connected-node
  state.
- No policy for preserving playback resources while AI runs.
- No per-task fallback matrix for search, recommendations, summaries, and
  voice commands.

Planning impact:
- Premium AI readiness must depend on connected-node and session contracts, not
  only on `core_ai` model work.

### 8. Handoff and State Sync Are Not Implementation-Ready

Volume 3 requires handoff, mirror, remote display, continue later, position
preservation, validation before stopping source playback, encrypted incremental
state sync, conflict detection, retries, timestamps, and logical versioning.

Current state:
- `app/lib/core/sync/sync_metrics.dart` tracks generic sync metrics.
- `core_data` has offline repository/outbox concepts.
- There is no Airo TV state schema for profiles, favorites, watch history,
  playlist metadata, EPG mappings, parental rules, device preferences, AI
  preferences, or trusted devices.

Gap:
- No `SyncRecord` schema for Airo media state.
- No conflict-resolution policy per data type.
- No trusted-device encrypted sync protocol.
- No handoff preflight validation.
- No rollback behavior when destination playback fails.

Planning impact:
- Handoff should be split into two deliverables: command/session preflight and
  state continuity.

### 9. Adaptive UI Contract Is Incomplete

Volume 3 requires UI adaptation by device category, input mode, viewing
distance, pointer/touch/remote, window size, orientation, density, and
accessibility, not width alone.

Current state:
- TV focus widgets and TV IPTV screens exist.
- Product profile planning exists.

Gap:
- No shared `InteractionMode` or `FormFactorProfile` contract.
- No routing of UI density, typography, focus behavior, and pointer/touch/remote
  modes through a common design-system layer.
- No desktop/tablet shell readiness for Volume 3.

Planning impact:
- Add an adaptive UI mode contract to the plan so TV, mobile companion, tablet,
  and desktop do not fork behavior inconsistently.

### 10. Platform Validation Matrix Is Missing

Volume 3 expects Android/Android TV, iOS/iPadOS, macOS, Windows, Linux, and
Apple TV to be treated as separate validation surfaces.

Current state:
- The plan has a legacy Android certification matrix.
- It does not yet include cross-platform discovery, pairing, playback,
  background work, permission, and storage validation.

Gap:
- No platform matrix for local-network permissions, background advertisement,
  secure storage, playback backend, file access, model downloads, and
  companion-control behavior.

Planning impact:
- v2.0.0.1 should explicitly target Android mobile + Android TV first, then
  mark desktop/tablet as contract-compatible but out of the first MVP unless
  resourced.

## Required Plan Changes

These items should be added to the v2.0.0.1 plan:

| Priority | Plan addition | Reason |
| --- | --- | --- |
| P0 | Connected node protocol | Foundation for discovery, pairing, AI routing, sync, and handoff |
| P0 | Local discovery abstraction | Required before any phone remote or companion workflow |
| P0 | Secure pairing/trust model | Required for local control without exposing credentials or state |
| P0 | Versioned command envelope | Prevents remote, handoff, text input, and AI control from becoming feature-specific hacks |
| P0 | PlaybackEngine contract | Existing IPTV service is not broad enough for Volume 3 |
| P1 | Session coordinator | Required for multiple controllers, text input locks, expiry, and recovery |
| P1 | Local encrypted sync schema | Required before cross-device profiles/history/favorites claims |
| P1 | Adaptive UI mode contract | Prevents separate TV/mobile/desktop behavior models |
| P1 | Cross-platform validation matrix | Makes platform promises testable |

## Recommended v2.0.0.1 Scope Adjustment

Keep v2.0.0.1 as a foundation milestone, but make its MVP target explicit:

1. Android phone + Android TV are the first connected-device pair.
2. Local discovery, QR pairing, trusted-device storage, and remote playback
   commands are in scope as contracts and fakes.
3. Full desktop, tablet, Apple TV, multi-room, multi-view, recording,
   transcoding, and local LLM delegation remain later phases.
4. Existing IPTV playback remains the first backend, but all new work should
   call a future `PlaybackEngine` interface.
5. AI features should be routed through connected-node capability contracts
   before they can claim phone/desktop/home-node delegation.

## Acceptance Gaps To Add

- A phone can discover a TV node on the same LAN using a fake and one real
  platform adapter.
- Discovery metadata contains no playlist URLs, profile names, credentials,
  viewing history, or device secrets.
- Pairing creates an expiring trusted-device relationship with scoped
  permissions.
- Revoking trust immediately blocks new commands from that device.
- A playback command uses the versioned command envelope and returns a typed
  result.
- Standalone TV playback works when discovery, pairing, AI routing, or cloud
  sync are unavailable.
- The player contract can be tested without a Flutter widget tree or a specific
  backend.
- Handoff never stops source playback until destination preflight succeeds.
- Local-only mode disables cloud relay/sync without disabling same-LAN control.

## Final Assessment

Volume 3 is directionally aligned with the modular V2 repository, but it exposes
a deeper platform gap than the current plan captured. The project should not
start by building phone remote screens. It should first define connected-node,
discovery, pairing, session, command, playback, and sync contracts, then build
the Lite Receiver and companion workflows on top of those contracts.
