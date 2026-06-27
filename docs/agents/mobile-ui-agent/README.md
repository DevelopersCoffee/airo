# Mobile UI Agent

The Mobile UI Agent owns shell chrome, navigation presentation, header
ownership policy, shared mobile layout standards, and the governance documents
that keep feature teams from making independent shell decisions.

## Scope

The Mobile UI Agent is the primary owner for:

- shell-level app chrome in `app/lib/core/app/*`
- shared route presentation and destination affordances
- mobile header ownership rules
- shared mobile visual standards and density guardrails
- shared asset usage rules for shell imagery and iconography

The Mobile UI Agent reviews, but does not solely own:

- shared theme token foundations in `packages/core_ui`
- cross-cutting shell/runtime contracts with `agent/core-architecture`
- docs updates that change repo-wide workflow guidance

## Boundaries

Feature screens own feature content and local task flows. They do not own:

- the global shell header
- the primary destination model
- shell branding asset selection
- breakpoint-wide navigation behavior

If a feature needs contextual chrome, it must declare that need through the
shared shell configuration and ADR-backed route ownership rules.

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

## Current Execution Issues

- `#398` UIUX-002: Consolidate shell and page header ownership
- `#399` UIUX-003: Centralize theme tokens and navigation configuration
- `#400` UIUX-004: Centralize shell asset management and chrome hygiene
