# Airo / Aika Stream — project status

**Last verified:** 2026-10-24 (Asia/Calcutta) · `origin/main` @ `69f354f86cf421fc0ebe651586306118504d491e`

**Pack:** [#2112](https://github.com/DevelopersCoffee/airo/pull/2112), [#2113](https://github.com/DevelopersCoffee/airo/pull/2113). Living SSOT — refresh after major releases or CI regressions.

**Method:** Historical agent notes (May–Sept 2026 gstack snapshots) were used for orientation only. Every status below is tied to current repo files, git refs, GitHub releases/PRs/CI, or in-repo QA evidence unless marked **Needs verification**.

**Allowed status words:** Done, Pending, Blocked, Deferred, Needs verification.

---

## 1. Baseline

| Item | Status | Evidence |
| --- | --- | --- |
| Default branch | **Done** | `main` @ `69f354f86cf421fc0ebe651586306118504d491e` (`git rev-parse origin/main`, 2026-10-24). |
| Airo super-app version (phone) | **Done** | `app/pubspec.yaml` line 19: `version: 0.1.0+13`. |
| Aika Stream TV version (SSOT) | **Done** | `app/pubspec_tv.yaml` line 14: `version: 0.0.4+28`. OKF: `docs/okf/aika-stream-play/references/version-ssot.md`. |
| Airo Coins flavor | **Done** | `app/pubspec_coins.yaml`: `0.0.7+12`. |
| Latest GitHub Release (org-wide) | **Done** | [Aika Stream 0.0.2](https://github.com/DevelopersCoffee/airo/releases/tag/aika-stream-v0.0.2) tag `aika-stream-v0.0.2` (2026-09-22). Prior TV-tagged release: `aika-stream-v0.0.1` (2026-09-15). Aggregate app line: `v0.0.6` (2026-08-03). |
| Open pull requests | **Needs verification** | Re-run `gh pr list --state open` before the next release; count changes frequently. |
| Remote branch surface | **Done** | Many remote-tracking branches on `origin`; IPTV/TV lines include `origin/agent/iptv/aika-stream-*`, `origin/feat/aika-stream-obb-19*`, Fire TV pipeline merged via #2100. |
| Local worktrees on this VM | **Done** | Single checkout at `/workspace`; no additional agent worktrees mounted on this Cloud Agent VM. |

### Release tracks (keep separate)

| Track | Status | Evidence |
| --- | --- | --- |
| **Aika Stream TV / Play** (`com.developerscoffee.tv.midas`) | **Needs verification** | Pubspec SSOT `0.0.4+28` on `main`. GitHub release tag stops at `aika-stream-v0.0.2`. Play `versionCode` spend and live Production state are human-gated — see `docs/okf/aika-stream-play/references/version-ssot.md` (codes 21–25 spent as of 2026-09-28 note). |
| **Airo super-app (phone)** | **Pending** | `0.1.0+13` on `main`; not aligned with latest aggregate GitHub release `v0.0.6` naming — see `docs/release/VERSION_LINES.md`. |
| **Fire TV / Amazon Appstore** | **Done** (pipeline) | [#2100](https://github.com/DevelopersCoffee/airo/pull/2100) merged. Latest full matrix: [40032582357](https://github.com/DevelopersCoffee/airo/actions/runs/40032582357) job `build-android (fire-tv, …)` **success** (2026-10-23). Store submission: **Needs verification**. |

> **Note on “Amiro Build 9”:** No release artifact or pubspec in this repository uses the label “Amiro Build 9”. Treat **Airo super-app** (`app/pubspec.yaml`, currently build **13**) and **Aika Stream TV** (`app/pubspec_tv.yaml`, currently build **28**) as distinct tracks. If “Build 9” refers to an external Play or internal codename, status is **Needs verification**.

---

## 2. Stabilize (compile, tests, CI)

| Item | Status | Evidence |
| --- | --- | --- |
| CI on `main` (full matrix) | **Done** | [Workflow run 40032582357](https://github.com/DevelopersCoffee/airo/actions/runs/40032582357) **success** on `69f354f8`: `analyze`, `lint`, `test-core`, `test-app`, `build-web`, `build-android` **tv**, **fire-tv**, **full**, **coins**, `airo-mind-shell`, security scans. |
| Phone app compile/analyze (this VM) | **Blocked** | Flutter SDK not on PATH on this Cloud Agent VM (2026-10-24). Use CI or a developer host. |
| TV / Fire TV compile (this VM) | **Blocked** | Same Flutter SDK gap; rely on CI `build-android` tv + fire-tv jobs above. |
| `feature_iptv` unit tests (this VM) | **Blocked** | Flutter SDK missing locally; CI `test-app` on run 40032582357 **success**. |
| Repository script gates (docs change scope) | **Done** | `scripts/check-docs-completeness.sh --base origin/main --head HEAD` passed (2026-10-24). |

**CI commands reference (for humans re-running):** `.github/workflows/ci.yml` — matrix includes `fire-tv` with description “Fire OS / Amazon Appstore (Aika Stream, GMS-free gates)” (lines ~500–508, ~759).

---

## 3. Qualify devices (evidence in repo + notes)

Physical retest on this agent: **Blocked** (no physical TV/phone attached). Status reflects **documented evidence only**.

| Campaign | Status | Evidence |
| --- | --- | --- |
| Pixel 9 — published `Airo-TV-0.0.5` APK | **Needs verification** | In-repo evidence: `docs/release/evidence/AIRO_TV_V0.0.5_PIXEL9_QA.md` (2026-07-26). Issues [#1142](https://github.com/DevelopersCoffee/airo/issues/1142), [#1143](https://github.com/DevelopersCoffee/airo/issues/1143). **Rerun:** install current TV artifact matching target release; repeat flows in evidence doc; confirm Settings Back and native libs on cold start. |
| Fire TV Stick 3rd Gen physical QA | **Needs verification** | `docs/release/evidence/airo-tv-physical-device-qa-2026-07-27.md` — campaign **INCOMPLETE**; 1080p vs required 720p profile not verified; D-pad/playback matrix gaps. **Rerun:** configure 720p output per Amazon spec; repeat D-pad, language picker, long-playback soak per `docs/release/RELEASE_DEVICE_QUALIFICATION.md`. |
| D-pad navigation (Fire TV stick) | **Needs verification** | `docs/release/evidence/airo-tv-dpad-fire-tv-stick-3rd-gen-2026-07-27.md`. **Rerun:** physical remote only (no ADB-as-remote credit). |
| Aika Stream TV `0.0.1+19` test plan (Sept 2026 notes) | **Needs verification** | gstack test plan mapped widget tests (`feature_iptv`, `tv_shell_test.dart`); pubspec on `main` is now `0.0.4+28`, not `+19`. **Rerun:** `cd packages/feature_iptv && flutter test`; `cd app && flutter test test/core/app/tv_shell_test.dart`; then device flows in plan (QR home, Watch pop stop, transport row, mini guide). |
| Long playback / memory soak | **Needs verification** | Not re-run on current `main` SHA in repo evidence. **Rerun:** 2+ hour live playback on target STB with memory profiler; file under `docs/release/evidence/`. |
| `dpad_qualification` harness (package) | **Deferred** | External package on pub.dev `1.1.0`; roadmap in gstack note (2026-09-15) — not a substitute for physical STB sign-off. |

---

## 4. Integration gaps (plans vs `main`)

| Area | Status | Evidence |
| --- | --- | --- |
| **airo_haptics / Aika haptics** | **Done** | `packages/platform_haptics/pubspec.yaml` depends on `airo_haptics: ^1.2.0` (pub.dev **1.2.0**). Application mapper: `packages/feature_iptv/lib/application/aika_haptics.dart`, provider, widget call sites + tests. *Sept 2026 spec claimed engine not on `main` — superseded.* |
| **airo_local_l10n** | **Deferred** | No `airo_local_l10n` package in monorepo; not on pub.dev (API 404, 2026-10-15). Appears only in external agent walkthrough titles (agent-work-index). Locale today: `packages/core_app_shell` / `airo_locale_settings` keys in app tests. |
| **Pairing** | **Done** | Monorepo shim `packages/core_pairing` re-exports pub.dev `airo_pairing` **1.2.0** (`pubspec.yaml` lines 13–14). |
| **Job scheduler** | **Done** | Consumed via `packages/platform_worker_jobs` → `airo_job_scheduler: ^1.1.0` (pub.dev **1.1.0**). |
| **Aika Stream settings expansion (slice 1)** | **Done** | Merged: [#2042](https://github.com/DevelopersCoffee/airo/pull/2042) (`c5b2de22`), [#2054](https://github.com/DevelopersCoffee/airo/pull/2054) (`b244abac`); manifest `IptvSettingsSectionId.accessibility` in `packages/feature_iptv_core/lib/src/iptv_settings_manifest.dart`. Follow-up slices (sleep timer, resume, headers) per plan: **Pending** — `docs/superpowers/plans/2026-09-22-aika-stream-settings.md`. |
| **Model download / storage / readiness** | **Done** (core pipeline) | `ModelReadinessService` in `packages/core_ai`. LiteRT-LM runtime/tooling expanded on `main` (e.g. `packages/core_ai/lib/src/litert/litert_lm_tool_loop.dart`, `litert_lm_runtime_adapter.dart`; Android `LiteRtLmPlugin.kt`). |
| **Agent Mind J1 audio / multimodal preprocess** | **Pending** | Gstack plan (2026-08-16); `origin/agent/mind/j1-audio-preprocess` not merged. On-device LiteRT + Mind reasoning tools advanced separately on `main` — **Needs verification** against J1 acceptance criteria before marking Done. |

---

## 5. Release & open source

| Item | Status | Evidence |
| --- | --- | --- |
| Post–build-19 TV train | **Needs verification** | Branches `feat/aika-stream-obb-19*`, `agent/tv/2014-aika-stream-tv-19` exist; SSOT now `0.0.4+28`. Map each Play drop to git SHA via `release/aika-stream-v*` branches per OKF — not automated in this doc. |
| GitHub release notes vs pubspec | **Pending** | Latest tagged GitHub Aika Stream release **0.0.2** lags pubspec **0.0.4** on `main`. |
| Open-source packages on pub.dev | **Done** | Matrix: `docs/open-source-roadmap.md` (Phase 8 table). Live versions sampled 2026-10-15: `airo_haptics` 1.2.0, `airo_pairing` 1.2.0, `airo_job_scheduler` 1.1.0, `airo_epg` 1.2.0, `dpad_qualification` 1.1.0, `run_off_main` 1.1.0, `iptv_org_api` 2.1.0, etc. |
| Monorepo `airo_*` stubs (`publish_to: none`) | **Done** | e.g. `packages/airo_background_downloads`, `packages/airo_license`, `packages/airo_notifications`, `packages/airo_pro_bootstrap` — workspace copies; consumption is via pub.dev packages through shims (`platform_haptics`, `core_pairing`, …). |
| Fire TV store release | **Blocked** | CI/build **Done** (#2100); Amazon Appstore human submission and listing compliance **Blocked** on store credentials and QA sign-off outside repo. |

---

## Notes vs code — contradictions logged

| Claim (historical notes) | Current repo truth |
| --- | --- |
| Aika Stream TV test target `0.0.1+19` (Sept 2026) | `app/pubspec_tv.yaml` is `0.0.4+28` on `main`. |
| `airo_haptics` 1.1.0 “not on `origin/main`” (Sept 2026 design spec) | Haptics integrated on `main` with pub.dev `airo_haptics` **1.2.0**. |
| Settings work only on branch `agent/iptv/aika-stream-settings-slice-1` | Slice 1 landed via #2042 / #2054; branch not merge-ancestor of `main` but features present. |
| QA package id `io.airo.app.tv` (Jul 2026 Pixel 9 evidence) | TV Android `applicationId` for tv/fireTv flavors: `com.developerscoffee.tv.midas` (`app/android/app/build.gradle.kts`). Rebrand/consistency: **Needs verification** on old APKs vs current builds. |

---

## Related documents

- `PROJECT_BACKLOG.md` — ordered follow-ups.
- `PROJECT_EXECUTION_PLAN.md` — phased execution.
- `PROJECT_RELEASE_CHECKLIST.md` — release gates by track.
- Existing release corpus: `docs/release/`, `docs/okf/aika-stream-play/`.
