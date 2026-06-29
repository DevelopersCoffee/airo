# Contributing To Airo

Thanks for helping improve Airo. This guide is written for developers who want a
clear path from "I found the repo" to "my PR is reviewable."

## Start Here

1. Read the project README.
2. Find an issue labeled
   [`good first issue`](https://github.com/DevelopersCoffee/airo/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
   or
   [`help wanted`](https://github.com/DevelopersCoffee/airo/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22).
3. If no issue fits, open one before making a non-trivial change.
4. For features, bug fixes, architecture changes, and automation flows, follow
   [`docs/agents/AGENT_POLICY.md`](docs/agents/AGENT_POLICY.md).

Tiny typo fixes can go straight to a PR. Anything that changes behavior,
architecture, CI, security posture, or user-facing documentation needs an issue.

## Good First Contributions

High-signal beginner contributions usually look like this:

- Reproduce a bug and add exact device/OS/tool versions.
- Convert a vague issue into deterministic use cases and an automation flow.
- Improve setup docs after following them on a clean machine.
- Add a missing failure-path test for existing behavior.
- Fix accessibility labels, overflow, empty states, or copy in a tightly scoped UI.
- Add screenshots or notes to docs when they clarify real workflows.
- Reduce friction in local scripts without changing app behavior.

Avoid large drive-by rewrites. Small, reviewable PRs are much more likely to land.

## Development Setup

```bash
git clone git@github.com:DevelopersCoffee/airo.git
cd airo
make setup
```

Platform setup:

```bash
make setup-android
make setup-ios
make setup-web
```

Useful local commands:

```bash
make help
make format
make analyze
make test
make doctor
```

Run only the checks relevant to your change when a full run is not practical, and
document that scope in the PR.

## Branch And Worktree Workflow

Always start from the latest `origin/main`:

```bash
git fetch origin main
git worktree add -b codex/my-short-task ../airo-my-short-task origin/main
cd ../airo-my-short-task
```

Use short-lived branches. Keep each PR focused on one logical change.

## Agent Policy Requirements

Before implementation for any feature, bug fix, architecture change, or
automation flow, the GitHub issue must include:

- Owning agent and impacted modules.
- Critical Agent gate.
- Cross-agent contract when more than one module or agent boundary is touched.
- Deterministic use cases.
- Automation flow.
- A framework/application/both classification.
- Confirmation that the task branch or worktree is based on latest
  `origin/main`.

The policy lives in [`docs/agents/AGENT_POLICY.md`](docs/agents/AGENT_POLICY.md).
Use it as the source of truth if this guide and the policy ever differ.

## Pull Request Checklist

Before opening a PR:

- Link the issue.
- Keep the diff scoped.
- Run `make format`.
- Run `make analyze` and/or package-specific analysis when relevant.
- Run `make test` or the smallest deterministic test target that covers the
  change.
- Update `docs/wiki` for user-visible behavior, install, privacy, model,
  troubleshooting, file-type, finance, media, route, or platform changes.
- Call out skipped checks and why they were skipped.
- Confirm no secrets, keystores, signing files, generated credentials, or
  personal data are committed.

Android Emulator usage must be explicitly accepted by the issue with
`AIRO_ALLOW_ANDROID_EMULATOR=true`. Otherwise use host-only checks, a physical
device, or a named simulator/device path.

## Documentation-Only Changes

For docs-only PRs, at minimum:

```bash
test -f README.md
test -f CONTRIBUTING.md
test -f CODE_OF_CONDUCT.md
rg "make setup|make analyze|make test|git worktree|pull request" README.md CONTRIBUTING.md
```

If you add local links, make sure they point to files that exist.

## Security And Privacy

Do not commit:

- API keys, access tokens, signing certificates, keystores, or passwords.
- Local configuration such as `app/android/key.properties`.
- Personal user data, private logs, screenshots with sensitive content, or
  production credentials.

Report vulnerabilities through [`SECURITY.md`](SECURITY.md) instead of opening a
public issue.

## Review Expectations

Maintainers optimize for changes that are:

- Small enough to review quickly.
- Grounded in an issue and deterministic acceptance criteria.
- Tested at the correct layer.
- Honest about limitations and skipped checks.
- Compatible with the framework/application ownership boundary.

When in doubt, open an issue with the problem and proposed shape before writing a
large patch.
