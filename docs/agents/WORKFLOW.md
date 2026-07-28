# Airo Workflow

Single owner of process: branches, commits, validation, device choice, CI spend,
PRs, and issue close-out. `AGENTS.md` carries the one-line summaries; the detail
lives here so it is only in context when it matters. Ownership and readiness
gates live in [AGENT_POLICY.md](./AGENT_POLICY.md); reviewer routing lives in
[COUNCIL.md](./COUNCIL.md).

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

Branch names: `agent/<agent-name>/<issue>-<short-description>`, e.g.
`agent/finance/8-save-expense-flow`. Commits follow Conventional Commits with
the agent or package as scope:
`feat(finance): add save expense to transaction flow`.

## Validation and device choice

Host-only checks come first — `flutter analyze`, `flutter test`, package tests,
web/Playwright checks, APK build checks. Run the narrowest set that proves the
touched contract.

**Device verification runs on real hardware. Simulators and emulators are not
the rig.** The three devices under active test:

| Surface | Device | Run it with |
|---|---|---|
| Phone / touch | Pixel 9 | `make run-android` (auto-detects the connected device) |
| Tablet / iOS | iPad Air 4 | `make run-ios`, `scripts/run_visual_qualification.sh` |
| Ten-foot / TV | Fire TV Stick 4K | `make run-firetv`, `make build-firetv` |

Watch the target names: `make run-pixel9`, `run-iphone13`, `run-iphone17`,
`run-firetv-emulator`, `run-androidtv`, `boot-local-devices`, and
`deploy-local-binaries` all drive **emulators and simulators**, not the rig
above. `make run-pixel9` boots a QEMU AVD, not the physical Pixel 9.

The Android Emulator stays gated behind `AIRO_ALLOW_ANDROID_EMULATOR=true`. A
`qemu-system-aarch64 EXC_BAD_ACCESS / KERN_INVALID_ADDRESS` crash on macOS is an
infrastructure failure, not an app regression: stop the run, preserve the crash
report, continue on host checks or the physical device, and do not retry in a
loop.

Android journeys take the device serial —
`AIRO_JOURNEY_ANDROID_DEVICE=<adb-serial>`. A Fire TV Stick joins over the
network first: `adb connect <stick-ip>:5555`.

Name the environment used — host-only, Pixel 9, iPad, Fire TV, or an explicit
emulator opt-in — in the issue and the PR.

## CI spend

GitHub Actions minutes are shared cost. Prove correctness locally first and keep
remote CI for the cases that need it.

1. Mark iterative issue commits and integration-branch merge commits `[skip ci]`
   unless the change is a release verification step or a maintainer asked for a
   run.
2. Treat release, signing, Play upload, APK/AAB artifact, full Android matrix,
   emulator, and broad integration workflows as opt-in — required by branch
   protection, the release owner, or the issue.
3. Push issue branches rather than pushing work-in-progress straight to `main`;
   release-line pushes also trigger Pages and release workflows.
4. Do not re-run a workflow unless a failed *required* check is relevant to the
   change. Cancel accidental or redundant runs with `gh run cancel <run-id>`.
5. Avoid empty commits, no-op pushes, repeated metadata-only pushes, and branch
   churn: they burn minutes without changing reviewable behavior.
6. When remote CI genuinely is required, say why in the issue or PR before
   pushing without `[skip ci]`.

## Pull requests

- Issue linked, acceptance criteria met, branch current with `main`, no
  conflicts.
- `flutter analyze` and `flutter test` clean for the touched packages.
- Verification environment named.
- Keep the diff reviewable. A PR over ~500 lines usually wants splitting.
- Secrets never land in code or issue text — reference them by name. See
  [SECURITY.md](../../SECURITY.md).

## Closing issues

Close an issue once its bounded acceptance criteria are met and the local
validation evidence is recorded on the issue. Do not hold a completed slice open
for optional CI, broad matrix runs, release artifacts, or physical-device
evidence — track those as follow-up. Equally, do not close before the required
policy artifacts, deterministic use cases, and validation notes are present.

Issue state lives on the
[project board](https://github.com/orgs/DevelopersCoffee/projects/2), not in a
separate tracker. Every issue carries `agent/<name>`, `priority/P0|P1|P2`, and
`type/task|bug|feature`.

## Coverage targets

Core packages ≥ 80 %, feature packages ≥ 60 %. A change that drops a package
below its target needs a reason in the PR.
