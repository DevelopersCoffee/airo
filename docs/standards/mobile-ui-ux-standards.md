# Mobile UI / UX Standards

## Purpose

This document defines the default ownership and implementation standards for
mobile shell UI in Airo. Shared shell concerns must be configured centrally so
feature screens do not create their own competing navigation, header, token, or
branding rules.

## Ownership Rules

Shared UI code owns:

- shell chrome
- route-to-header configuration
- primary destination metadata
- responsive navigation behavior
- shared shell asset registration
- shared design token roles

Feature screens own:

- screen body content
- local task interactions
- contextual subviews inside their content area
- feature-specific empty states and copy

Feature screens must not:

- add a competing shell app bar on a shell-managed route
- hardcode new primary destinations outside shared navigation config
- invent shared shell asset paths locally
- redefine shared spacing, color, or typography roles ad hoc

## Header Ownership Standard

For any visible route state, exactly one layer owns the top header:

- shell-owned header for root destinations
- route-owned contextual header for approved nested flows
- no visible header for immersive/fullscreen flows

A route must explicitly opt into contextual or immersive behavior through
shared configuration. Feature widgets should not silently render their own top
app bars when mounted under shell-owned destinations.

## Navigation Standard

Navigation metadata must come from one source of truth that includes:

- route id
- label
- icon pair or token reference
- destination path
- shell visibility behavior
- overflow eligibility on narrow screens

Primary destination overflow on phones must be handled centrally. Feature code
must consume the shared navigation model instead of constructing its own bottom
navigation items.

## Token Standard

Shared visual roles belong in centralized tokens, including:

- background surfaces
- text emphasis levels
- accent and status colors
- spacing scale
- corner radius scale
- shell elevation and divider treatments

Application code may compose these tokens, but should not mint new shell-wide
roles unless the shared token contract is updated first.

## Asset Standard

Shell-level logos, icons, illustrations, and shared imagery must be referenced
through a shared registry, constant set, or equivalent accessor layer.

Allowed behavior:

- feature code consumes named shared assets
- shell branding updates happen in one shared location

Disallowed behavior:

- duplicate raw asset paths spread across widgets
- feature-local copies of shell iconography
- ad hoc branding changes inside screen files

## Verification Expectations

Follow-up Mobile UI implementation issues should include:

- widget or route tests for header ownership behavior
- widget tests for navigation overflow or destination rendering
- static verification that shared assets are resolved through central accessors
- documentation updates when the shared contract changes

## Related Work

- Governance epic: `#397`
- Header ownership implementation: `#398`
- Theme and navigation centralization: `#399`
- Shell asset centralization: `#400`
