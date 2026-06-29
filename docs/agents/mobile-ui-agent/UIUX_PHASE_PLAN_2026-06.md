# Mobile UI Agent Phase Plan

## Objective

Standardize Airo mobile UI/UX so shell decisions do not get re-litigated in
feature work. The rollout should enforce one header owner, centralized
navigation and asset configuration, and native-first space-efficient patterns.

## Planning Frame

**Problem:** Duplicate header surfaces, uneven use of local `AppBar`s,
overcrowded top-level navigation, and ad hoc shell asset usage reduce usable
space and create inconsistent behavior.

**User / actor:** Mobile users across core Airo destinations and engineers
shipping UI changes.

**Framework or application layer:** Mixed

**Owning agent:** agent/mobile-ui

**Reviewing agents:** agent/core-architecture, agent/qa-testing, agent/docs

**Base branch/worktree:** Must start from latest `origin/main`

## Issue Queue

- `#415` Parent rollout and sequencing
- `#417` Single-header ownership and compact shell chrome
- `#418` Shared navigation overflow and hamburger policy
- `#416` Shell assets and route density hygiene

## Workstreams

### 1. Header and Chrome Consolidation

- remove duplicate global and local header stacking
- define shell-owned, route-owned, and immersive route states
- reduce top chrome height where actions can move to overflow
- verify auth/profile/system actions remain reachable

### 2. Navigation and Overflow Governance

- centralize primary destination metadata
- cap narrow-screen primary navigation to a sustainable action budget
- route lower-frequency destinations through shared overflow or hamburger entry
- preserve large-screen adaptations without forking route ownership rules

### 3. Visual Token and Density Governance

- define spacing, radius, color, and typography roles centrally
- remove shell-level magic numbers from product surfaces
- keep the UI professional, calm, and information-dense
- favor speed and clarity over decorative motion

### 4. Asset and Iconography Governance

- route shell imagery through a single registry
- prevent duplicate raw asset paths across features
- define when logos, illustrations, and badges are allowed in shell surfaces
- align icons with native conventions before custom treatments

### 5. Verification and Rollout

- add widget or route tests for header ownership and overflow behavior
- add static checks or audits for centralized asset usage
- migrate feature surfaces incrementally instead of redesigning the whole app at once
- track follow-up work as focused child issues, not one long-running mega-task

## Definition of Ready

Before implementation work starts, each issue must include:

- Critical Agent Gate
- explicit owner and reviewing agents
- deterministic use cases for phone and larger-screen layouts
- automation flows for the changed shell behavior
- rollback or migration notes

## Definition of Done

- UX behavior is driven by centralized config, not feature-local shell widgets
- exactly one top header is visible for every route state
- primary navigation is consistent across the app at the same breakpoint
- shell assets resolve through shared accessors
- tests cover route ownership and overflow behavior
