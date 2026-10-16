# Airo / Aika Stream — release checklist

**Purpose:** Track-specific gates before shipping. Complements (does not replace) `docs/release/RELEASE_CHECKLIST.md` and OKF playbooks.

**Last verified:** 2026-10-16 · `main` @ `6e86787985490a6b1c4a86eb801c3334b4bc8bcd`.

Check box = gate satisfied with cited evidence. Use status words in the **Status** column when a gate is not binary.

---

## Shared preflight (all tracks)

| Gate | Status | Evidence / command |
| --- | --- | --- |
| Branch from latest `origin/main` | **Done** | SHA `6e86787985490a6b1c4a86eb801c3334b4bc8bcd` |
| CI Continuous Integration green on release candidate SHA | **Done** (current `main`) | [Run 38715870317](https://github.com/DevelopersCoffee/airo/actions/runs/38715870317) |
| Semantic PR / commit policy | **Pending** | Required at PR merge time |
| No secrets in repo / release notes | **Done** | Policy; this doc contains no keystore material |
| `[skip ci]` only for non-executable changes | **Done** | `CLAUDE.md` / hooks policy |

---

## Track A — Aika Stream TV (Google Play)

**Package:** `com.developerscoffee.tv.midas` · **SSOT:** `app/pubspec_tv.yaml` · **Current:** `0.0.4+28`

| # | Gate | Status | Evidence |
| --- | --- | --- | --- |
| A1 | Version name/code only edited in `pubspec_tv.yaml` | **Done** | Line 14 |
| A2 | Stub synced | **Needs verification** | `scripts/aika_stream_version.sh --sync-stub` |
| A3 | Play `versionCode` never reused | **Needs verification** | OKF `docs/okf/aika-stream-play/rules/never-reuse-play-versioncode.md`; spent codes noted in version-ssot |
| A4 | Production keystore only (no validation keystore) | **Needs verification** | OKF `production-keystore-only.md`; human confirms |
| A5 | Build TV AAB with explicit build-name/number (spaces, not `=`) | **Needs verification** | `docs/okf/aika-stream-play/references/version-ssot.md` |
| A6 | `feature_iptv` + TV widget tests pass | **Needs verification** | CI passed; host rerun recommended |
| A7 | Physical device smoke (Pixel or TV) on **this** artifact | **Needs verification** | Last full evidence: Jul 2026 v0.0.5 |
| A8 | Release branch `release/aika-stream-v{versionName}` at build SHA | **Pending** | OKF cut-release-branch playbook |
| A9 | GitHub Release + notes for same version | **Pending** | Latest tag `aika-stream-v0.0.2` < pubspec 0.0.4 |
| A10 | Play Internal upload | **Blocked** | Human operator |
| A11 | Play Production promotion | **Blocked** | Human operator |
| A12 | Store listing / Data Safety / content rating docs current | **Needs verification** | `docs/release/AIKA_STREAM_*` — spot-check against build features |

**Post–build-19 note:** Historical OBB/train work lives on branches `feat/aika-stream-obb-19*`. Current SSOT is **+28**. Confirm Play Console live version before bumping.

---

## Track B — Airo super-app (phone)

**SSOT:** `app/pubspec.yaml` · **Current:** `0.1.0+13` (build **13** — not the same as Aika Stream build **28**)

| # | Gate | Status | Evidence |
| --- | --- | --- | --- |
| B1 | Phone pubspec version intentional | **Done** | `app/pubspec.yaml` |
| B2 | `flutter analyze` + format | **Needs verification** | Host-only; VM blocked |
| B3 | Full app CI variant green | **Done** | CI job `build-android (full, lib/main.dart, …)` run 38715870317 |
| B4 | Aggregate GitHub release (`v0.0.x` wave) if shipping with orchestrator | **Pending** | Latest `v0.0.6` (2026-08-03) vs pubspec `0.1.0+13` |
| B5 | Mind shell job green | **Done** | `airo-mind-shell` success run 38715870317 |
| B6 | Store/listing separate from Aika Stream | **Done** | Distinct package id and pubspec |

> **Amiro / Build 9:** If your release calendar uses an internal “Build 9” label for the phone app, map it to `version:` build number in `app/pubspec.yaml` and Play Console — no **Done** entry without that mapping evidence.

---

## Track C — Fire TV / Amazon Appstore (#2100)

**Pipeline PR:** [#2100](https://github.com/DevelopersCoffee/airo/pull/2100) (merged) · **CI flavor:** `fire-tv` · **Same entrypoint:** `lib/main_tv.dart` + `pubspec_tv.yaml`

| # | Gate | Status | Evidence |
| --- | --- | --- | --- |
| C1 | Fire OS Gradle variant builds in CI | **Done** | #2100; fire-tv job run 38715870317 |
| C2 | `scripts/check-fire-tv-release.sh` passes | **Done** | CI step on fire-tv matrix |
| C3 | GMS-free / Amazon policy gates documented | **Needs verification** | Review workflow comments in #2100 + store compliance docs |
| C4 | Fire TV signing secrets configured in CI | **Needs verification** | Workflow uses `FIRE_TV_RELEASE_KEYSTORE_BASE64` — presence not verified in this doc pass |
| C5 | Physical Fire TV qualification complete | **Needs verification** | Jul 2026 campaign INCOMPLETE |
| C6 | Amazon Appstore listing + submission | **Blocked** | Human + Amazon developer account |
| C7 | D-pad / focus defects closed for Fire | **Needs verification** | Branches around issue #1272 — audit merges |

**Do not** conflate Track C sign-off with Track A Play promotion — same codebase path, different store and test matrix.

---

## Track D — GitHub APK / aggregate releases (optional)

For sideload/GitHub users per `docs/release/GITHUB_APK_PUBLISHING_GUIDE.md`.

| # | Gate | Status | Evidence |
| --- | --- | --- | --- |
| D1 | Tag matches semver policy | **Needs verification** | `docs/release/VERSION_LINES.md` |
| D2 | Release orchestrator workflow YAML valid | **Done** | Part of PR validation ruby YAML checks on `main` |
| D3 | Artifact names match VERSION_LINES matrix | **Needs verification** | Per release cut |

---

## Open-source package publish (cross-cutting)

| # | Gate | Status | Evidence |
| --- | --- | --- | --- |
| O1 | Pub.dev packages match monorepo semver constraints | **Needs verification** | Spot-check: `airo_haptics` 1.2.0, `airo_pairing` 1.2.0 |
| O2 | Workspace shims stay `publish_to: none` | **Done** | e.g. `packages/platform_haptics/pubspec.yaml` line 7 |
| O3 | Migration docs updated per extraction | **Pending** | `docs/open-source/*-migration.md` |

---

## Sign-off roles

| Role | Aika Stream Play | Airo phone | Fire TV Amazon |
| --- | --- | --- | --- |
| Principal Architect | Required (docs + architecture) | Required | Required |
| PR Governor | Merge only | Merge only | Merge only |
| Release / DevEx | A10–A11 human | B4 orchestrator | C6 human |
| QA | A7 | **Needs verification** | C5, C7 |

---

## Quick command reference (host machine)

```bash
# TV version SSOT
grep '^version:' app/pubspec_tv.yaml
scripts/aika_stream_version.sh --sync-stub

# Tests (from Sept 2026 TV test plan)
cd packages/feature_iptv && flutter test
cd app && flutter test test/core/app/tv_shell_test.dart

# TV AAB (example — adjust name/code to target drop)
GRADLE_USER_HOME="$HOME/.gradle" \
  bash scripts/build-tv.sh --aab-only --build-name 0.0.4 --build-number 28
```

Cloud Agent VM (2026-10-16): Flutter SDK **not** on PATH — run the above on a developer host or download CI artifacts from [38715870317](https://github.com/DevelopersCoffee/airo/actions/runs/38715870317).
