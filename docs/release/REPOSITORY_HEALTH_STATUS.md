# Repository Health Status

This document records the repository-health baseline for the v2 public-release
wave. It is backed by the local `core_release` repository-health preflight.

Implementation work for this release line must start from latest `origin/main`.

## Local Evidence Command

```bash
dart pub global run melos run release:repo-health-preflight
```

The default command is expected to fail until maintainers record the remaining
governance decisions. To produce passing evidence after those decisions are
made, set:

```bash
AIRO_REPO_DISCUSSIONS=enabled \
AIRO_REPO_CODEOWNERS=not_required \
AIRO_REPO_FUNDING=intentionally_absent \
dart pub global run melos run release:repo-health-preflight
```

Use `AIRO_REPO_CODEOWNERS=present` when a root or `.github/CODEOWNERS` file is
added. Use `AIRO_REPO_FUNDING=present` when `.github/FUNDING.yml` is added.

## Verified Repo-Visible Files

- `README.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/user_bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/question.yml`
- `.github/ISSUE_TEMPLATE/agent_task.md`
- `docs/release/RELEASE_CHECKLIST.md`
- `docs/release/V2_PUBLISHING_HUMAN_SETUP.md`
- `docs/release/V2_HUMAN_IN_LOOP_BLOCKERS.md`
- `docs/release/STORE_COMPLIANCE.md`
- `docs/release/V2_RELEASE_ORCHESTRATOR.md`

## Label Taxonomy

The local preflight verifies that the repository label taxonomy covers:

- `release/v2.0.0.1`
- `store-readiness`
- `platform-android`
- `airo-tv`
- `fire-tv`
- `documentation`
- `agent/security`
- `agent/ci-cd`
- `agent/qa-testing`
- `blocked`

## Remaining Maintainer Decisions

- Decide whether GitHub Discussions should be enabled or intentionally deferred.
- Add CODEOWNERS entries for release, security, docs, v2 platform, and
  app/profile ownership, or explicitly mark CODEOWNERS not required for this
  release wave.
- Add `.github/FUNDING.yml`, or explicitly confirm funding/sponsor metadata is
  intentionally absent for this release wave.

## Deferred Items

Repository settings that cannot be read from the local checkout remain
human-confirmed evidence. The release manager should attach the generated
repository-health JSON/Markdown evidence to the release record after decisions
are made.
