# Airo Agent Policy

Every implementation agent working in this repository must follow the agent
lifecycle in [docs/agents/AGENT_POLICY.md](docs/agents/AGENT_POLICY.md) before
writing feature code.

## Required Before Implementation

For every feature, bug fix, or architecture change:

1. Identify the owning agent and impacted modules.
2. Run the Critical Agent clarity gate.
3. Define the cross-agent contract if more than one module is touched.
4. Add deterministic use cases and automation flows to the GitHub issue.
5. Confirm whether the work belongs in framework code, application code, or both.
6. Sync the task branch or worktree from the correct release-line base before writing code.
7. Only then start implementation.

## Worktree Sync Rule

When an LLM, agent, or human starts a new task, creates a branch, or creates a
worktree, the starting point must be the latest release-line base, not a stale
local branch or an older worktree snapshot.

Release-line bases:

- v1 monolith / full APK / 1.x work starts from `origin/main`.
- v2 modular APK / 2.x work starts from `origin/v2`.
- If the issue does not explicitly say v2, use `origin/main`.

Minimum requirement:

1. `git fetch origin main v2`
2. choose `origin/main` for v1 work or `origin/v2` for v2 work
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
   Do not manually dispatch, rerun, or unblock GitHub Actions for iteration
   branches unless a maintainer asks for that remote evidence.
3. Prefer pushing issue branches and the `codex/next-v2.0.0.0` integration
   branch for v2 development. Do not push directly to `v2` just to validate a
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
7. Keep issues open only when a real external gate remains, such as physical
   device evidence, store-console access, credentials, production secrets, or a
   maintainer/product decision. Record that blocker explicitly in the issue.

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
