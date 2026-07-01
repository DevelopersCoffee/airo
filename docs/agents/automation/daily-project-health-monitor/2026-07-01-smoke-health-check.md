# Daily Project Health Monitor: Smoke Health Check Accuracy

## Critical Agent Gate

**Problem:** The smoke-test workflow publishes a summary with hard-coded green statuses for code analysis and debug build even though the `health-check` job does not execute those checks and other smoke steps can fail under `continue-on-error`.
**User / actor:** Release and DevEx Agent, maintainers reviewing release health artifacts.
**Framework or application layer:** Framework / CI and release automation.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** QA Automation Agent.
**Impacted modules/files:** `.github/workflows/smoke-tests.yml`
**Base branch/worktree:** confirmed from latest `origin/main`: yes
**Open questions:** None for this maintenance slice; scope is limited to status reporting accuracy.
**Decision:** Ready

## Deterministic Use Cases

1. When Playwright smoke tests fail, the uploaded summary marks web smoke as failed instead of implying green status.
2. When Android debug build fails, the uploaded summary marks Android smoke as failed.
3. When dependency inspection succeeds, the summary marks dependency health accurately and still uploads even if another job fails.

## Automation Flow

1. Run `.github/workflows/smoke-tests.yml` with `workflow_dispatch`.
2. Execute web smoke, Android debug build, and dependency inspection.
3. Aggregate actual job and step outcomes in `health-check`.
4. Upload `reports/smoke-test-summary.md` with truthful status rows.
