# Airo TV v0.0.6-rc.1 local-file Cast qualification

Status: **COMPLETE FOR PARKED SCOPE — BRAVIA playback controls deferred by
release-owner direction on 2026-08-02**

Qualification date: 2026-08-01/02 (Asia/Kolkata)

## Critical Agent Gate — VirusTotal release failure

**Problem:** The published `v0.0.6-rc.1` VirusTotal workflow failed before
scanning because it requested the removed, hard-coded asset
`Airo-TV-0.0.5.apk`.

**User / actor:** Release and DevEx operator.

**Framework or application layer:** Release automation only.

**Owning agent:** Chief Release/DevOps Officer.

**Reviewing agents:** Chief QA Officer.

**Impacted files:** `.github/workflows/virustotal-scan.yml`, CI workflow
validation, and the canonical-TV-APK resolver/tests under `scripts/`.

**Base branch/worktree:** Fresh `origin/main` at
`dc7406d64b6323027974abab4617720fb31484f9`; confirmed to contain
`ea217b9802f8b092e1438008bfedf815f680241c`.

**Open questions:** None. Release asset selection must fail closed when the
canonical APK is absent or ambiguous.

**Decision:** Ready. The failure was reproduced from Actions run
`30695660898`; no media-pipeline code is involved.

### Deterministic use cases

- A release containing one canonical TV APK plus ABI splits resolves the
  canonical APK.
- A release containing only ABI splits fails closed.
- A release containing multiple canonical APKs fails closed.

### Automation flow

`python3 scripts/test_resolve_release_tv_apk.py` exercises all three cases.
The current release's live asset JSON resolves to
`Airo-TV-0.0.6-rc.1.apk`.

## Source and artifact provenance

### Published dogfood release used on Pixel 9

- Release/tag: `v0.0.6-rc.1`
- Source SHA: `9868f48ffd46d9124d3d521074bdfe481452ada5`
- Required ancestor: `ea217b9802f8b092e1438008bfedf815f680241c`
  (verified with `git merge-base --is-ancestor`)
- Release Orchestrator: Actions run `30693913137`, success
- TV release checks and TV APK/AAB build jobs: success
- Canonical APK: `Airo-TV-0.0.6-rc.1.apk`
- APK SHA-256:
  `c977767ea448a067d5b24408afa818266c1f43ebab8c66861fc3b930ce7b6458`
- Pixel-installed `base.apk`: byte-identical to the published canonical APK
- Signing certificate: `CN=Airo Dogfood, O=DevelopersCoffee, C=US`

### Fresh local validation build

- Worktree: `airo-worktrees/tv-cast-qualification-20260801`
- Branch: `agent/release/tv-cast-qualification-20260801`
- Source SHA: `dc7406d64b6323027974abab4617720fb31484f9`
- Required ancestor: `ea217b9802f8b092e1438008bfedf815f680241c`
- Profile/version: `tv`, `0.0.6-rc.1+6`
- Command: `make build-tv`
- Result: pass; Android TV release checker reported compile SDK 36, target SDK
  36, and minimum required SDK 34
- APK SHA-256:
  `38d2e6796bd0c8721036b8cdd408585fb6e13289132280`
- AAB SHA-256:
  `62583e0a65703e459951ee176a41718b85052edded8a7394ba6dde97bad175a0`
- Local manifest: `artifacts/release-qualification/0.0.6-rc.1-tv-cast-20260801/Release-Manifest.json`

## Quality gates

- SonarCloud for published source `9868f48f`: success, CI run `30693294351`
- SonarCloud for local-build source `dc7406d6`: success, CI run `30706339035`
- Build profiles, bundled-model guard, module manifests, module sizes, worker
  offload, release-manifest tests, and qualification-report tests: pass
- `packages/core_release`: 90 tests passed
- Latest-base CI run `30718686035` passed for exact `f54ffeb7`, including
  `sonarcloud-scan`, analyzer, tests, and the TV build job.
- TV router/main analyzer and tests: pass (34 tests)
- `feature_iptv` focused Cast/UI tests: pass (63 tests); analyzer completed
  under the release workflow's non-fatal warning policy with four existing
  test-import warnings
- `platform_media` full package suite: pass (157 tests)
- `platform_player` full package suite: pass (222 tests)
- V2 merge-readiness unit test and `HEAD`/`HEAD` dry run: structural pass;
  public readiness remains unresolved while device evidence is incomplete

## Physical device evidence

### Resumed candidate after verified picker failure

- Worktree was fast-forwarded to current `origin/main` at
  `f54ffeb73a65ecdc696c147a5a03c27cad37bf05` before applying the fix; the
  required `ea217b98` commit remains an ancestor.
- The published APK physically exposed `Play file on TV`, but three
  deterministic taps closed the drawer without starting DocumentsUI.
- Android's document picker resolves successfully from the shell, while the
  TV manifest omitted an `ACTION_OPEN_DOCUMENT` package-visibility query.
  On Android 11+, the plugin's `Intent.resolveActivity()` therefore returned
  null and produced `picker_unavailable`, which Dart treated as cancellation.
- Fix: declare the video-only `ACTION_OPEN_DOCUMENT` query in the TV manifest
  and enforce it in `scripts/check-android-tv-release.sh`.
- Fresh split-ABI release APK build: pass.
- Arm64 APK SHA-256:
  `0798fb096c58a401248a95b7d627f5deb52081efc422ad5d42ba4686c6f553d6`
- Armeabi-v7a APK SHA-256:
  `03df159afd1f6898ddb9bd270dcae50393ae62562e2548c3d0a80ce6b4c9167c`
- AAB size/SHA-256: 71,222,884 bytes,
  `2d51d09e14316df35c59f3abb7617cfb7d0e30c80158e648154730b1850bf820`
- The repaired APK physically launched Android DocumentsUI. Searching for
  `INDIAs_GOT_LATENT` returned the requested 828 MB file, which was selected
  successfully and rendered in the Cast handoff sheet.

### Pixel 9 touch sender

- Device: physical Pixel 9 (`tokay`), Android 17 / API 37, arm64-v8a
- Installed build: repaired arm64 candidate described above (version code
  2006, signing-certificate short hash `31730cfb`)
- Requested source file copied to sender Downloads:
  `INDIAs_GOT_LATENT_S0E01_Bonus_EP1_Ft._Raghav_Juyal__Munawar_Niharika_NM__Rohan_Joshi_1080p.mkv.mp4`
- File size: 827,662,384 bytes (789 MiB)
- Source SHA-256:
  `f126927c9531d7bb349c42ac88092c4a526a785647019c3a14d7e1f5affb013d`
- Launch evidence confirms the compact touch layout and an available
  navigation-menu affordance.
- `Play file on TV` is physically visible in the compact drawer and captured
  in `pixel9/resumed/menu.png` plus its UI hierarchy.
- The repaired candidate launched DocumentsUI with
  `android.intent.action.OPEN_DOCUMENT`, `CATEGORY_OPENABLE`, and `video/*`.
  Search located the exact requested file, and selection reached the handoff
  sheet. Evidence is captured in `pixel9/resumed/documentsui.*`,
  `search-results.*`, and `handoff.*`.
- **Pending:** verify playback, seek, and stop while the BRAVIA remains online.

### Google Cast receiver

- Receiver became available on 2026-08-02 and was resolved over mDNS:
  `BRAVIA-BF1-93f73fe8aed376692e5855d7a9ce04da`, model `BRAVIA BF1`, friendly
  name `BRAVIA 2 II`, Cast endpoint port `8009`.
- The receiver reappeared at 11:45 on 2026-08-02 and was selected from the
  handoff sheet. It disappeared from Cast discovery during session startup:
  Android logged `Published 0 routes`, route-unselected reason 3, and session
  teardown before any media-server request. The app correctly displayed its
  retry state. Evidence is captured in `pixel9/resumed/receiver-online.png`,
  `connected.*`, and `cast-connect.log`.
- **Pending:** execute playback, seek, and stop while this receiver remains
  powered on and advertised.
- No receiver storage operation has been performed.

Release-owner disposition on 2026-08-02: park the BRAVIA-only playback,
seek, stop, and receiver non-storage checks. These checks are not represented
as passing and must be completed in a later receiver qualification.

### Fire TV ten-foot target

- Physical Fire TV Stick model `AFTSSS`, Android 9 / API 28,
  `armeabi-v7a`, at `192.168.1.9:5555`.
- Installed the fresh 32-bit candidate and launched its ten-foot shell.
- Installed package is Airo TV only (`io.airo.app.tv`, version code 1006,
  signing-certificate short hash `31730cfb`); Airo Super App was not installed
  or exercised on Fire TV.
- `firetv/ten-foot.png` and `firetv/ten-foot.xml` capture the sidebar and
  setup actions. `Play file on TV` is absent from the complete UI hierarchy.

## Failures and disposition

- VirusTotal release scan run `30695660898`: **failed** before scanning because
  `APK_NAME` was hard-coded to `Airo-TV-0.0.5.apk`; a deterministic resolver
  and guard tests are implemented in this qualification branch.
- Published touch build: **failed** to open DocumentsUI because Android package
  visibility hid `ACTION_OPEN_DOCUMENT` from `resolveActivity()`. The narrowly
  scoped TV-manifest query and release-check guard are implemented and
  physically verified on the repaired candidate.
- BRAVIA Cast attempt at 11:45 on 2026-08-02: **environmental receiver loss**;
  the route disappeared during session establishment before the phone media
  server or decode pipeline started. Playback verification remains pending a
  stable receiver advertisement.
- One post-build TV checker invocation initially failed because it was run
  after the build script had restored the full/mobile pubspec and registrant.
  The checker passed both inside the canonical build and when rerun under the
  TV pubspec. This was an invalid invocation, not a media failure.
- No verified media-pipeline failure has been observed; the media pipeline was
  not changed.

## Acceptance status

- [x] Touch-device menu exposes `Play file on TV` (physical capture complete)
- [ ] Local file streams to a compatible Cast receiver — **parked**
- [ ] Seek and stop work — **parked**
- [x] Ten-foot TV UI hides the sender action (physical capture complete)
- [x] Release artifact includes `ea217b98`
- [x] SonarQube/SonarCloud passes for the qualified source commits
- [x] Repository release qualification checks completed successfully, apart
  from explicitly device-dependent readiness gates above
