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
4. **Play denies Pro; the overlay decides when to unlock.** Public
   `createEntitlements()` returns `NoEntitlements`. Overlay builds may grant
   Pro after a **hosted** license (RevenueCat + Airo License API) or, for
   CI/dev only, `AIRO_PRO_LICENSE=true`. That dart-define must never ship as
   a Play/production bypass. Public call sites stay on
   `createEntitlements()` / `isEnabled`.
5. **Play OSS is local-first.** The open-source app does not register
   installations with the hosted License API and does not link RevenueCat.
   Anonymous installation analytics may be added later only after a privacy
   and Play Data Safety review.
6. **License contracts are public; commerce is not.** `packages/airo_license`
   is the reusable SDK (models, cache, `PurchaseProvider` port,
   `LocalLicenseClient`). It must not import `core_auth`, purchase SDKs, or
   Supabase. Hosted API, pairing, device management, and checkout live in
   `airo-pro` and private `airo-license-api`.

## How the seam works

```
public repo (this)                     private overlay (airo-pro)
──────────────────                     ──────────────────────────
core_entitlements                      packages_pro/airo_pro_bootstrap
  ProFeature enum                        license-backed createEntitlements()
  Entitlements interface                 registers real ProModules
airo_license (local-first SDK)         RevenueCat adapter (future)
  LocalLicenseClient                   hosted LicenseClient (future)
  UnavailablePurchaseProvider          pairing / device management UI
airo_pro_bootstrap (deny-all)          packages_pro/pro_*
app/                                   private airo-license-api
  prepareProEntitlements() +           (Postgres, webhooks — not this repo)
  createEntitlements()
```

- App startup calls `prepareProEntitlements()`, then
  `createEntitlements()` and `registerProModules(registry)`. In this repo
  entitlements deny all Pro features and `registerProModules` is empty.
  Overlay builds enable Pro only after a verified license policy — not
  because the public SDK called a network.
- `airo-pro` is a mirror of this repo plus a `packages_pro/` directory and a
  one-line `pubspec_overrides.yaml` in `app/` pointing `airo_pro_bootstrap`
  at the real implementation.
- `airo-pro` syncs from this repo by merging `upstream/main` (scripted in the
  overlay repo). Because the overlay is additive-only, merges are mechanical.
- `core_auth` remains login/session identity. It is not the license system.

## What belongs where

| Public (GA)                                   | Private (pro overlay)                          |
|-----------------------------------------------|------------------------------------------------|
| Player, playlist import, exact-id remaps      | Import intelligence (tvg-id + name matching)   |
| Basic search/filter                           | Stream health verdicts / dead-link pruning     |
| Single-source playback                         | Multi-source failover                          |
| Contracts (`core_entitlements`, `airo_license`) | Hosted License API + RevenueCat |
| No-op bootstrap (`airo_pro_bootstrap`)        | EPG reminders + OS notification gateway        |
| Rust core, perf work (milestone: v2 Perf)     | Metadata enrichment, sports desk               |
| Static Play “Free / Open Source” license line | Pairing, restore, device management UI         |
|                                               | CDN intelligence-pack build pipeline           |
|                                               | Billing-backed entitlements (future)           |

Rule of thumb: platform/performance engineering is public (it makes the open
product credible); server-assisted intelligence and monetizable convenience
is overlay.

## Adding a new pro feature

1. Add a `ProFeature` value (stable id is permanent) in `core_entitlements`
   **and** the matching string in `AikaLicenseCapabilities`.
   Freeze the stable-id list in `packages/core_entitlements/test/goldens/pro_feature_stable_ids.dart`; any rename or renumber requires an explicit compatibility decision.
2. If the public UI needs a hook (an empty row slot, a settings entry), land
   it here behind `entitlements.isEnabled(...)`.
3. Implement the feature as a `ProModule` package in `airo-pro`'s
   `packages_pro/`, register it in the overlay bootstrap.
4. Ship. Entitlement flips (free → paid) are policy changes in the overlay,
   never public-code changes.
