# Airo Workflow — branching, CI spend, and issue close-out

Load this when starting a branch or worktree, deciding whether a change needs
remote CI, or closing an issue. `AGENTS.md` carries the one-line summary; the
detail lives here so it is only in context when it matters.

## Branch and worktree bases

A new task, branch, or worktree starts from the current remote release-line
base — never a stale local branch or an older worktree snapshot.

- `origin/main` — active development, modular and release-profile work.
- `origin/v1_bkp` — frozen pre-swap monolith. Reference and recovery only. Base
  on it when an issue explicitly names it, and not otherwise.

```bash
git fetch origin main
git worktree add ../airo-worktrees/<task> -b <branch> origin/main
```

Verify the branch is actually based on the fetched remote base. If this step was
skipped, stop and rebase, recreate, or reset onto the correct base before
writing more code.

## CI spend

GitHub Actions minutes are shared cost. During iterative issue work, prove
correctness locally first and keep remote CI for the cases that need it.

1. Run the narrowest local validation that proves the touched contract —
   formatting, analyzer, targeted package tests, `git diff --check`, docs checks.
2. Mark iterative issue commits and integration-branch merge commits
   `[skip ci]` unless the change is a release verification step or a maintainer
   asked for a run.
3. Push issue branches rather than pushing work-in-progress straight to `main` —
   release-line pushes also trigger Pages and release workflows.
4. Avoid empty commits, no-op pushes, repeated metadata-only pushes, and branch
   churn: they burn minutes without changing reviewable behavior.
5. Cancel an expensive workflow that started accidentally instead of waiting out
   the artifact build.
6. When remote CI genuinely is required, say why in the issue or PR before
   pushing without `[skip ci]`.

## Closing issues

Close an issue once its bounded acceptance criteria are met and the local
validation evidence is recorded on the issue. Do not hold a completed slice open
for optional CI, broad matrix runs, release artifacts, or physical-device
evidence — track those separately. Equally, do not close before the required
policy artifacts, deterministic use cases, and validation notes are present.
