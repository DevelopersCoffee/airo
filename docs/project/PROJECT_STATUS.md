# Airo / Aika Stream — project status

**Last verified:** 2026-10-16 (Cloud Agent on `origin/main` at `6e86787985490a6b1c4a86eb801c3334b4bc8bcd`)

**Pack:** Landed via [#2112](https://github.com/DevelopersCoffee/airo/pull/2112) (merged 2026-10-15). This file is the living SSOT; refresh after major releases or CI regressions.

**Method:** Historical agent notes (May–Sept 2026 gstack snapshots) were used for orientation only. Every status below is tied to current repo files, git refs, GitHub releases/PRs/CI, or in-repo QA evidence unless marked **Needs verification**.

**Allowed status words:** Done, Pending, Blocked, Deferred, Needs verification.

---

## 1. Baseline

| Item | Status | Evidence |
| --- | --- | --- |
| Default branch | **Done** | `main` @ `6e86787985490a6b1c4a86eb801c3334b4bc8bcd` (`git rev-parse HEAD origin/main`, 2026-10-16). Parent feature SHA `ce8fcaa6280582dbf59812036d8da4e970e09a7f` (#2108). |
| Airo super-app version (phone) | **Done** | `app/pubspec.yaml` line 19: `version: 0.1.0+13`. |
| Aika Stream TV version (SSOT) | **Done** | `app/pubspec_tv.yaml` line 14: `version: 0.0.4+28`. OKF: `docs/okf/aika-stream-play/references/version-ssot.md`. |
| Airo Coins flavor | **Done** | `app/pubspec_coins.yaml`: `0.0.7+12`. |
| Latest GitHub Release (org-wide) | **Done** | [Aika Stream 0.0.2](https://github.com/DevelopersCoffee/airo/releases/tag/aika-stream-v0.0.2) tag `aika-stream-v0.0.2` (2026-09-22). Prior TV-tagged release: `aika-stream-v0.0.1` (2026-09-15). Aggregate app line: `v0.0.6` (2026-08-03). |
| Open pull requests | **Done** | Three open Dependabot PRs only (#2111, #2110, #2109) as of 2026-10-16 (`gh pr list --state open`). |
| Remote branch surface | **Done** | ~459 remote-tracking branches (`git branch -r \| wc -l`, 2026-10-16). Active IPTV/TV lines include `origin/agent/iptv/aika-stream-*`, `origin/feat/aika-stream-obb-19*`, `origin/agent/tv/2014-aika-stream-tv-19`, `origin/cursor/fire-tv-build-pipeline-ff46` (merged via #2100). |
| Local worktrees on this VM | **Done** | Single checkout at `/workspace`; no additional agent worktrees mounted on this Cloud Agent VM. |

### Release tracks (keep separate)

| Track | Status | Evidence |
| --- | --- | --- |
| **Aika Stream TV / Play** (`com.developerscoffee.tv.midas`) | **Needs verification** | Pubspec SSOT `0.0.4+28` on `main`. GitHub release tag stops at `aika-stream-v0.0.2`. Play `versionCode` spend and live Production state are human-gated — see `docs/okf/aika-stream-play/references/version-ssot.md` (codes 21–25 spent as of 2026-09-28 note). |
| **Airo super-app (phone)** | **Pending** | `0.1.0+13` on `main`; not aligned with latest aggregate GitHub release `v0.0.6` naming — see `docs/release/VERSION_LINES.md`. |
| **Fire TV / Amazon Appstore** | **Done** (pipeline) | [#2100](https://github.com/DevelopersCoffee/airo/pull/2100) merged: Fire OS build variant + CI leg. Latest full matrix on pack SHA: [38715870317](https://github.com/DevelopersCoffee/airo/actions/runs/38715870317) job `build-android (fire-tv, …)` **success** (2026-10-15). Store submission state: **Needs verification** (no Appstore listing evidence in repo). |

> **Note on “Amiro Build 9”:** No release artifact or pubspec in this repository uses the label “Amiro Build 9”. Treat **Airo super-app** (`app/pubspec.yaml`, currently build **13**) and **Aika Stream TV** (`app/pubspec_tv.yaml`, currently build **28**) as distinct tracks. If “Build 9” refers to an external Play or internal codename, status is **Needs verification**.

---

## 2. Stabilize (compile, tests, CI)

| Item | Status | Evidence |
| --- | --- | --- |
| CI on `main` (full matrix) | **Done** | [Workflow run 38715870317](https://github.com/DevelopersCoffee/airo/actions/runs/38715870317) **success** on `6e867879` (#2112 merge): `analyze`, `lint`, `test-core`, `test-app`, `build-web`, `build-android` **tv**, **fire-tv**, **full**, **coins**, `airo-mind-shell`, security scans. Prior green push: [38605508681](https://github.com/DevelopersCoffee/airo/actions/runs/38605508681) (#2108). |
| Phone app compile/analyze (this VM) | **Blocked** | `flutter` SDK not available on PATH in this Cloud Agent VM (`which flutter` empty, 2026-10-16). Cannot reproduce analyze locally here. |
| TV / Fire TV compile (this VM) | **Blocked** | Same Flutter SDK gap; rely on CI `build-android` tv + fire-tv jobs above. |
| `feature_iptv` unit tests (this VM) | **Blocked** | Flutter SDK missing locally; CI `test-app` on run 38715870317 **success**. |
| Repository script gates (docs change scope) | **Done** | `scripts/check-docs-completeness.sh --base origin/main --head HEAD` passed (2026-10-16). |

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
| **Model download / storage / readiness** | **Done** (core pipeline) | `ModelReadinessService` + tests in `packages/core_ai` (`7b02f167`, `3f79faf8` on `main`). Branch `origin/agent/mind/j1-audio-preprocess` **not merged** — full J1 multimodal plan partially superseded on `main`. |
| **Agent Mind J1 audio / multimodal preprocess** | **Pending** | Plan in gstack (2026-08-16); branch exists (`origin/agent/mind/j1-audio-preprocess`) but not ancestor of `main`. Whisper/encoder fusion beyond catalog tags: **Deferred**. |

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
