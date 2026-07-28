# Airo — agent context

Local-first Flutter super app: AI chat, personal finance, TV/IPTV, music, games,
and reading in one codebase. Melos workspace — `packages/` is framework, `app/`
is product. 62 packages carry a `module.yaml` declaring their council owner.

This file applies to every agent tool that reads it — Claude Code, Codex,
Antigravity, or anything else.

## Gotchas

**Parsing never runs on the main isolate.** Any parse, JSON decode, M3U/EPG
transform, or serialization over ~50 KB goes through `runOffMain()` from
`packages/core_workers`, or `platform_worker_jobs` / `AiroWorkerExecutor` for a
reusable job boundary. Screen-local `compute()` or `Isolate.run` inside
presentation code is a lint violation: application modules consume platform
services rather than spawning their own workers. Synchronous helpers stay fine
for tests and small deterministic parsing. The Rust core (`packages/core_native`)
will replace many of these call sites, but the isolate boundary must survive as
the web fallback.

**Flavors are separate pubspecs, not build flags.** `app/pubspec.yaml` (phone),
`pubspec_tv.yaml`, `pubspec_coins.yaml`, `pubspec_patrol.yaml`,
`pubspec_ios_spm.yaml` — each pairs with its own entrypoint in `app/lib/`
(`main.dart`, `main_tv.dart`, `main_coins.dart`, `main_qualification.dart`). A
dependency added to one is invisible to the others.

**`packages/airo_pro_bootstrap` is a deliberate no-op.** The private `airo-pro`
overlay swaps a same-named package in through `pubspec_overrides.yaml`, the same
mechanism as `packages/stubs`. Never put pro logic in the public copy — only
widen the seam (`createEntitlements`, `registerProModules`) when the overlay
needs it.

**Framework and application layers do not cross unilaterally.** Framework owns
contracts, runtime boundaries, storage schemas, security rules, and platform
abstractions. Application owns journeys, screens, copy, routine packs, and
templates. Cross-boundary work needs an explicit contract recorded in the issue
before code.

**Release lines.** Active work branches from `origin/main`. `origin/v1_bkp` is
the frozen pre-swap monolith, kept for reference and recovery — base on it only
when an issue names it.

**GitHub Actions minutes are a costed shared resource.** Prove the touched
contract with the narrowest local analyzer/test/format run, and mark iterative
and sync commits `[skip ci]`. Full matrices and release workflows are opt-in.

## Load when relevant

| Doing | Read |
|---|---|
| Any feature, fix, or architecture change | [docs/agents/AGENT_POLICY.md](docs/agents/AGENT_POLICY.md) — lifecycle gates, Critical Agent, cross-agent contracts |
| Deciding who must review | [docs/agents/COUNCIL.md](docs/agents/COUNCIL.md) — module ownership, decision matrix, `module.yaml` schema |
| Branching, worktrees, CI spend, closing issues | [docs/agents/WORKFLOW.md](docs/agents/WORKFLOW.md) |
| Public site or release copy | `.agents/skills/airo-release-branding/SKILL.md` |
| Running Airo TV locally | `.claude/skills/run-airo-tv/SKILL.md` |
| TV / leanback UI | `.claude/skills/android-tv-design/SKILL.md` |
| Editing this file or the docs it points at | [docs/agents/CONTEXT_ENGINEERING.md](docs/agents/CONTEXT_ENGINEERING.md) |
