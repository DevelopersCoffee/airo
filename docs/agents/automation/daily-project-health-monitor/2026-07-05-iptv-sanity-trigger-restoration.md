# Daily Project Health Monitor: IPTV Sanity Trigger Restoration

## Critical Agent Gate

**Problem:** The IPTV sanity pipeline documentation and repository design describe daily scheduled refreshes and push-based validation for `iptv-data`, but `.github/workflows/iptv_sanity.yml` currently exposes only `workflow_dispatch`. That leaves the repository without automatic freshness checks for IPTV artifacts and creates drift between expected and actual CI behavior.
**User / actor:** Release and DevEx Agent, Media Agent, maintainers depending on refreshed IPTV artifacts.
**Framework or application layer:** Framework / CI and release automation.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** QA Automation Agent, Media Agent.
**Impacted modules/files:** `.github/workflows/iptv_sanity.yml`
**Base branch/worktree:** confirmed from latest `origin/main`: yes
**Open questions:** None for this maintenance slice; scope is limited to restoring intended workflow triggers without changing pipeline logic.
**Decision:** Ready

## Deterministic Use Cases

1. When IPTV source or pipeline files change on `main`, the IPTV sanity workflow runs automatically.
2. At 00:00 UTC each day, the IPTV sanity workflow runs automatically without manual intervention.
3. Maintainers can still trigger the workflow manually with `workflow_dispatch`.

## Automation Flow

1. GitHub receives either a scheduled event, a push to `main` touching IPTV pipeline files, or a manual dispatch.
2. `.github/workflows/iptv_sanity.yml` starts the existing Python lint, test, pipeline, verification, and gist publication steps.
3. The repository regains automatic IPTV artifact freshness checks without changing the pipeline implementation itself.
