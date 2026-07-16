---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-007: Personalized IPTV Home and Recommendations'
labels: 'agent/mobile-ui, agent/media, P2, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** A redesigned personalized home is a product-surface change, not release hardening. Current v2 should keep the BYOC setup and IPTV surfaces stable while improving reliability, large playlist performance, search, cache, and TV accessibility.

## What To Keep From The Community Request

- Continue Watching and Recently Watched are useful after history/watch-progress contracts are stable.
- EPG-driven "starting soon" rails can be useful for favorites.
- Recommendations should be local and explainable before AI ranking is considered.

## What Not To Build In Current V2

- No app home redesign.
- No cross-device recommendation state.
- No AI-generated recommendations.
- No "Trending Now" unless sourced only from local user playlist/EPG data.
- No new landing page or marketing-style dashboard.

## Future Feature Packet Gate

**Problem:** Users want faster re-entry into recent and favorite IPTV content.
**User / actor:** Returning IPTV user.
**Framework or application layer:** Application.
**Owning agent:** Mobile UI Agent.
**Reviewing agents:** Media Agent, QA Automation Agent, Security and Privacy Agent.
**Impacted modules/files:** `packages/feature_iptv`, `packages/platform_history`, `packages/platform_favorites`, `packages/platform_epg`, possibly app home.
**Base branch/worktree:** Must be reconfirmed from latest `origin/v2` when reopened.
**Open questions:** Whether this belongs inside IPTV tab only or app-wide home.
**Decision:** Blocked until product surface and navigation owner approve.

## Future Cross-Agent Contract Required

**Provider agent:** Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Recent/favorite/upcoming rail data providers.
**Input shape:** Local history, favorites, EPG snapshot, playlist records.
**Output shape:** Ordered rail items with action targets.
**State changes:** Local rail preferences only.
**Errors:** Empty history, missing EPG, stale playlist record.
**Permissions:** No new permissions.
**Privacy/redaction:** Personalization stays local.
**Persistence:** Local history/favorites only.
**Versioning/migration:** No cloud dependency.
**Tests required:** Empty state, rail ordering, TV focus, no overflow.

## Reopen Criteria

- CV-006 local search and current history/favorites contracts are stable.
- Product owner chooses IPTV-scoped rail versus app-wide home change.
- First slice is limited to Continue Watching or Recently Watched.
