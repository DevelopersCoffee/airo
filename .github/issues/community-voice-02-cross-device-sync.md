---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-002: Cross-Device State and Cloud Sync'
labels: 'agent/framework, P2, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** The current v2 milestone is Play Store-safe BYOC IPTV hardening. Cloud sync adds account identity, backend selection, conflict resolution, credential redaction, retention/deletion policy, and security review. It is valuable, but it should not block v2 release readiness.

## What To Keep From The Community Request

- Users want setup-once behavior across TV, mobile, and desktop.
- Favorites, hidden groups, watch progress, resume points, and settings are the right sync candidates.
- Playlist credentials must be redacted by default.
- Offline queueing and deterministic conflict handling are required before implementation.

## What Not To Build In Current V2

- No Firebase/Firestore sync implementation.
- No account-required IPTV setup.
- No cloud copy of playlist URLs or credentials.
- No device-to-device state sync.
- No subscription/license sharing behavior.

## Future Feature Packet Gate

**Problem:** Users with multiple devices need consistent IPTV preferences and resume state.
**User / actor:** Signed-in Airo TV user who explicitly opts into sync.
**Framework or application layer:** Mixed.
**Owning agent:** Framework Agent.
**Reviewing agents:** Security and Privacy Agent, Media Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `packages/core_cloud_orchestration`, `packages/core_auth`, `packages/platform_favorites`, `packages/platform_history`, `packages/platform_playlist`, `packages/feature_iptv`.
**Base branch/worktree:** Must be reconfirmed from latest `origin/main` when reopened.
**Open questions:** Backend provider, encryption model, account requirement, deletion/export policy, playlist credential handling.
**Decision:** Blocked until product/security design is accepted.

## Future Cross-Agent Contract Required

**Provider agent:** Framework Agent.
**Consumer agent:** Media Agent.
**Interface/API:** Local mutation log, sync coordinator, conflict resolver, redaction policy.
**Input shape:** Local state mutations for favorites, history, settings, profile-scoped data, playlist references.
**Output shape:** Sync result, conflict result, redacted remote payload, local replay state.
**State changes:** Local queue and optional remote account state.
**Errors:** Offline, auth expired, conflict, quota, remote delete, redaction failure.
**Permissions:** Account/network only after explicit user opt-in.
**Privacy/redaction:** Playlist credentials are never synced unless a separate explicit full-backup feature is approved.
**Persistence:** Local queue plus remote encrypted/sanitized sync state.
**Versioning/migration:** Sync schema version and rollback plan required.
**Tests required:** Conflict resolution, offline replay, deletion, redaction, opt-out cleanup.

## Future Deterministic Use Cases

### UC-001: Opt-in sync
**Actor:** Signed-in user.
**Preconditions:** User has local IPTV state.
**Trigger:** User enables sync.
**Happy path:** Redacted state uploads and another device receives it.
**Failure paths:** Auth failure or redaction failure blocks upload.
**Data created/updated/deleted:** Local queue and remote sync state.
**Privacy expectations:** Credentials are not uploaded by default.

### UC-002: Offline mutation replay
**Actor:** User changing favorites while offline.
**Preconditions:** Sync is enabled but network is unavailable.
**Trigger:** User toggles favorites and later reconnects.
**Happy path:** Queue replays in order and resolves conflicts deterministically.
**Failure paths:** Conflict is recorded and visible to the user.
**Data created/updated/deleted:** Local mutation queue and remote sync state.
**Privacy expectations:** Only approved fields sync.

## Reopen Criteria

- Account and privacy design is approved.
- Backend choice is accepted.
- Redaction and deletion behavior is specified.
- Sync scope is split into a small first slice, such as favorites plus resume points only.
