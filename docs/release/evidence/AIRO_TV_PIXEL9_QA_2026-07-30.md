# Airo TV and Super App Pixel 9 QA Evidence

Date: 2026-07-30
Base: fetched `origin/main` at `3c4bd8b2`
Branch: `codex/release-qa-pixel9-tv-20260730`
Device: physical Pixel 9 (`tokay`), Android 17 / API 37
Playlist fixture: `https://iptv-org.github.io/iptv/index.m3u`

## Critical Agent Gate

**Problem:** The next release candidate needed physical-device proof that the
Airo TV journey is smooth and crash-free on Pixel 9, that shared IPTV behavior
also works inside the Airo Super App, and that release tooling leaves the
source tree reproducible.

**User / actor:** Airo TV and Airo Super App viewers, QA automation, and release
engineering.

**Framework or application layer:** Mixed. The IPTV journey is application
behavior; Android resources and build-profile restoration are shared platform
and release concerns.

**Owning agents:** Airo TV Flutter Architect and Chief Release/DevOps Officer.

**Reviewing agents:** Chief QA Officer, Chief Architect, Chief Performance
Officer, Media Intelligence Architect, and Coins / Finance Agent for the
manifest-only ownership correction.

**Impacted modules/files:** Android shared resources, TV build scripts,
performance/soak tooling, release checks, `feature_coin/module.yaml`, and
release evidence.

**Base branch/worktree:** Confirmed. The worktree was created from the freshly
fetched `origin/main` commit `3c4bd8b2`.

**Open questions:** Fire TV D-pad, Cast receiver switching, iPad, signing/store
credentials, compliance forms, and the required 30-minute constrained-TV soak
still need their owning release lanes.

**Decision:** Ready for Pixel 9 regression qualification. Not ready for public
release while the official required gates remain unknown.

## Deterministic Use Cases

### UC-001: Clean Airo TV first launch

**Given:** No Airo TV app data exists on the Pixel 9.
**When:** The release-profile APK is installed and launched.
**Then:** A BYOC playlist setup state renders, no bundled channels appear, the
process remains active, and startup emits no fatal, ANR, native-library, or
media-control exception.

### UC-002: Import, find, and play an authorized channel

**Given:** The IPTV.org public test playlist is selected through the in-app
quick choice.
**When:** The user adds the source, searches for `CNN`, and selects CNN
Headlines.
**Then:** Channels load, search results appear, video and audio start, fullscreen
works, Home enters PiP, and PiP settles to video-only playback.

### UC-003: Shared Super App IPTV path

**Given:** The full Airo release APK is installed without clearing existing app
data.
**When:** The user opens the Super App and selects the Live destination.
**Then:** The shared Airo TV browser and existing channel playback render inside
the Super App without a media-control exception.

### UC-004: Reproducible TV profile build

**Given:** The TV build swaps `pubspec_tv.yaml` into the app directory.
**When:** dependency resolution changes `pubspec.lock` during the build.
**Then:** both the original pubspec and original lockfile are restored exactly,
temporary backups are removed, and the TV release contract passes.

### UC-005: Responsive browser fallback

**Given:** The TV web profile is built with a local authorized fixture.
**When:** The UI renders at 1920x1080, 1280x720, 1024x576, and 390x844.
**Then:** The debug fixture is seeded without replacing user state, the shell
is visible, screenshots are captured, and no Flutter overflow is emitted.

### UC-006: Sustained Pixel playback and PiP lifecycle

**Given:** A live channel is playing in the TV release on the Pixel 9.
**When:** RSS is sampled every 30 seconds for at least 30 minutes and the TV
activity transitions from foreground playback to PiP beside the Super App.
**Then:** All samples complete, the TV process and media session remain alive,
PiP continues rendering, memory plateaus or falls, and logs contain no app
fatal, ANR, native-library, playback, media-control, or out-of-memory error.

## Pixel 9 Results

### Airo TV artifact

- Package: `io.airo.app.tv`
- Version: `0.0.5` (`versionCode 5`)
- Profile: lightweight TV release, local validation signing
- Size: 29 MiB
- SHA-256:
  `e2a3a41a71824f20408442e56597c0ccaf3b636c5c9a9cacb0d32adf1daf5bf7`
- TV native media contract: passed
- Retained media resources: `audio_service_play_arrow`,
  `audio_service_pause`, and `audio_service_stop` present in the final APK

Passed journeys:

- clean first launch and BYOC empty state;
- playlist quick choice, import, channel parsing, and persistence after
  relaunch;
- country selector and playlist-source management;
- `CNN` search and live CNN Headlines playback;
- inline playback, resolution display, fullscreen, Android Back/Home lifecycle,
  and automatic PiP;
- settled PiP shows video without the app browse chrome;
- no app fatal exception, ANR, `UnsatisfiedLinkError`,
  `ExoPlaybackException`, or `CustomAction` exception after the fix.

### Pixel 9 playback soak

- Duration: 1,868 seconds (31 minutes, 8 seconds)
- Samples: 61 at 30-second target intervals
- Lifecycle: foreground live playback followed by sustained PiP while the
  Super App remained usable in the foreground
- Peak TV RSS: 408 MB
- Final TV RSS: 276 MB
- Result: accepted against the expanded 3 GB+ Pixel support profile
- Final TV media session: `PLAYING`
- Crash/ANR/native/playback/media-control/OOM log scan: clean
- Dart heap and image-cache snapshots were not available in the locally signed
  release build and remain recorded as unknown (`0`) in the runner artifact;
  this result proves process/RSS/lifecycle stability, not Dart-heap drift
- JSON SHA-256:
  `155dfdceda32509ac26d17f46cc76bc1d8d5b357dfec5a5fa30af9b8cef0f367`
- Markdown SHA-256:
  `8109ad36abd2ca746cb6a4806210fd36455be317350c5c7e537ff33f77f6963e`

### Airo Super App artifact

- Package: `io.airo.app`
- Version: `0.0.5` (`versionCode 5`)
- Profile: full Android release, local debug signing override
- Size: 101 MiB
- SHA-256:
  `cd813c74f7b6f6f1d0e2bcf08c0ef2b0e0e4690acd88288f4998a04352741ca2`
- Installed in place with `-r -d`; existing Super App data was preserved
- Clean launch passed
- Live destination rendered the shared Airo TV browser and resumed existing
  live playback
- The final APK retains the same play, pause, and stop media resources
- No app fatal exception, ANR, native-library error, or `CustomAction`
  exception was observed

## Defects Fixed

1. Android resource shrinking removed `audio_service` media-control icons.
   Android threw `IllegalArgumentException: You must specify an icon resource
   id to build a CustomAction` at TV startup and again when playback began.
   A shared Android keep rule now protects the complete media-control icon set
   for both Airo TV and the Super App. The TV release check and negative fixture
   enforce the contract.

2. The lightweight TV build restored `pubspec.yaml` but left
   `app/pubspec.lock` changed after dependency resolution. Shell and PowerShell
   build paths now back up and restore the lockfile. A deterministic fake-build
   regression test verifies exact restoration and backup cleanup.

3. `feature_coin` depended on `core_product_shell` without declaring it in
   `module.yaml`, causing the release module-manifest gate to fail. The manifest
   now matches the real shared dependency.

4. The web-safe TV bootstrap discarded `DEBUG_IPTV_PLAYLIST_URL`, so all four
   release viewport checks timed out despite rendering correctly. The stub now
   seeds only an empty playlist preference, preserves existing user state, and
   has focused regression coverage.

5. The playback-soak and memory-timeline tools could not select one device when
   ADB exposed multiple connections. Both tools now use one shared ADB-target
   argument helper and accept an explicit `--device` / `AIRO_TV_DEVICE`.

6. The documented host-side soak command imported Flutter UI libraries through
   the broad device-profile barrel and failed because `dart:ui` is unavailable
   to `dart run`. A host-safe device-profile entrypoint now exposes the same
   shared memory models without UI dependencies.

7. Android 17 reports `TOTAL RSS` beside `TOTAL PSS` without the older `K`
   suffix. The shared parser now supports both formats and has regression
   coverage from the Pixel 9 output shape.

8. The legal preflight found ten Airo-owned packages without package-level
   license files. Each now carries the repository's existing DevelopersCoffee
   MIT license. The preflight confirms every scanned Airo package has a
   matching license; only maintainer provenance/private-dependency decisions
   remain.

## Local Qualification

Passed:

- build-profile tests and profile contract check;
- bundled-model artifact guard;
- module manifest tests and all 62 real manifests;
- module-size gate;
- worker-offload policy tests and guard;
- release manifest and qualification-report tests;
- `core_release` package: 89 tests;
- TV media-session focused tests: 8 tests;
- Android TV native media contract fixtures;
- TV profile restoration regression test;
- web bootstrap regression tests: 2 tests;
- browser viewport matrix: 4 viewports with no Flutter overflow;
- platform benchmark targeting, Android 17 parsing, progress, and evidence
  tests: 10 tests;
- complete `platform_benchmarks` suite: 37 tests passed, 2 opt-in native/EPG
  benchmarks skipped as designed;
- host-side targeted soak smoke: 2 samples, accepted;
- Pixel 9 live playback/PiP soak: 61 samples over 31 minutes, accepted for the
  expanded Pixel support profile;
- v2 merge-readiness tests and same-commit dry run;
- `git diff --check`.

## Release-owner Preflight Findings

- Data Safety: locally ready for Google Play console entry; maintainer console
  submission remains required.
- Content rating: questionnaire is locally ready; Google Play/IARC must assign
  the final rating.
- Firebase App Distribution: ready because distribution mode is intentionally
  `none` for this local release configuration.
- Android production signing: blocked on four absent secret inputs.
- Firebase mobile client: blocked because `io.airo.app` is absent from
  `google-services.json` and Android Firebase options remain placeholders.
- Google Play upload: blocked on the service-account credential.
- Legal package coverage: all scanned package licenses now present and
  matching; blocked only on the private-dependency confirmation and provenance
  policy decision.
- Repository health: all required files, templates, labels, and CODEOWNERS are
  present; maintainer decisions for Discussions, ownership policy, and funding
  remain unrecorded.

## Remaining Public-Release Blockers

The official v2 readiness preflight remains `publicReady: false`. Required
unknown or externally incomplete gates include Firebase clients, production
signing, Play credentials and track decisions, Data Safety/IARC console
submission, legal provenance decisions, repository governance decisions,
Kotlin Gradle Plugin scope, release qualification approval, physical Fire
TV/Android TV D-pad evidence, Cast receiver evidence, iPad evidence, and the
30-minute constrained-TV memory/playback soak.

No Fire TV Stick was connected during this run, so Pixel 9 evidence must not be
used as a substitute for ten-foot D-pad qualification.

## 2026-08-01 Fire TV Addendum

This addendum supersedes the statement above that no Fire TV was connected.
It qualifies commit `29124bbd` on a physical Fire TV Stick AFTSSS (Fire OS,
API 28) through ADB remote-key injection. A handheld remote was not used, so
the input method is part of the evidence boundary.

### Exact TV candidate

- Artifact: `airo-tv-29124bbd-armeabi-v7a-release.apk`
- Package/version: `io.airo.app.tv`, `0.0.6-rc.1` (`versionCode 1006`)
- Profile: lightweight TV release with local validation signing; it is not a
  distributable production-signed artifact
- Size: 27,339,658 bytes
- SHA-256:
  `accb5b554aff5d60a6955980c1e41e7b37df186c4003e2aea77551e8d75557ba`

Passed physical journeys:

- imported the IPTV.org public playlist and rendered the channel library;
- dismissed the playlist modal with Back without leaving Airo;
- recovered from dead streams through Try Again / Skip channel / Report dead
  link and reached playable `1+1 Ukraina (1080p)`;
- played live video continuously for 30 minutes;
- retained `FLAG_KEEP_SCREEN_ON` for every soak sample, with Airo recorded as
  both the wake-lock-holding and hold-screen window;
- returned from fullscreen playback to the grid with one Back and remained in
  Airo for the following 25 seconds;
- persisted playlist/current-channel state across an unexpected physical
  device reboot.

The reboot reset uptime and changed the process ID, so it invalidated the
planned Home/resume process-retention observation. It must not be reported as
an Airo crash or as proof of same-process resume. Persistence across the
stronger reboot lifecycle passed.

### Exact-candidate constrained-TV soak

- Duration/samples: 30 minutes, 61 samples at 30-second intervals
- Foreground: true for all samples
- PID: stable (`9442`) for all samples
- Keep-screen-on: true for all samples
- Start/final PSS: 193,403 KB / 185,340 KB
- PSS delta: -8,063 KB; minimum 174,016 KB; maximum 197,658 KB
- Crash/ANR/OOM/`UnsatisfiedLinkError` scan: clean
- CSV SHA-256:
  `77bd3aad69859ee8b3c2a52df5cdfcd16bfeee4430a003d5b8e5f1ccad6acfe1`
- Logcat SHA-256:
  `81ddf6f208034d1269c21bba826d5cb5c680c8179d8dbf092dd58c7566b3fa91`

Dart heap and image-cache drift remain unknown because those counters are not
available from the release build. This result proves process/PSS, playback,
foreground, and display-awake stability only.

### Fire TV defects fixed in this branch

1. Back could escape the playlist dialog on Fire OS; the dialog now owns and
   consumes that Back transition.
2. Closing the on-screen keyboard could also close the playlist form; the form
   now remains open.
3. Fire OS could dispatch a delayed duplicate Back after leaving fullscreen
   playback; the callback is contained so the browse screen remains open.
4. The TV flavor's former no-op `wakelock_plus` override allowed the Fire OS
   dream/screensaver to interrupt playback. The lightweight override is now a
   functional, KGP-free Android plugin that applies `FLAG_KEEP_SCREEN_ON`.
5. The bounded Fire TV error-log classifier treated two stable Fire OS startup
   messages (unavailable JDWP agent and unsupported ION ioctl) as app defects.
   They are now counted as known runtime noise while every other error remains
   actionable.

### Incomplete Fire TV input gate

The eight-card D-pad plus Help open/dismiss report is not accepted. During the
capture, another local qualification process replaced the installed candidate
at 23:46:07 with a differently signed APK (pulled APK SHA-256
`7381b67d46954a2630c7ce26eb5fba5d3e5c62471a2845db35d59d83d946b422`),
clearing the playlist and invalidating the run. The exact candidate was
restored afterward, but no report is generated from the contaminated capture.
Issue #589 therefore remains open for the final eight-card and Help traversal.

### Super App boundary

The exact rebased PR head `d7f24813` full-app candidate was built and installed
in place on the physical Pixel 9 without clearing existing data:

- Artifact: `airo-super-app-d7f24813-arm64-v8a-release.apk`
- Package/version: `io.airo.app`, `0.0.6-rc.1` (`versionCode 2008`)
- Size: 106,264,984 bytes
- SHA-256:
  `fbd4395c3f002cdfb902f54a1b6cfc4299ca7862c68ece963dc705eda2cabaea`

The shared Live destination rendered the persisted playlist, current channel,
filters, and channel grid. Live video also rendered during the app's PiP
transition. The process remained alive, and the bounded signature scan found
no fatal exception, ANR, OOM, `UnsatisfiedLinkError`, playback exception, or
media-control `CustomAction` failure. This replaces the earlier
immediately-preceding-candidate evidence with exact-artifact proof.

### Rebased TV artifact awaiting deployment

The same rebased PR head produced a fresh Fire TV APK locally:

- Artifact: `airo-tv-d7f24813-armeabi-v7a-release.apk`
- Size: 27,372,706 bytes
- SHA-256:
  `c9a6f6084b7ece7f72720ccf6aa866fbcda69b68d9b3b84a654adde701efb5d2`
- TV release contract: passed with compile/target SDK 36 and required minimum
  SDK 34

The AFTSSS left the LAN immediately after this build (`Host is down`, no ARP
entry), so this rebased artifact has not yet replaced the physically qualified
pre-rebase candidate. Deployment and the final D-pad/Help traversal remain
open rather than being inferred from the earlier artifact.

### Release decision

The physical Fire TV playback, sleep prevention, Back containment, recovery,
and constrained-TV soak gates pass for the exact candidate. Public readiness
remains `false`: production signing, Firebase/mobile configuration, Play
credentials and console submissions, legal provenance/private-dependency
decisions, final D-pad/Help evidence, Cast receiver evidence, iPad evidence,
and release-owner approval remain external or incomplete.
