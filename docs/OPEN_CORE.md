# Airo Open-Core Architecture

Airo follows the **open-core model** used by GitLab (CE/EE), Sentry, Mattermost,
and Grafana: the public repository contains the complete, generally available
product; a private overlay repository (`DevelopersCoffee/airo-pro`) contains
premium engineering that may be monetized later.

## Ground rules

1. **The public repo must always build and ship on its own.** No file in this
   repository may import, reference, or require anything that only exists in
   `airo-pro`. CI in this repo proves it.
2. **Interfaces live here, implementations live there.** Every pro capability
   is expressed as a contract in `packages/core_entitlements` plus a swap
   point in `packages/airo_pro_bootstrap`. The private repo implements the
   contracts; it never edits public feature code in place.
3. **The overlay swaps packages, not patches.** Pro builds replace
   `airo_pro_bootstrap` (and only additive `packages_pro/*` packages) via
   `pubspec_overrides.yaml` — the same mechanism this repo already uses for
   `packages/stubs`. There are no long-lived forked edits of public files, so
   upstream merges stay near-conflict-free.
4. **Pro is free for now.** The only entitlement policy shipped here is
   `LaunchPromoEntitlements` (everything enabled). When charging begins, the
   overlay swaps in a billing-backed `Entitlements` implementation; no public
   call site changes.

## How the seam works

```
public repo (this)                     private overlay (airo-pro)
──────────────────                     ──────────────────────────
core_entitlements                      packages_pro/airo_pro_bootstrap
  ProFeature enum                        real createEntitlements()
  Entitlements interface                 registers real ProModules
  ProModule / ProModuleRegistry        packages_pro/pro_import_intelligence
airo_pro_bootstrap (no-op stub)        packages_pro/pro_epg_reminders
  createEntitlements()                 ... (one package per ProFeature)
  registerProModules() {}
app/
  calls createEntitlements() +
  registerProModules() at startup
```

- App startup calls `createEntitlements()` and `registerProModules(registry)`
  unconditionally. In this repo those are no-ops beyond the launch promo.
- `airo-pro` is a mirror of this repo plus a `packages_pro/` directory and a
  one-line `pubspec_overrides.yaml` in `app/` pointing `airo_pro_bootstrap`
  at the real implementation.
- `airo-pro` syncs from this repo by merging `upstream/main` (scripted in the
  overlay repo). Because the overlay is additive-only, merges are mechanical.

## What belongs where

| Public (GA)                                   | Private (pro overlay)                          |
|-----------------------------------------------|------------------------------------------------|
| Player, playlist import, channel UI, cast     | Import intelligence (dedup, canonical match)   |
| Basic search/filter                           | Stream health verdicts / dead-link pruning     |
| Contracts (`core_entitlements`)               | Regional ranking / Top 50 rows                 |
| No-op bootstrap (`airo_pro_bootstrap`)        | EPG pipeline + reminders                       |
| Rust core, perf work (milestone: v2 Perf)     | Metadata enrichment, sports desk               |
|                                               | CDN intelligence-pack build pipeline           |
|                                               | Billing-backed entitlements (future)           |

Rule of thumb: platform/performance engineering is public (it makes the open
product credible); server-assisted intelligence and monetizable convenience
is overlay.

## Adding a new pro feature

1. Add a `ProFeature` value (stable id is permanent) in `core_entitlements`.
2. If the public UI needs a hook (an empty row slot, a settings entry), land
   it here behind `entitlements.isEnabled(...)`.
3. Implement the feature as a `ProModule` package in `airo-pro`'s
   `packages_pro/`, register it in the overlay bootstrap.
4. Ship. Entitlement flips (free → paid) are policy changes in the overlay,
   never public-code changes.
