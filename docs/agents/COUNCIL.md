# Airo Engineering Council

> Version: 1.0.0
> Effective: 2026-07-16
> Tool-agnostic: this file is the single source of truth for any AI coding
> tool (Claude Code, Codex, Antigravity, Cursor, or a human). No syntax here
> is specific to one tool.

## Purpose

Airo ships code from multiple AI tools working in parallel. This council
gives every module a named owner and every category of change a required set
of reviewers, so correctness is enforced by the repository's structure
rather than by which tool happened to write the code. See
[AGENT_POLICY.md](./AGENT_POLICY.md) for the lifecycle (Critical Agent gate,
contract draft, etc.) this council's roles plug into.

Design rationale: `docs/superpowers/specs/2026-07-16-engineering-council-design.md`.

## Structure

Airo is a super-app with sub-apps. Governance has two layers:

- **Super-App Chiefs** — cross-cutting, own no single package, required
  reviewers within their lane across every sub-app.
- **Sub-App Domain Agents** — one roster per sub-app, each owning real
  packages.

CEO is a human role (vision, budget, roadmap, final say) — not modeled as an
agent, and does not review implementation, libraries, or code quality.

## Super-App Chiefs

### Chief Architect
Owns: module boundaries, package ownership, APIs, dependency graph, ADRs.
Approves: new packages, cross-package contracts, folder structure changes.
Rejects: circular dependencies, layer violations, ownership-boundary
violations. Default owner for any package not yet assigned below.

### Chief Security Officer
Owns: secrets, authentication, encryption, dependency/license risk, privacy.
Required reviewer for: `core_auth`, `core_entitlements`, `core_device_identity`,
`core_device_merge`, any new dependency, any `unsafe` Rust.

### Chief Performance Officer
Owns: CPU, memory, GPU, startup time, frame time, binary size, battery,
network, disk. Required reviewer for every Rust change and every new
dependency.

### Chief QA Officer
Owns: test strategy — unit, integration, golden, E2E, TV, accessibility,
regression. Required reviewer for any user-visible change and any new
provider/adapter.

### Chief UX Officer
Owns: navigation, interaction consistency, accessibility, design system,
motion. Required reviewer for TV navigation/focus/remote-handling changes and
any `core_ui` change.

### Chief Documentation Officer
Owns: docs, ADRs, migration notes, examples, API docs. Nothing merges without
matching documentation (existing `scripts/check-docs-completeness.sh` already
enforces a version of this).

### Chief Open Source Officer
Owns: dependency scoring — license, maintenance, security, binary impact,
bus factor. Primary owner of `platform_dependency_governance`. Required
reviewer for every new dependency in any package.

### Chief Release/DevOps Officer
Owns: CI, build/release workflows, versioning, branching, signing, artifacts.
Maps to the existing "Release and DevEx Agent" in `AGENT_POLICY.md`.

### Chief Cloud Officer
Owns: Firebase/GCP/AWS, sync, auth backend, monitoring. Primary owner of
`core_cloud_orchestration`, `core_auth`, `core_entitlements`, `core_sessions`,
`core_device_merge` — auth flow, entitlement checks, and session lifecycle.
Chief Security Officer is a required reviewer on these, not the owner.

### Product Manager
Owns: business value, feature completeness, roadmap alignment, `product_capabilities`.
Required reviewer for every new end-user feature. Does not review
implementation detail — that's the domain agent's job.

## Sub-App Domain Agents

### Airo TV domain

| Role | Owns (real packages) | Approves | Rejects |
| --- | --- | --- | --- |
| Flutter Architect | `core_ui`, `app/`, `template_feature` | Riverpod usage, widget structure, navigation, design-system packages | New state-management patterns that bypass Riverpod, ad-hoc design tokens |
| Rust Architect | `rust/`, `core_workers` | `unsafe`, SIMD, Tokio/Rayon usage, FFI boundary shape | Unreviewed `unsafe`, blocking calls on async runtimes |
| Playback Architect | `platform_player`, `platform_streams`, `platform_media`, `core_media_routing` | Decoder/renderer changes, DRM, subtitle/audio pipeline | Changes that bypass the media routing contract |
| Media Intelligence Architect | `platform_epg`, `feature_iptv`, `platform_playlist`, `platform_playlist_export`, `platform_playlist_import`, `platform_favorites`, `platform_history` | Provider adapters, EPG parsing/normalization, ranking | Provider-specific hacks that leak into shared models |
| TV Experience Architect | `core_remote_control`, `core_remote_views`, `platform_receiver_modes` | Focus engine, remote input mapping, overscan handling | Focus traversal that breaks 10-foot navigation |
| Platform Architect | `core_native`, `platform_channels`, `core_device_identity`, `core_pairing`, `core_protocol`, `platform_device_profile`, `platform_device_qualification` | Native bridge/FFI shape, platform channel contracts | Direct native calls bypassing the channel contract |
| Edge Architect | `core_orchestration_storage`, `core_watch_progress`, `core_presence` | Offline/caching/sync design, background workers | Sync logic duplicated outside these packages |

### Other sub-app domains (existing, kept)

| Role | Owns | Notes |
| --- | --- | --- |
| Coins / Finance Agent | `feature_coin`, `platform_coin_vault`, future `platform_coin_*` and coin plugin packages | Airo Coin is package-first. `packages/airomoney` is retired; `app/lib/features/coins` is legacy super-app code to extract or delete, not a target for new behavior. |
| AI/Brain Agent | (none yet) | Owns product-layer Brain/chat journeys once built. Does **not** own `core_ai`, `core_ai_delegation`, `core_delegation` — those runtime/model-routing packages stay with Framework Agent per `AGENT_POLICY.md`'s Ownership Map, to avoid a two-owner conflict on the same package. |
| Meeting Intelligence Agent | (none yet) | Dormant — no packages exist for this sub-app yet |

### Package ownership — full retrofit (phase 2)

Every real package (a directory with its own `pubspec.yaml`) now has a
`packages/<name>/module.yaml`, validated by
`scripts/check-module-manifests.py` in CI. `packages/stubs/` is a container
of 21 independent third-party-compatibility shims, not itself a package (no
`pubspec.yaml` at its own root) — excluded from manifest coverage by design.

Packages assigned to `Chief Architect` as primary owner (no dedicated domain
fits): `airo` (super-app host/routing), `airo_pro_bootstrap`, `core_data`,
`core_domain`, `core_experimentation`, `core_media_data` (data/benchmark
models, not decoder/DRM/subtitle logic — not a real Playback fit),
`platform_worker_jobs` (generic resource-scheduler contracts, no UI —
not a real Flutter fit). These stay Chief-Architect-owned until a future
pass finds a better-fitting domain, not because they're unimportant.

## Decision Matrix

| Change | Required reviewers |
| --- | --- |
| Add/change Flutter package or widget | Flutter Architect + Chief Performance Officer + Chief Open Source Officer |
| Add/change Rust crate or `unsafe` code | Rust Architect + Chief Performance Officer + Chief Security Officer |
| Add/change a provider/source adapter | Media Intelligence Architect + Platform Architect + Chief QA Officer |
| Change playback pipeline (decoder, DRM, renderer) | Playback Architect + Chief Performance Officer + Chief Security Officer |
| Change TV navigation/focus/remote handling | TV Experience Architect + Flutter Architect + Chief UX Officer |
| Change architecture/module boundaries | Chief Architect + Platform Architect |
| Add a dependency (any package) | Owning domain agent + Chief Open Source Officer + Chief Security Officer |
| Change sync/offline/storage engine | Edge Architect + Chief Cloud Officer + Chief Performance Officer |
| New end-user feature | Product Manager + Chief Architect + Chief QA Officer |
| Release cut | Entire council |

## `module.yaml` Manifest Schema

One file per package, at `packages/<name>/module.yaml`. Enforced in CI by
`scripts/check-module-manifests.py` (name/pubspec match, valid roles,
allowed/forbidden dependencies vs. real pubspec path deps) — wired into
`pr-checks.yml`. Fields are omitted, never fabricated, when a value isn't
measured.

```yaml
name: <package name, must match pubspec.yaml name>
owner: <one role from the roster above>
reviewers:
  - <additional roles required for non-trivial changes, per Decision Matrix>
contracts:
  - <versioned contract/IR name this package implements — omit if none yet>
allowed_dependencies:
  - <packages or package groups this module may depend on>
forbidden_dependencies:
  - <packages this module must never depend on>
quality_gates:
  test_coverage: ">NN%"   # omit fields with no measured baseline
```

Reference examples: `packages/platform_epg/module.yaml`,
`packages/platform_player/module.yaml`,
`packages/platform_dependency_governance/module.yaml`.

## Release Gate

Before a release, each Chief and relevant domain agent records a pass/fail
against their lane (architecture, performance, security, QA, docs, product,
release). This is the same shape as `AGENT_POLICY.md`'s existing "Release
Ready" gate — this council supplies the specific named reviewers for it.

## Cross-Tool Usage

- Claude Code: invoke a role via `.claude/agents/<role-slug>.md` (thin files
  pointing back to this document's relevant section).
- Codex: reviewed via the user's global `codex-delegate` hook; cite the
  relevant section of this file in the review prompt when a change touches an
  owned package.
- Any other tool: read `AGENTS.md` at the repo root, which points here.

## Related Documents

- [Agent Policy](./AGENT_POLICY.md) — lifecycle, gates, contracts
- [Agent Operating Rules](./RULES.md)
- [Design spec](../superpowers/specs/2026-07-16-engineering-council-design.md)
