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

Each surface resolves to its own device — no shared auto-detect, so a connected
Fire TV Stick can never stand in for the phone and a paired iPhone can never
stand in for the iPad.

| Surface | Device | Run it with | Override |
|---|---|---|---|
| Phone / touch | Pixel 9 | `make run-android` | `AIRO_PHONE_DEVICE` |
| Tablet / iOS | iPad Air 4 | `make run-ios`, `make qualify-ipad` | `AIRO_TABLET_DEVICE` |
| Ten-foot / TV | Fire TV Stick 4K | `make run-firetv`, `make build-firetv` | `AIRO_TV_DEVICE` |

`scripts/select_rig_device.sh phone|tablet|tv` owns that resolution and every
entry point calls it — the Makefile targets, the agent-skills journey, and the
visual qualification pass. It never falls back to a simulator, and it refuses to
guess: zero matches or more than one is an error naming what it found. Fire TV
hardware is identified by `model:AFT*`, the iPad by name.

`make run-android-auto` is the deliberate escape hatch that skips this
separation and takes any Android device, Fire TV Stick included.

Watch the target names: `make run-pixel9` and `make run-iphone17` drive an
**emulator and a simulator**, not the rig above — `run-pixel9` boots a QEMU AVD,
not the physical Pixel 9. They survive only as the explicit opt-in path; the
other simulator-only targets were removed on 2026-07-28.

The Android Emulator stays gated behind `AIRO_ALLOW_ANDROID_EMULATOR=true`. A
`qemu-system-aarch64 EXC_BAD_ACCESS / KERN_INVALID_ADDRESS` crash on macOS is an
infrastructure failure, not an app regression: stop the run, preserve the crash
report, continue on host checks or the physical device, and do not retry in a
loop.

The Fire TV Stick joins over the network before anything can see it:
`adb connect <stick-ip>:5555`.

Name the environment used — host-only, Pixel 9, iPad, Fire TV, or an explicit
emulator opt-in — in the issue and the PR.

## CI spend

GitHub Actions minutes are shared cost. Prove correctness locally first and keep
remote CI for the cases that need it.

1. Mark iterative issue commits and integration-branch merge commits `[skip ci]`
   when the commit does not change executable behaviour — see "Skipping CI"
   below for the line.
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

## Skipping CI

`[skip ci]` saves minutes on commits that cannot break anything. It is not a way
to land code faster.

**Allowed** — documentation, comments, markdown, release notes, issue and PR
templates, other non-executable metadata.

**Not allowed** — anything under `app/`, `packages/`, `packages_pro/`, `rust/`,
`e2e/`, `scripts/`, `tool/`; `Makefile`, `melos.yaml`, Gradle, Cargo, or
`pubspec` files; `.github/workflows/`. A change to any of these must be proven
by a CI run.

`scripts/check_skip_ci.sh` enforces this from the `commit-msg` hook. Install it
once per clone with `make install-hooks`; it lives in git rather than any one
tool's config, so it applies to every committer, human or agent. Split the
executable part into its own commit rather than working around it.

*Why:* on 2026-07-29, `c2ada89f` renamed a UI string to sentence case, updated
the `feature_iptv` tests it owned but not the one in `app/test`, and shipped
`[skip ci]`. Nothing ran. `main` went red on the next unrelated push, and the
cost of finding it landed on someone who had not touched that code.

## Dependency pins

When a dependency is pinned back because a version is broken, the pin and the
guard are two separate jobs, and the guard is the one that gets forgotten:

1. Pin the version, with a comment naming the symptom and the prior reverts.
2. Add the Dependabot `ignore` entry — on the coordinate Dependabot actually
   bumps, which for Gradle plugins is the plugin id (`com.android.application`),
   not the artifact (`com.android.tools.build:gradle`).
3. **Search for already-open PRs matching the new ignore and close them.** An
   `ignore` rule only stops Dependabot opening *future* PRs; it does not
   withdraw one already in flight.
   ```bash
   gh pr list --repo DevelopersCoffee/airo --author app/dependabot \
     --search "<dependency>" --state open
   ```
4. Confirm the pin survives on `main` after the next merge.

*Why:* AGP 9.3.x has been reverted three times. `9.3.0` in `249ad2eb` (#1011),
`9.3.1` via #1336, and `9.3.1` again when #1349 — already open before the ignore
rule existed — was merged and silently undid the pin, leaving a comment reading
"Pinned to 9.2.1" directly above `version "9.3.1"`. Step 3 is the step that was
missing.

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
