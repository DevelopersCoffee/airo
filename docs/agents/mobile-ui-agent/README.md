# Mobile UI Agent

The Mobile UI Agent is the canonical UI/UX owner for Airo mobile shell
surfaces. It owns shell chrome, navigation presentation, header ownership
policy, shared mobile layout standards, and the governance documents that keep
feature teams from making independent shell decisions.

## Scope

The Mobile UI Agent is the primary owner for:

- shell-level app chrome in `app/lib/core/app/*`
- shared route presentation and destination affordances
- mobile header ownership rules
- shared mobile visual standards and density guardrails
- shared asset usage rules for shell imagery and iconography
- native-first interaction standards for Android and iOS shell behavior
- narrow-screen overflow and hamburger/menu policy

The Mobile UI Agent reviews, but does not solely own:

- shared theme token foundations in `packages/core_ui`
- cross-cutting shell/runtime contracts with `agent/core-architecture`
- docs updates that change repo-wide workflow guidance

## Boundaries

Feature screens own feature content and local task flows. They do not own:

- the global shell header
- a second native or local header layered beneath the global shell header
- the primary destination model
- shell branding asset selection
- breakpoint-wide navigation behavior

If a feature needs contextual chrome, it must declare that need through the
shared shell configuration and ADR-backed route ownership rules.

## UX Direction

The shared mobile UX direction is:

- AI-first productivity, not chat-first novelty
- calm, professional, and dense without clutter
- progressive disclosure instead of stacked controls
- one clear header owner per route state
- centralized navigation and asset decisions
- native Android and iOS interaction patterns before custom chrome

Google AI Edge Gallery-style usability, accessibility, and platform alignment
are the preferred foundation. Deliberately harsh or brutalist treatments are
not the default for product surfaces.

## Required Inputs Before Implementation

Every Mobile UI issue must include:

- a completed Critical Agent Gate
- route ownership impact and affected shell surfaces
- deterministic use cases for mobile and large-screen behavior
- widget or route-flow automation coverage expectations
- explicit ownership when shell code and feature screens both change

## Governance Artifacts

- UI standards: [../../standards/mobile-ui-ux-standards.md](../../standards/mobile-ui-ux-standards.md)
- ADR: [../../adr/0006-mobile-ui-governance-and-shell-ownership.md](../../adr/0006-mobile-ui-governance-and-shell-ownership.md)
- Task tracker: [./TASKS.md](./TASKS.md)
- Phase plan: [./UIUX_PHASE_PLAN_2026-06.md](./UIUX_PHASE_PLAN_2026-06.md)

## Current Execution Issues

- `#415` UIUX-005: Native-first mobile shell UX rollout
- `#417` UIUX-006: Enforce single-header ownership and compact shell chrome
- `#418` UIUX-007: Centralize navigation overflow and hamburger policy
- `#416` UIUX-008: Centralize shell assets and route density hygiene
