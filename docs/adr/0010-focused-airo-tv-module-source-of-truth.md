# ADR-0010: Focused Airo TV Module Source of Truth

## Status

Accepted

## Date

2026-07-22

## Context

Airo TV is being developed as a focused product that also lives inside the
larger Airo app. During Pixel 9 testing, the standalone IPTV build could show
channels but did not expose the XMLTV guide-source workflow because that
surface was reachable only through the full Airo Settings hub.

That split caused agents to implement or validate behavior in one shell while
missing another shell. It also made Pro TV overlay planning ambiguous: the
public app had an open-core bootstrap seam, but focused Airo TV entrypoints did
not consistently prove the same startup contract.

## Decision

The focused Airo TV module is the source of truth for Airo TV behavior.

Reusable Airo TV behavior belongs in `feature_iptv` and the relevant
`platform_*` / `core_*` packages. App entrypoints may wire providers, routes,
startup tasks, theme defaults, and shell chrome, but they must not own Airo TV
business behavior.

Essential standalone workflows, including playlist source, XMLTV guide source,
playback settings, and diagnostics, must be reachable from the focused Airo TV
surface. They may also appear in full Airo Settings, but full Airo Settings is
not allowed to be the only access path.

Every Airo TV behavior change must check the parity contract across:

- standalone phone IPTV (`main_airo_iptv.dart`)
- TV / Fire TV (`main_tv.dart`)
- full Airo embedding (`main.dart`)
- web validation profiles
- open-core `airo_pro_bootstrap` overlay seam
- build profile metadata (`app/pubspec_*.yaml` and
  `.github/airo-build-profiles.json`)

Native bootstrap code must be conditional-imported or adapter-backed when a
web-validation path imports the same public entrypoint.

## Consequences

### Positive

- Focused Airo TV work can be developed and tested without depending on the
  full Airo shell.
- Full Airo consumes the same Airo TV feature/platform code instead of
  reimplementing behavior.
- Future Pro TV overlays have a stable public bootstrap seam.
- Agents have a concrete parity checklist before declaring Airo TV work done.

### Negative

- Entry-point changes need slightly more validation because standalone, TV,
  full Airo, and web profiles can differ.
- Shared bootstrap code may require conditional adapters to stay web-safe.

### Risks

- Agents may still add a shortcut in `app/lib` for speed. Reviews must reject
  app-owned Airo TV behavior unless it is pure shell wiring.
- Build-profile metadata can drift unless every plugin/runtime dependency is
  updated with the code that introduced it.

## Alternatives Considered

### Full Airo Settings As The Source Of Truth

Rejected. It breaks standalone Airo TV and makes focused product development
dependent on the super-app shell.

### Duplicate Workflows Per Entrypoint

Rejected. It creates drift across phone IPTV, TV, full Airo, and Pro overlay
builds.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Modular Package Structure
- [ADR-0008](0008-storage-tiering-and-preference-size-guards.md) - Storage
  Tiering and Preference Size Guards
