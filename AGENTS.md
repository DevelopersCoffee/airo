# Airo Agent Policy

## Release Branding Skill

Before updating the public GitHub Pages site or preparing public product copy
for any Airo/Airo TV release, read and follow
`.agents/skills/airo-release-branding/SKILL.md`. The skill governs release
evidence, Community Voice summaries, Airo Pro disclosure, screenshots, device
claims, guides, and roadmap consistency.

Every implementation agent working in this repository must follow the agent
lifecycle in [docs/agents/AGENT_POLICY.md](docs/agents/AGENT_POLICY.md) before
writing feature code.

For module ownership and required reviewers by change type, read
[docs/agents/COUNCIL.md](docs/agents/COUNCIL.md) — the Airo Engineering
Council roster. This applies regardless of which AI tool is writing the
code (Claude Code, Codex, Antigravity, or any other agent reading this file).

## Required Before Implementation

For every feature, bug fix, or architecture change:

1. Identify the owning agent and impacted modules.
2. Run the Critical Agent clarity gate.
3. Define the cross-agent contract if more than one module is touched.
4. Add deterministic use cases and automation flows to the GitHub issue.
5. Confirm whether the work belongs in framework code, application code, or both.
6. Sync the task branch or worktree from the correct release-line base before writing code.
7. Only then start implementation.

## GitHub Actions Cost Control

GitHub Actions minutes are a shared cost. Agents must prefer focused local
validation over broad remote CI.

Default rule:

1. Run the narrowest local tests, analyzers, format checks, docs checks, or
   package builds that prove the touched contract.
2. Do not intentionally trigger full GitHub Actions build matrices for small
   issue slices unless branch protection, release/signing validation, or the
   issue explicitly requires them.
3. Use `[skip ci]` on local-only commits and direct sync pushes when remote CI
   is not required and repository/branch policy permits it.
4. If an expensive workflow starts accidentally or is no longer needed, cancel
   it rather than waiting for artifact builds.
5. Do not keep a PR or issue open only to wait for non-required artifact builds.
   Merge/close the bounded slice when required checks and local evidence are
   sufficient; split remaining acceptance evidence into follow-up work instead
   of blocking unrelated progress.
6. Close issues as soon as their bounded acceptance criteria are met. Do not
   hold completed slices open for optional CI, broad matrix runs, release
   artifacts, or physical-device evidence that can be tracked separately.

## Worker Offload Rule

Large parsing, serialization, indexing, cache hydration, and playlist/EPG data
transforms must not be added directly to UI or feature code on the main isolate.

Default rule:

1. Put reusable heavy-work boundaries in platform/framework packages.
2. Use `platform_worker_jobs` and `AiroWorkerExecutor` for Dart isolate-backed
   work unless the issue explicitly requires native/Rust execution.
3. Keep synchronous helpers only for deterministic tests and small direct
   parsing. Async production paths should use the worker boundary.
4. Do not add screen-local `compute`, `Isolate.run`, or parser loops inside
   Airo TV presentation code. Application modules consume platform services.

## Worktree Sync Rule

When an LLM, agent, or human starts a new task, creates a branch, or creates a
worktree, the starting point must be the latest release-line base, not a stale
local branch or an older worktree snapshot.

Release-line bases:

- Active development and current modular/release-profile work starts from `origin/main`.
- The legacy pre-swap monolith line is preserved at `origin/v1_bkp` for reference or recovery only.
- If an issue explicitly targets an older v1 artifact or historical branch state, name that base branch in the issue instead of assuming it.

Minimum requirement:

1. `git fetch origin main v1_bkp`
2. choose `origin/main` for active work, or `origin/v1_bkp` only when the issue explicitly requires the legacy line
3. create the branch or worktree from that chosen remote base
4. verify the task branch/worktree is based on the fetched remote base

If this sync step is skipped, implementation must stop until the worktree is
rebased, recreated, or reset onto the correct current remote base.

## CI Cost Control Rule

GitHub Actions minutes are a costed resource. During iterative issue work,
agents must avoid unnecessary remote CI builds and use local validation first.
For current v2.0.0.0 development, the default is to skip remote CI for
issue-iteration and integration-branch merge commits unless a maintainer
explicitly asks for a CI run.

Minimum requirement:

1. Run focused local validation for the touched package or module before
   pushing: formatting, analyzer/lint, targeted tests, and `git diff --check`
   as applicable.
2. Add `[skip ci]` to iterative issue commits and merge commits unless the user
   explicitly requests a CI run or the change is a release verification step.
3. Prefer pushing issue branches and the `codex/next-v2.0.0.0` integration
   branch for current mainline development. Do not push directly to `main` just to validate a
   work-in-progress change, because release-line pushes can trigger additional
   workflows such as Pages builds.
4. Avoid empty commits, no-op pushes, repeated metadata-only pushes, or branch
   churn that would trigger workflows without changing reviewable behavior.
5. Do not wait for remote CI to close an issue when the agreed acceptance
   criteria are satisfied by focused local validation and the issue records the
   evidence.
6. Close GitHub issues as soon as the acceptance criteria are satisfied and
   local validation evidence has been recorded in the issue. Do not close issues
   before required policy artifacts, deterministic use cases, and validation
   notes are present.

If remote CI is intentionally required, state why in the issue or PR before
pushing without `[skip ci]`.

Framework agents own reusable contracts, runtime boundaries, storage schemas,
security rules, and platform abstractions. Application agents own product
journeys, screens, copy, routine packs, templates, and end-user workflows.
Neither layer should make unilateral changes across the boundary.

If the required policy artifacts are missing, stop implementation and add them
to the issue first.

## Isolate policy — no parsing on the main isolate

**Rule:** All parsing, JSON decoding, M3U/EPG processing, and serialization of
payloads >50 KB must run via `runOffMain()` from `packages/core_workers`.

```dart
import 'package:core_workers/core_workers.dart';
final channels = await runOffMain(() => parseM3U(content));
```

`Isolate.run` / `compute()` are acceptable equivalents. Direct inline
`jsonDecode` of large network responses on the widget/provider layer is a lint
violation. The Rust FFI core (`packages/core_native`) will eventually replace
these call sites, but the isolate boundary must be preserved as web fallback.
