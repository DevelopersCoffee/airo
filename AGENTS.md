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

Framework agents own reusable contracts, runtime boundaries, storage schemas,
security rules, and platform abstractions. Application agents own product
journeys, screens, copy, routine packs, templates, and end-user workflows.
Neither layer should make unilateral changes across the boundary.

If the required policy artifacts are missing, stop implementation and add them
to the issue first.
