---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-003: Account Pairing and Device Migration'
labels: 'agent/framework, P2, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** QR pairing, account migration, token transfer, and license restoration are not required for v2 BYOC release hardening. This work depends on account, entitlement, cloud sync, secure token exchange, and device management decisions that are not accepted for the current milestone.

## What To Keep From The Community Request

- TV setup should avoid long remote-control typing.
- Short-code or QR setup is a strong future onboarding pattern.
- Migration must be explicit and user-approved.
- Token payloads must be short-lived, scoped, encrypted/signed, and revocable.
- Provider replacement is a separate but related user need: favorites, history, guide mappings, and smart playlist rules should survive when a user imports a replacement playlist.

## What Not To Build In Current V2

- No account pairing flow.
- No license migration or premium-device sharing.
- No device-count enforcement.
- No WebSocket pairing service.
- No transfer of playlist credentials.

## Future Feature Packet Gate

**Problem:** Users need a low-friction way to set up TV devices and survive provider replacement without rebuilding their local TV experience.
**User / actor:** User adding a TV client after configuring Airo on mobile/desktop, or user replacing an unreliable provider playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Framework Agent.
**Reviewing agents:** Security and Privacy Agent, Media Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `packages/core_pairing`, `packages/core_auth`, `packages/core_entitlements`, `packages/core_cloud_orchestration`, `packages/feature_iptv`.
**Base branch/worktree:** Must be reconfirmed from latest `origin/main` when reopened.
**Open questions:** Pairing transport, token lifetime, transfer payload fields, credential exclusion, entitlement policy, canonical channel match strategy for provider replacement.
**Decision:** Blocked until identity and entitlement contracts are approved.

## Future Cross-Agent Contract Required

**Provider agent:** Framework Agent.
**Consumer agent:** Media Agent.
**Interface/API:** Pairing session service, payload serializer, verifier, entitlement sync boundary, future provider replacement matcher.
**Input shape:** Pairing request, one-time code/QR token, approved migration fields, old/new canonical channel candidates.
**Output shape:** Accepted/rejected pairing result, migrated local state, and future match confidence results.
**State changes:** Local device registration and optional account/device record.
**Errors:** Expired code, replayed token, mismatched account, revoked device, payload validation failure.
**Permissions:** Network/account only after explicit user action.
**Privacy/redaction:** Playlist credentials excluded unless separate encrypted backup is approved.
**Persistence:** Local pairing state and optional account device list.
**Versioning/migration:** Pairing payload schema version required.
**Tests required:** Expiry, replay protection, redaction, revoke, failure UI.

## Reopen Criteria

- Cross-device sync scope is accepted.
- Entitlement/device policy is approved.
- Security review accepts token exchange design.
- First slice is limited to non-secret settings/favorites migration.
- CV-017 smart playlist and canonical channel identities are implemented before provider replacement is attempted.
