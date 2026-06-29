# Contributing to Airo

This repository expects scoped, verifiable contributions. The goal is fast
review, low surprise, and clean work stacked on the latest `origin/main`.

## Before You Start

Read these first:

- [README.md](README.md)
- [AGENTS.md](AGENTS.md)
- [docs/agents/AGENT_POLICY.md](docs/agents/AGENT_POLICY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

Pick an issue before writing code. Prefer tickets that already include:

- a completed Critical Agent Gate
- owning agent and impacted modules
- deterministic use cases and automation notes

If those artifacts are missing, add them to the issue first.

## Create a Fresh Worktree

Every new task must start from the latest `origin/main`.

```bash
git fetch origin main
git worktree add ../airo-my-task -b codex/my-task origin/main
cd ../airo-my-task
```

Do not branch from a stale local checkout or an older worktree snapshot.

## Local Setup

Use the repository `Makefile` where possible:

```bash
make setup
make analyze
make test
```

For narrower work, run the smallest honest verification that matches the
change. Examples:

```bash
make analyze
make test
flutter test path/to/specific_test.dart
```

If something is blocked by local environment state, report the exact blocker in
the PR. Example: missing signing files, missing `google-services.json`, or
device-only prerequisites.

## Contribution Types

### Code changes

- Keep changes scoped to one issue or one concern.
- Respect framework/application boundaries from `AGENTS.md`.
- Do not invent APIs, product behavior, or migration steps not grounded in the
  issue or codebase.
- Update docs/wiki when user-facing behavior changes.

### Docs-only changes

Docs-only contributors do not need to run the full app matrix. At minimum, run
host-only checks:

```bash
test -f README.md
test -f CONTRIBUTING.md
test -f CODE_OF_CONDUCT.md
rg "make setup|make analyze|make test|git worktree|pull request" README.md CONTRIBUTING.md
```

Then do a quick placeholder scan over the edited docs and confirm no unfinished
markers remain.

### Native or platform work

- Keep Android/iOS changes narrow and reproducible.
- Prefer targeted verification over broad claims.
- If local platform builds are blocked by unrelated machine setup, say so
  explicitly in the PR.

## Pull Request Checklist

Before opening a PR:

1. Link the issue.
2. Rebase or restack on the latest `origin/main` if needed.
3. Run the narrowest honest verification.
4. Update docs if behavior changed.
5. Fill out the PR template with summary, risks, testing, and notes for
   reviewers.

Maintainers will look for:

- issue linkage
- Critical Agent Gate presence
- verification evidence
- correct scope discipline
- docs impact when applicable

## First Contributions

Good first contribution categories in this repo:

- docs/wiki clarity fixes
- contributor tooling and repo hygiene
- scoped widget or test fixes with deterministic validation
- policy/completeness gaps called out by CI

Avoid starting with broad architecture or multi-module runtime issues unless
the issue already has a clear contract and verification plan.

## Secrets and Release Materials

Never commit:

- keystores
- `key.properties`
- signing secrets
- personal tokens
- generated credentials

If a task depends on release secrets or store assets, document the blocker
instead of fabricating a local workaround.

## License Status

The repository currently does not include a root `LICENSE` file. Do not invent
license terms in docs or PRs. If contribution or redistribution questions
depend on licensing, ask maintainers in the linked issue or PR thread.
