# Airo / Aika Stream — project backlog

**Last verified:** 2026-10-24 (Asia/Calcutta) against `origin/main` @ `69f354f86cf421fc0ebe651586306118504d491e`.

Status words: **Done**, **Pending**, **Blocked**, **Deferred**, **Needs verification** only.

Priority is top-down within each section; cross-track items name their release line explicitly.

---

## P0 — Stabilize and prove `main`

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-001 | Keep `main` CI green on all Android variants (full, tv, fire-tv, coins) | **Done** | [CI run 40032582357](https://github.com/DevelopersCoffee/airo/actions/runs/40032582357) success (2026-10-23). |
| B-002 | Re-run `feature_iptv` + TV shell tests on developer host | **Needs verification** | Commands from Sept 2026 test plan: `cd packages/feature_iptv && flutter test`; `cd app && flutter test test/core/app/tv_shell_test.dart`. CI passed; local Flutter missing on Cloud Agent VM. |
| B-003 | Close Dependabot Android bumps (#2111–#2109) or merge when vetted | **Pending** | Open PRs as of 2026-10-16. |

---

## P1 — Device qualification (physical)

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-010 | Pixel 9 regression on **current** TV build | **Needs verification** | Baseline: `docs/release/evidence/AIRO_TV_V0.0.5_PIXEL9_QA.md`. Rerun with artifact built from target release SHA; verify #1142 / #1143 fixes. |
| B-011 | Fire TV Stick — complete 720p matrix | **Needs verification** | `docs/release/evidence/airo-tv-physical-device-qa-2026-07-27.md` INCOMPLETE. Configure 720p; physical remote D-pad; document in `docs/release/evidence/`. |
| B-012 | D-pad / focus qualification (Google TV, Android TV density classes) | **Needs verification** | Missing devices in Jul 2026 campaign. Use `docs/release/RELEASE_DEVICE_QUALIFICATION.md` + optional `dpad_qualification` pub.dev **1.1.0** for emulator prep only. |
| B-013 | Long playback + memory soak (2h+) | **Needs verification** | No current-SHA evidence in repo. |
| B-014 | Fire TV CI artifact smoke on physical Fire OS | **Needs verification** | CI builds fire-tv (#2100); on-device install/signing not recorded post-merge. |

---

## P2 — Aika Stream TV / Play track

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-020 | Align GitHub release tag with pubspec SSOT (`0.0.4+28`) | **Pending** | Pubspec: `app/pubspec_tv.yaml`. Latest GitHub release: `aika-stream-v0.0.2`. |
| B-021 | Play drop checklist (Internal → Production) | **Blocked** | Human upload/promotion per `docs/okf/aika-stream-play/playbooks/internal-then-production.md`; agent cannot verify Production Latest. |
| B-022 | Settings expansion slice 2+ (resume last channel, sleep timer, source headers, EPG offset) | **Pending** | Slice 1 **Done** (#2042, #2054). Plan: `docs/superpowers/plans/2026-09-22-aika-stream-settings.md`; specs e.g. `docs/superpowers/specs/2026-09-23-tv-resume-last-channel-design.md`. |
| B-023 | Reconcile spent Play versionCodes with next bump | **Needs verification** | OKF: `docs/okf/aika-stream-play/references/version-ssot.md` — do not reuse 21–25. Confirm next code with Play Console before edit. |
| B-024 | Archive or merge stale `aika-stream-obb-19` / `tv-19` branches | **Pending** | Remote branches exist; SSOT at +28. Audit for unmerged fixes before delete. |

---

## P3 — Airo super-app (phone) track

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-030 | Phone app release alignment (`0.1.0+13` vs aggregate `v0.0.6` line) | **Pending** | `app/pubspec.yaml`; naming: `docs/release/VERSION_LINES.md`. |
| B-031 | Mind / Intelligence readiness UX on desktop vs Android LiteRT | **Pending** | `ModelReadinessService` on `main`; full J1 branch not merged (`origin/agent/mind/j1-audio-preprocess`). |

---

## P4 — Fire TV / Amazon Appstore track

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-040 | Maintain Fire OS CI leg (GMS-free gates) | **Done** | #2100 merged; fire-tv job green on run 38715870317. |
| B-041 | Amazon Appstore listing + submission | **Blocked** | Requires store account, signing, and completed B-011/B-014 qualification. |
| B-042 | Fire TV–specific D-pad defects (e.g. issue #1272 lineage) | **Needs verification** | Remote branches `fix/firetv-playlist-modal-focus-1272`, `codex/issue-1272-firetv-dpad` — merge status not re-audited in this pass. |

---

## P5 — Integration & platform packages

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-050 | `airo_haptics` consumption via `platform_haptics` | **Done** | pub.dev 1.2.0; `feature_iptv` mapper + tests. |
| B-051 | `airo_local_l10n` create/publish/integrate | **Deferred** | Not in monorepo or pub.dev; only external agent plans. Until spec lands in repo: extract locale seam from `core_app_shell`. |
| B-052 | `core_pairing` / `airo_pairing` drift | **Done** | pub.dev 1.2.0; monorepo tests in `packages/core_pairing/test/`. |
| B-053 | `airo_job_scheduler` via `platform_worker_jobs` | **Done** | pub.dev 1.1.0. |
| B-054 | Open-source extraction backlog (remaining packages) | **Pending** | `docs/open-source-roadmap.md`, `docs/open-source-candidate-audit.md`. |
| B-055 | `dpad_qualification` v1.1 trust patch | **Deferred** | External repo roadmap (gstack 2026-09-15); independent of Aika Stream ship. |

---

## P6 — Documentation & governance

| ID | Item | Status | Evidence / next step |
| --- | --- | --- | --- |
| B-060 | Project status pack under `docs/project/` | **Done** | [#2112](https://github.com/DevelopersCoffee/airo/pull/2112) merged → `6e867879`; index `docs/project/README.md`. |
| B-061 | Refresh stale release evidence index | **Pending** | Many `docs/release/evidence/*` artifacts predate `0.0.4+28`. |
| B-062 | Repository health preflight for next wave | **Needs verification** | `docs/release/REPOSITORY_HEALTH_STATUS.md` — requires maintainer env vars for green preflight. |

---

## Icebox (explicitly out of scope for current wave)

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| B-900 | Cloud-synced IPTV settings | **Deferred** | Settings plan NOT in scope slice 1. |
| B-901 | Full multimodal fusion (Whisper + vision encoders) | **Deferred** | J1 plan Phase 3+ only. |
| B-902 | V1 monolith `v1` branch resurrection | **Deferred** | `docs/release/VERSION_LINES.md` — active work on `main`. |
