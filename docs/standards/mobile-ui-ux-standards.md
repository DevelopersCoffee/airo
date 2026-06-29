# Mobile UI / UX Standards

## Purpose

This document defines the default ownership and implementation standards for
mobile shell UI in Airo. Shared shell concerns must be configured centrally so
feature screens do not create their own competing navigation, header, token, or
branding rules.

The product direction is AI-first productivity, not chat-first novelty. The UI
should feel calm, professional, trustworthy, and fast.

## Design Principles

- simplicity over decoration
- speed over animations
- information density without clutter
- progressive disclosure instead of stacked controls
- native Android and iOS interaction patterns first
- accessibility by default
- offline-first user experience

Google AI Edge Gallery-style usability and platform alignment are the preferred
baseline. Experimental visual treatments may exist in isolated surfaces, but
they do not define shared shell behavior.

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
- layer a Flutter header beneath a native header or vice versa
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

Global and native top chrome must resolve to one visible surface. The app must
not consume vertical space with both a shell header and a second local or
platform header unless the route is explicitly designed as a split-pane or
stacked editing flow.

Header action rules:

- root destinations keep a compact action budget
- secondary actions move to shared overflow before header height increases
- auth/profile/system actions remain reachable from shared shell affordances
- feature-specific actions should prefer contextual menus, sheets, or inline
  actions over permanently expanding top chrome

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

Navigation rules by breakpoint:

- phones: use bottom navigation only for the highest-frequency destinations
- phones: move lower-frequency primary destinations into shared overflow or
  hamburger entry when the action budget is exceeded
- tablets and large screens: adapt with rail or drawer, but keep the same
  destination registry and ownership rules
- all breakpoints: avoid nested navigation deeper than three levels unless the
  route is a clearly bounded task flow

The shell should prefer one predictable overflow model over multiple competing
menus.

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

Do not hardcode shell typography sizes or spacing values in screen files.
Platform typography should be used by role, not by ad hoc number selection.

Minimum shared hierarchy:

- screen title
- section header
- body
- secondary description
- metadata
- caption

Monospace is reserved for logs, code, technical metadata, and terminal-like
surfaces. It is not a default product typeface.

## Asset Standard

Shell-level logos, icons, illustrations, and shared imagery must be referenced
through a shared registry, constant set, or equivalent accessor layer.

Allowed behavior:

- feature code consumes named shared assets
- shell branding updates happen in one shared location
- feature screens import `ShellAssetRegistry` when they need shell-owned imagery

Disallowed behavior:

- duplicate raw asset paths spread across widgets
- feature-local copies of shell iconography
- ad hoc branding changes inside screen files
- direct references such as `assets/hermes/images/filler-bg0.jpg` outside the shared asset registry

Shell imagery rules:

- decorative artwork must justify the space it consumes
- shell surfaces should prefer icons and hierarchy over large banners
- icons should follow native platform expectations before custom illustration
- shared branding changes must be achievable from one registry layer

## Space and Density Standard

The shell must treat vertical space as constrained on phones.

Required behavior:

- avoid double headers
- avoid redundant section titles that repeat the shell title
- move infrequent actions into overflow before adding more persistent chrome
- use tokenized spacing scales instead of one-off padding values
- prefer sheets, drawers, and expandable sections for secondary controls

Disallowed behavior:

- permanent top-level banners without strong product value
- six or more equal-priority bottom tabs on phones
- route roots that repeat title, subtitle, and actions already shown in shell

## Platform Adaptation Standard

- Android should align to Material 3 tokens and interaction patterns
- iOS should align to Human Interface Guidelines and native navigation
  expectations
- light and dark mode should respect system appearance by default
- platform adaptation must not fork the information architecture without a
  shared contract decision

## Verification Expectations

Follow-up Mobile UI implementation issues should include:

- widget or route tests for header ownership behavior
- widget tests for navigation overflow or destination rendering
- static verification that shared assets are resolved through central accessors
- documentation updates when the shared contract changes

## Related Work

- Governance docs: `docs/agents/mobile-ui-agent/README.md`
- ADR: `docs/adr/0006-mobile-ui-governance-and-shell-ownership.md`
- Phase plan: `docs/agents/mobile-ui-agent/UIUX_PHASE_PLAN_2026-06.md`
