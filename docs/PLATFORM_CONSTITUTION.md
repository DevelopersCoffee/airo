# Airo Platform Constitution

Status: **Binding.** All PRs are reviewed against this document. Amendments require an ADR in `docs/adr/`.

Adopted: 2026-07-20. Owner: Airo Engineering Council (`docs/agents/`).

---

## 1. Prime directive

Airo is a **platform, not an application**. The app layer (`app/lib/`) is UI, wiring, and entrypoints — nothing else. Business logic that appears in `app/lib/` outside of widgets, routing, and DI wiring is a defect.

We do not add features to comply with this document. We move, delete, and shrink. Every structural change must have measurable ROI (APK/AAB size, memory, startup, CPU, or maintenance cost) or it is **Not Worth Migrating**.

## 2. Layer model

```
Apps (entrypoints: main_tv, main_mobile_streaming, main_airo_iptv, ...)
  ↓ may depend on
Feature packages (feature_*)            — UI + orchestration for one domain
  ↓ may depend on
Platform packages (platform_*)          — business logic, no Flutter UI imports
  ↓ may depend on
Core packages (core_*)                  — contracts, data, protocol, native bridge
  ↓ may depend on
Rust core (rust/airo_core via core_native)  — CPU-bound engines
```

Rules:

- Dependencies point **downward only**. A `platform_*` package importing `feature_*` or `app/` fails review.
- `platform_*` and `core_*` packages must not import `flutter/material.dart` or `flutter/cupertino.dart` (widgets live in `core_ui` or `feature_*`).
- Platform channels and FFI live only in `core_native` and `platform_channels`. Feature code calls interfaces, never `MethodChannel` directly.
- One implementation per problem. Before writing a parser, cache, client, or repository: search `packages/` and `rust/` first. Duplicating an existing engine (e.g. a Dart M3U parser beside the Rust one in `core_native`) is a correctness bug, not a style issue.

## 3. Capability-first, not feature-parity

**A TV is not a phone. A phone is not a tablet.** We optimize for capability-first distribution, never for feature parity.

Every feature must declare, in its owning package's `module.yaml` (or `product_capabilities` registration):

- Capability ID (e.g. `capability.playback`, `capability.provider.iptv`, `capability.cast_receiver`)
- Supported devices / OS
- Runtime + native dependencies (plugins, .so files, ML models)
- Ship policy per device class: **Always Ship / Optional / Dynamic Download / Never Ship**
- Cost budget: APK impact, memory impact, startup impact

If a feature is unnecessary on a device class, it **must not ship** there — not "disabled behind a flag", not shipped-but-dormant native code. Dart tree-shaking does not remove native plugin binaries; exclusion must happen at the build graph (pubspec/Gradle/Podfile) level.

### Device responsibility matrix (defaults)

| Capability | TV / Fire TV | Phone | Tablet | Desktop |
|---|---|---|---|---|
| Cast receiver | YES | NO | NO | Optional |
| Cast sender | NO | YES | YES | Optional |
| Touch gestures | NO | YES | YES | NO |
| Remote/D-pad navigation | YES | NO | Optional | Keyboard |
| Picture-in-Picture | Optional | YES | YES | Optional |
| Voice search | YES | YES | Optional | Optional |
| Games, coins, money, bill-split, contacts, OCR | NO | YES | YES | Optional |
| Downloads / recording | Dynamic | Dynamic | Dynamic | Dynamic |
| Media-server providers (Jellyfin/Plex/Emby) | Plugin | Plugin | Plugin | Plugin |

Deviations from this matrix require a stated reason in the PR description.

## 4. Where code goes

| Kind of code | Home |
|---|---|
| Parsing, indexing, ranking, diffing, hashing, merge — anything CPU-bound and allocation-heavy | `rust/airo_core` (exposed via `core_native`), **only with a benchmark** in `packages/benchmarks` proving the win |
| Provider clients (Xtream, Stalker, Jellyfin, …), EPG, playlists, history, favorites, streams | `platform_*` packages |
| OS integrations (Media3, PiP, audio focus, media session, HDMI, remote input) | plugin packages behind interfaces; contracts in `platform_channels` / `core_native` |
| Widgets, themes, focus/remote UX | `core_ui` and `feature_*` |
| Schemas / persistence | `core_data` (or the owning `platform_*` package) — never `app/lib` |
| C++ | FFmpeg-adjacent work only (thumbnails, filters, hardware decode). Nothing else. |

Rust admission test: profiler or benchmark evidence of CPU/memory win, or a cross-platform reuse need Dart cannot serve. Otherwise: **Needs profiling** — stay in Dart.

## 5. Airo Coin package-first rule

Airo Coin is developed as a focused product module first, then embedded into
the Airo super app after the standalone module is healthy.

The source-of-truth homes are:

- `packages/platform_coin_*`: reusable storage, crypto, import/sync, validators,
  repositories, and other non-UI business logic.
- `packages/feature_coin`: Airo Coin UI, session orchestration, routing-facing
  widgets, and feature-level providers.
- Coin plugin packages: native integrations behind interfaces, never direct
  `MethodChannel` calls from app screens or feature widgets.
- `airo-pro` coin overlay: paid/pro implementations such as encrypted backup,
  restore, sync, export, or intelligence. The public repo exposes only stable
  contracts through `core_entitlements` and package interfaces.
- `app/lib/`: super-app entrypoints, route wiring, and navigation cards only.

New Airo Coin work must land in the owning package first. A PR that adds or
changes Airo Coin business logic under `app/lib/features/coins` is rejected
unless the PR is explicitly a legacy extraction step that removes or shrinks
that app-layer code. `packages/airomoney` is retired and must not receive new
code or imports.

Every Airo Coin PR must include a parity note stating:

- which package owns the behavior;
- whether standalone `feature_coin` validation passed;
- what super-app shell wiring changed, if any;
- whether an `airo-pro` coin contract or overlay is involved.

## 6. Build & size discipline

- Every new dependency goes through `platform_dependency_governance` scoring (license, maintenance, binary impact, bus factor) and a chief-open-source-officer review.
- A dependency used by one device class must not link into other device classes' binaries. Mobile-only plugins (games engines, ML kits, contacts, OCR, PDF) must be isolated so TV builds never compile them.
- Optional domains ship as dynamic modules (Flutter deferred components / Play Feature Delivery) when Play distribution allows; base APK holds only: playback, search, history, settings, provider API, player, capability registry.
- Generated code (`*.g.dart`, `frb_generated`) is budgeted: a generated file >200 KB requires schema splitting or justification.
- CI enforces size budgets per entrypoint. A PR that grows the TV APK needs a stated reason.

## 7. Review order

Correctness → Clarity → Consistency → Duplication → Tests → Performance. (Full checklist in `~/.claude/CLAUDE.md` code-review rules and Council module reviews.) A recommendation without a measurable benefit estimate is marked **Not Worth Migrating** and rejected.

## 8. Enforcement

- Council agents (chief-architect, chief-performance-officer, chief-open-source-officer, …) review against this document.
- CI gates: dependency direction check, package boundary lint, size budgets, benchmark regression.
- New packages copy `template_feature` and register in `melos.yaml` + `product_capabilities`.
