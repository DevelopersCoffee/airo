---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-013: Household Profiles and Parental Controls'
labels: 'agent/mobile-ui, agent/framework, P2, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** Household profiles require identity/profile schema, parental restriction policy, PIN recovery, data separation, and possibly sync behavior. Current v2 should not add profile semantics while hardening BYOC playback and performance.

## What To Keep From The Community Request

- Shared TVs need profile-aware favorites/history eventually.
- Parental controls should be local-first and explicit.
- Restricted categories must be deterministic and user-configured, not inferred from provider content.
- PIN recovery and lockout behavior must be specified before build.

## What Not To Build In Current V2

- No profile selector.
- No PIN gate.
- No profile-scoped favorites/history migration.
- No parental category classification.
- No profile cloud sync.

## Future Feature Packet Gate

**Problem:** Shared household devices need separated watch state and optional local restrictions.
**User / actor:** Household admin and household viewer.
**Framework or application layer:** Mixed.
**Owning agent:** Mobile UI Agent.
**Reviewing agents:** Framework Agent, Security and Privacy Agent, Media Agent, QA Automation Agent.
**Impacted modules/files:** `packages/core_auth`, `packages/platform_favorites`, `packages/platform_history`, `packages/feature_iptv`.
**Base branch/worktree:** Must be reconfirmed from latest `origin/main` when reopened.
**Open questions:** Profile schema owner, PIN storage/recovery, content-tag source, data migration, sync interaction.
**Decision:** Blocked until profile and restriction contracts are approved.

## Future Cross-Agent Contract Required

**Provider agent:** Framework Agent.
**Consumer agent:** Mobile UI Agent and Media Agent.
**Interface/API:** Active profile provider, profile-scoped repositories, parental control evaluator.
**Input shape:** Profile id, channel/group metadata, user restriction settings, PIN challenge.
**Output shape:** Allowed/blocked result, profile-scoped favorites/history state.
**State changes:** Local profile records, local profile-scoped media state.
**Errors:** Missing profile, wrong PIN, recovery unavailable, stale migration.
**Permissions:** No new permissions.
**Privacy/redaction:** Profile state remains local unless future sync explicitly includes it.
**Persistence:** Local profile store.
**Versioning/migration:** Migration from global state to default profile required.
**Tests required:** Default profile migration, scoped history/favorites, PIN checks, blocked UI.

## Reopen Criteria

- Product owner accepts household profile UX.
- Security owner accepts PIN storage/recovery model.
- First slice is default profile migration or profile-scoped history only.
