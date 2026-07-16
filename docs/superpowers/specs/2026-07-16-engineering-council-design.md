# Airo Engineering Council — Design Spec

> Date: 2026-07-16
> Status: Approved (phase 1 of 2 — see Phasing)

## Problem

Airo has agent-governance docs (`docs/agents/AGENT_POLICY.md`, `RULES.md`) but
the domain roster in `AGENT_POLICY.md` (Brain, Coins/Finance, Meeting
Intelligence, Routine OS) reflects an earlier "Airo Super App LLM OS" framing.
Current work (per repo state and recent history) is dominated by the Airo TV
sub-app: playback, EPG, Rust parsing, multi-source failover, TV shell. There
is no domain roster that matches this work, no per-role reviewer definition
usable by an AI coding tool, and no module-ownership manifest format.

Airo is coded by multiple AI tools — Claude Code, Codex (via the user's
global `codex-delegate` hook), and potentially Antigravity/Cursor/others.
Governance must not be Claude-specific: any tool should be able to discover
"who owns this, who must approve this" from files already in the repo.

## Non-goals (phase 2, not built here)

- CI enforcement that parses `module.yaml` and blocks PRs automatically.
- Retrofitting all 54 packages with `module.yaml` manifests.
- Automating GitHub required-reviewer assignment from the roster.

Phase 1 (this spec) ships the roster, charters, manifest schema, and three
real example manifests. Phase 2 is a follow-up spec once phase 1 roles have
been used on a handful of real PRs and proven out.

## Structure

Two layers, because Airo is a super-app with sub-apps:

**Super-App Chiefs** — cross-cutting, no single package, review within their
lane across every sub-app: Chief Architect, Chief Security Officer, Chief
Performance Officer, Chief QA Officer, Chief UX Officer, Chief Documentation
Officer, Chief Open Source Officer, Chief Release/DevOps Officer, Chief Cloud
Officer. CEO is a human role (final say, budget, roadmap) — not modeled as an
agent.

**Sub-App Domain Agents** — one roster per sub-app, owning real packages.

*Airo TV domain* (new, matches current work):

| Role | Owns (real packages) |
| --- | --- |
| Flutter Architect | `core_ui`, `app/`, `template_feature` |
| Rust Architect | `rust/`, `core_workers` |
| Playback Architect | `platform_player`, `platform_streams`, `platform_media`, `core_media_routing` |
| Media Intelligence Architect | `platform_epg`, `feature_iptv`, `platform_playlist`, `platform_playlist_export`, `platform_playlist_import`, `platform_favorites`, `platform_history` |
| TV Experience Architect | `core_remote_control`, `core_remote_views`, `platform_receiver_modes` |
| Platform Architect | `core_native`, `platform_channels`, `core_device_identity`, `core_pairing`, `core_protocol`, `platform_device_profile`, `platform_device_qualification` |
| Edge Architect | `core_orchestration_storage`, `core_watch_progress`, `core_presence` |
| Cloud Architect | `core_cloud_orchestration`, `core_auth`, `core_entitlements`, `core_sessions`, `core_device_merge` |

*Other sub-apps* (existing, kept — per maintainer decision these are
super-app-level domains, not replaced): Finance/Coins Agent → `airomoney`;
AI/Brain Agent → `core_ai`, `core_ai_delegation`, `core_delegation`; Meeting
Intelligence Agent → no packages yet, listed dormant for a future sub-app.

Packages not yet assigned an owner in this pass (`core_analytics`,
`core_commands`, `core_data`, `core_domain`, `core_native`, `core_push_wake`,
`platform_benchmarks`, `platform_certification`, `platform_dependency_governance`,
`platform_worker_jobs`, `product_capabilities`, `stubs`, `benchmarks`,
`airo_pro_bootstrap`) default to Chief Architect until a phase-2 pass assigns
them; `platform_dependency_governance` is explicitly owned by the Chief Open
Source Officer since it exists for exactly that purpose.

## Decision Matrix

Adapted from the maintainer's draft to real domains:

| Change | Required reviewers |
| --- | --- |
| Add/change Flutter package or widget | Flutter Architect + Chief Performance Officer + Chief Open Source Officer |
| Add/change Rust crate or `unsafe` code | Rust Architect + Chief Performance Officer + Chief Security Officer |
| Add/change a provider/source adapter | Media Intelligence Architect + Platform Architect + Chief QA Officer |
| Change playback pipeline (decoder, DRM, renderer) | Playback Architect + Chief Performance Officer + Chief Security Officer |
| Change TV navigation/focus/remote handling | TV Experience Architect + Flutter Architect + Chief UX Officer |
| Change architecture/module boundaries | Chief Architect + Platform Architect |
| Add a dependency (any package) | Owning domain agent + Chief Open Source Officer + Chief Security Officer |
| Change sync/offline/storage engine | Edge Architect + Cloud Architect + Chief Performance Officer |
| New end-user feature | Product Manager + Chief Architect + Chief QA Officer |
| Release cut | Entire council (see Release Gate below) |

This table replaces the illustrative one in the maintainer's original draft;
it is the canonical version going forward.

## `module.yaml` Manifest Schema

Lives at the root of each package (`packages/<name>/module.yaml`). Not
enforced by CI yet (phase 2) — phase 1 ships the schema and three real
examples as the reference for anyone adding a manifest by hand.

```yaml
name: <package name, must match pubspec.yaml name>
owner: <one role from the roster above>
reviewers:
  - <additional roles required for non-trivial changes>
contracts:
  - <versioned contract/IR name this package implements, if any — "none" if not yet versioned>
allowed_dependencies:
  - <packages or package groups this module may depend on>
forbidden_dependencies:
  - <packages this module must never depend on, and why is implied by the boundary>
quality_gates:
  test_coverage: ">NN%"   # omit fields that aren't measured yet rather than inventing numbers
```

Fields are omitted, not fabricated, when a package doesn't have a measured
value yet (e.g. no startup budget defined). A manifest with placeholder
numbers is worse than one with fewer, honest fields.

### Example manifests (written in phase 1)

- `packages/platform_epg/module.yaml` — owner Media Intelligence Architect.
- `packages/platform_player/module.yaml` — owner Playback Architect.
- `packages/platform_dependency_governance/module.yaml` — owner Chief Open
  Source Officer.

## Cross-Tool Mechanics

- **Source of truth is tool-agnostic markdown**: `docs/agents/COUNCIL.md`
  (new) holds the full roster, decision matrix, and manifest schema. No
  Claude-specific syntax.
- **`AGENTS.md` (repo root)** — already the convention file Codex, Antigravity,
  Cursor, and Claude Code all read first — gets one new section pointing at
  `docs/agents/COUNCIL.md`, mirroring its existing pointer to
  `docs/agents/AGENT_POLICY.md`.
- **`docs/agents/AGENT_POLICY.md`** — its "Domain Agents" and "Ownership Map"
  sections are updated to point at the new roster instead of duplicating it;
  the lifecycle/gates (Critical Agent, Contract Draft, etc.) are unchanged.
- **Claude Code** gets an additional operational layer: one file per role
  under `.claude/agents/<role-slug>.md`, so Claude can invoke a role as a real
  subagent (`Agent(subagent_type: "rust-architect")`). These files are thin —
  role name, package ownership, and "read `docs/agents/COUNCIL.md` § `<Role>`
  before reviewing, apply its criteria" — they do not restate the charter.
  This keeps `COUNCIL.md` the only place criteria are edited.
- **Codex** already runs an adversarial review on every Edit/Write via the
  user's global `codex-delegate` skill. No repo change needed for this to
  work; the skill's prompt can optionally cite the relevant `COUNCIL.md`
  section, but that's a global (`~/.claude/skills/`) change, out of scope for
  this repo-level spec.
- **Antigravity / other tools** — no special files. They inherit governance
  via `AGENTS.md` → `COUNCIL.md`, same as everyone else. No per-tool fork of
  the rules.

## What's Written in Phase 1

1. `docs/agents/COUNCIL.md` — full charter (roster, responsibilities per
   role, decision matrix, manifest schema).
2. `docs/agents/AGENT_POLICY.md` — Domain Agents + Ownership Map sections
   updated to reference the new roster.
3. `AGENTS.md` — new pointer section.
4. `docs/agents/index.md` — new link.
5. `.claude/agents/*.md` — one thin subagent file per Airo-TV-domain role and
   per Chief role (14 files).
6. Three real `module.yaml` example manifests (listed above).

## Testing / Verification

This is a documentation and configuration change with no runtime code path —
no automated tests apply. Verification is:

- Every package name referenced in `COUNCIL.md` and the manifests actually
  exists in `packages/` (checked against `ls packages/` at write time).
- No contradictions between `COUNCIL.md`'s roster and `AGENT_POLICY.md`'s
  updated Ownership Map (single source, one references the other).
- Spec self-review pass for placeholders/ambiguity before commit.
