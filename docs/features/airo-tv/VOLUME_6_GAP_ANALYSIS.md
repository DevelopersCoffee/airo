# Airo TV Volume 6 Gap Analysis

**Volume:** Cloud Playback Orchestration, Device Presence, Remote Control, and
Continuity  
**Date:** 2026-07-13  
**Status:** Draft gap analysis  
**Input:** Volume 6 pasted requirements attachment  
**Baseline inspected:** current repository docs, Firebase bootstrap/auth,
generic sync/outbox, IPTV Cast models/providers, and existing Airo TV planning
docs.

## Executive Summary

Volume 6 extends the Airo TV architecture from same-network connected devices
to optional cloud-assisted orchestration. The strongest product constraint is
that the cloud coordinates trusted devices, commands, state, presence, and
continuity; it must not become a media proxy, credential vault for provider
passwords, or a hard dependency for same-network playback.

The current repository has useful adjacent building blocks:

- Firebase bootstrap and Google auth exist in the app layer.
- `core_data` has generic offline-first outbox/sync patterns.
- `platform_player` and `feature_iptv` have Cast-style device discovery,
  session snapshots, and play/pause/volume flows.
- Prior Airo TV plans already define local discovery, trusted-device pairing,
  route ownership, media routing, native media, performance, and product
  profiles.

Those pieces are not enough for Volume 6. There is no Airo-owned cloud
orchestration boundary, device registry, presence service, secure persistent
command channel, universal playback-session state, command deduplication,
two-phase cloud handoff, secure playback-ticket service, remote-control
authorization policy, or local/cloud device merge contract.

## Requirement Intent

Volume 6 requires a hybrid model:

| Area | Required behavior |
| --- | --- |
| Controller | Sends playback intent, displays device/session state, supports remote control and transfers, but never assumes it owns receiver playback reality. |
| Orchestration service | Registers devices, tracks presence, routes commands, syncs state, arbitrates conflicts, handles revocation, and distributes snapshots without proxying video. |
| Receiver | Validates authorized commands, resolves source access locally or through scoped tickets, fetches media directly, and remains authoritative for playback state. |
| Media source | Supplies media directly to the receiver: IPTV, VOD, FAST, NAS, SMB, Plex/Jellyfin/Emby, cloud storage, desktop node, or local server. |

The routing policy is local-first:

1. Authenticated direct LAN channel.
2. Authenticated peer-to-peer path when available.
3. Cloud WebSocket relay for commands/state only.
4. Push/reconnect fallback.

Same-network playback must keep working when the cloud is unavailable.

## Current Repo Fit

| Current asset | Fit | Gap |
| --- | --- | --- |
| Firebase app initialization and Google auth | Useful account bootstrap for cloud-backed features | No device-scoped tokens, registry, presence, revocation, or session authorization model |
| `core_data` outbox/sync | Useful offline queue pattern | Not command routing, real-time presence, state revisioning, or cloud session reconciliation |
| `AiroCastDevice` / `AiroCastSessionSnapshot` | Useful early local playback-control vocabulary | No stable device identity, trust state, capabilities, session revision, command IDs, conflict policy, or cloud reachability |
| `IptvCastNotifier` | Useful Cast flow for connect/load/play/pause/volume | No desired-vs-actual model, idempotent command envelope, result lifecycle, remote permissions, or multi-controller arbitration |
| Existing Volume 3/4 plans | Already cover local discovery, pairing, ownership, routing, and handoff preflight | Need to extend contracts so local and cloud routes deduplicate and reconcile instead of becoming separate systems |
| Existing analytics plan | Privacy-filtered event direction exists | No Volume 6 metrics for command latency, presence lease health, revision conflicts, handoff completion, revocation speed, or cloud-to-local route ratio |

## Major Gaps

### 1. Cloud Orchestration Boundary

**Requirement:** Define a cloud service that coordinates devices, commands,
presence, state, transfer, authorization, protocol versions, offline expiry,
recovery, push fallback, audit, and revocation.

**Current state:** No Airo TV cloud orchestration module, service interface, or
backend contract exists. Current Firebase usage is app bootstrap/auth, not an
Airo playback control plane.

**Gap:** Add a framework-owned boundary before implementation. It must state
what the cloud may coordinate and explicitly prohibit media proxying,
transcoding, stored video, plaintext provider passwords, and exposing raw media
URLs to unrelated devices.

### 2. Device Identity, Registration, and Trust Lifecycle

**Requirement:** Stable device records with account ID, device ID, type,
platform, app/protocol version, capabilities, trust state, secure keys,
rename/revoke/reset, duplicate detection, key rotation, and security alerts.

**Current state:** Cast devices have transient ID/name/host fields. Generic
device information is used for diagnostics and AI capability checks, but not as
a secure Airo TV identity.

**Gap:** Define `AiroDeviceRecord`, `DeviceRegistration`, device key storage,
scoped refresh tokens, reinstall/reset behavior, duplicate handling, revocation
timing, and trusted-device review.

### 3. Presence and Connection Lifecycle

**Requirement:** Presence states such as Online, Available, Playing, Paused,
Buffering, Busy, Sleeping, Backgrounded, Offline, Unreachable, and Update
Required, backed by expiring leases and adaptive heartbeats.

**Current state:** The repo has generic social/user presence references and Cast
discovery states, but no Airo TV device-presence model.

**Gap:** Add presence leases, heartbeat rules, background behavior by platform,
privacy-safe visibility, local/cloud merge semantics, and stale-state handling.

### 4. Secure Persistent Command Channel

**Requirement:** Secure WebSocket or future HTTP/3 channel with auth,
synchronization, degraded/reconnecting states, missed-event recovery, duplicate
event rejection, credential refresh, exponential backoff, and push wake fallback.

**Current state:** No Airo TV secure WebSocket transport, command relay, or push
provider integration is present.

**Gap:** Define transport interfaces and fakes before choosing the provider.
The channel must be optional for same-LAN playback.

### 5. Universal Playback Session State

**Requirement:** Canonical playback state with session revision, active receiver
and controller IDs, media identity, status, position, live offset, rate, volume,
tracks, timestamps, and reporter. Receiver is authoritative for playback
reality; orchestration service is authoritative for session lifecycle,
membership, ordering, and permissions.

**Current state:** `AiroCastSessionSnapshot` stores phase, device, media, error,
and volume only.

**Gap:** Define `PlaybackSessionState`, `PlaybackRevision`,
`DesiredPlaybackState`, `ActualPlaybackState`, and snapshot/replay behavior.
Controllers may show optimistic UI only until reconciled by receiver state.

### 6. Command Model, Results, Ordering, and Deduplication

**Requirement:** Commands need globally unique IDs, target session/device,
sender identity, action, payload, expected revision, issue/expiry timestamps,
idempotency, acknowledgement, duplicate suppression, stale rejection, and typed
results: Accepted, In Progress, Completed, Rejected, Expired, Failed,
Unsupported, Conflict, Auth Required, and Receiver Unavailable.

**Current state:** Cast provider calls controller methods directly and uses a
local generation counter to ignore stale in-process requests.

**Gap:** Add a versioned command envelope that works across local LAN and cloud
relay. The same command delivered over both paths must execute once.

### 7. Multi-Controller Ownership and Conflict Resolution

**Requirement:** One active receiver, multiple controllers with scoped
permissions, deterministic conflict rules, profile and parental restrictions,
server arbitration for transfer ownership, and stale-command conflict handling.

**Current state:** No multi-controller membership or permission model exists for
Airo TV sessions.

**Gap:** Define session membership, controller roles, elevated auth actions,
parental/profile filters, restart semantics, and progress conflict rules.

### 8. Two-Phase Playback Transfer

**Requirement:** Transfer uses prepare/ready/commit/abort. Source continues
until destination is ready. Failed transfer leaves source playing. VOD variance
should be under two seconds; live should preserve edge/offset.

**Current state:** Prior plans define handoff preflight, but there is no
cloud-aware transfer protocol or session ownership transfer state.

**Gap:** Extend handoff contracts with cloud-coordinated transfer phases,
receiver capability validation, source/destination state snapshots, and abort
rules.

### 9. Media Source Resolution and Secure Playback Tickets

**Requirement:** Canonical media identity should be stable
`mediaId/sourceId/sourceResolver/credentialReference`, not raw URLs. Playback
tickets must be short-lived, receiver-bound, session-bound, single-use,
revocable, encrypted in transit, and excluded from logs.

**Current state:** Cast media requests are URL-based. Existing plans mention
route tokens, but there is no ticket service contract.

**Gap:** Define playback-ticket claims, lifecycle, redaction, receiver
validation, ticket revocation, and resolver responsibilities for receiver,
controller, home node, or metadata service.

### 10. Continue Watching and Cloud Progress

**Requirement:** Progress sync across devices with profile, media, source,
position, duration, completion state, updater, and revision. Receiver persists
on pause/stop/background/transfer/completion/shutdown.

**Current state:** Some media-hub UI shows progress, and generic sync exists,
but there is no Airo TV cross-device progress schema.

**Gap:** Add progress model, conflict policy, retention controls, local-only
mode behavior, and privacy settings before enabling cloud progress sync.

### 11. Cross-Network Device Discovery and Device Picker

**Requirement:** Device picker merges local and cloud device lists, showing
type, status, availability, last active time, proximity, capabilities, update
state, permissions, and trusted names.

**Current state:** Cast discovery is local and transient.

**Gap:** Define a device merge algorithm that prefers local routes, avoids
duplicate devices, respects revocation/update-required states, and never leaks
current titles to unauthorized accounts.

### 12. Remote Network Control and Local-Only Mode

**Requirement:** Remote pause/start/transfer/stop/resume across networks is
optional and permissioned. Users need local-only mode, same-account remote mode,
approval-required mode, profile/device permissions, and platform-dependent
remote wake behavior.

**Current state:** No Airo TV remote network control setting or cloud discovery
toggle exists.

**Gap:** Add privacy and entitlement controls before implementation. Core
same-network use must not require cloud presence.

### 13. Backend Components and Storage

**Requirement:** Device Registry, Presence Service, Session Service, Command
Router, State Distribution, Playback Ticket Service, Notification Service, plus
storage for devices, expiring presence, playback sessions, session controllers,
short-retention commands, and media progress.

**Current state:** No backend service schema or storage model exists for this
domain.

**Gap:** Add backend-facing interface docs and provider-neutral schemas. Do not
lock implementation to Firebase or a custom service until latency,
connection-count, push, cost, and privacy requirements are reviewed.

### 14. Security, Privacy, and Observability

**Requirement:** Device-scoped access tokens, rotating refresh, token
revocation, session expiry, profile/device authorization, replay protection,
signatures or authenticated encryption, rate limits, security history,
redaction, abuse monitoring, user controls for cloud discovery/progress/history,
and metrics for connection, command, state, handoff, conflict, and revocation
health.

**Current state:** General auth and some privacy-oriented planning exist, but no
Volume 6-specific security or telemetry schema is defined.

**Gap:** Add Volume 6 threat model, privacy controls, prohibited fields, and
observability events before implementation.

## Plan Additions Required

Add the following to the v2.0.0.1 plan:

| Addition | Priority | Why |
| --- | --- | --- |
| Cloud orchestration boundary | P0 | Prevent cloud from becoming media path or same-LAN dependency |
| Device identity and registration contract | P0 | Required for trust, revocation, remote control, and presence |
| Presence lease model | P0 | Required for cross-device UX and remote availability |
| Universal session state and revision model | P0 | Required for controller optimism, receiver authority, and recovery |
| Command envelope/result/dedup rules | P0 | Required so LAN and cloud paths cannot double-execute commands |
| Secure playback ticket model | P0 | Required for receiver-direct playback without leaking source credentials |
| Local/cloud device merge contract | P1 | Required for device picker and cross-network discovery |
| Remote-control permission and local-only settings | P1 | Required for privacy, parental controls, and premium packaging |
| Continue-watching cloud progress model | P1 | Required for continuity without leaking viewing history by default |
| Backend service/storage interfaces | P1 | Required before choosing Firebase/custom WebSocket/provider stack |
| Push wake and notification fallback contract | P2 | Useful for remote wake, but platform-dependent |

## Acceptance Coverage Gaps

Volume 6 acceptance criteria are not currently testable. The first automation
layer should use fakes and contract tests:

- Same-LAN playback works with cloud orchestration disabled.
- A command sent over both local and cloud paths executes once.
- A revoked device loses cloud command access quickly.
- Receiver continues playback when controller disconnects.
- Receiver remains authoritative for position, buffering, decoder errors, and
  track availability.
- Cloud snapshot recovery catches a reconnecting controller up to the latest
  revision.
- Failed transfer leaves source playback running.
- Playback tickets are receiver/session-bound and are not logged.
- Local-only mode hides cloud presence and keeps progress local.
- Device picker merges one local and one cloud record into one trusted device.

## Product Packaging Impact

Volume 6 should be treated as a premium-readiness and platform-contract layer,
not a requirement to ship cloud remote control in v2.0.0.1.

Recommended split:

- **Core / free:** same-network discovery, pairing, direct receiver playback,
  local command envelope, local-only privacy mode, receiver-authoritative
  session state.
- **Premium / later gate:** remote network control, cross-network transfer,
  cloud continue watching, remote wake, multi-household activity history,
  household supervision, and cross-home playback.

## Open Questions

- Which cloud backend owns persistent connections: Firebase, a custom WebSocket
  service, managed real-time database, or another gateway?
- Is Volume 6 implementation in v2.0.0.1, or are only contracts and fakes in
  scope?
- What is the first remote-control entitlement model: same account only,
  household sharing, or explicit trusted-device invite?
- What is the exact device identity behavior on reinstall, factory reset,
  rename, key rotation, and account transfer?
- Which push providers are acceptable for Android TV, Android mobile, iOS,
  desktop, and web dashboard?
- What retention windows apply to command history, session snapshots, progress,
  security history, and diagnostics?
- Are cloud continue watching and remote network control premium by default?
- Which local-only settings are default-on in privacy-sensitive regions or child
  profiles?

## Recommendation

Fold Volume 6 into the v2.0.0.1 plan as architecture contracts and fakeable
interfaces. Do not start a production cloud relay until local-first playback,
media routing, secure pairing, playback ownership, and receiver-authoritative
state are already defined. The non-negotiable gate is simple: cloud may
coordinate playback, but the receiver must fetch media directly and same-network
playback must survive without cloud.
