# Midas Stream v0.0.5 Pixel 9 QA Evidence

Date: 2026-07-26
Device: Pixel 9 (`tokay`), Android 17, physical device over wireless ADB
Playlist fixture: `https://iptv-org.github.io/iptv/index.m3u`

## Published artifact baseline

- Release: `airo-tv-v0.0.5`
- Artifact: `Airo-TV-0.0.5-arm64-v8a.apk`
- SHA-256:
  `bd25ac38b54e8f14c421dbc4c446b3cfd57447c08cb0860bf957b6fce14f7dec`
- Package/version: `io.airo.app.tv`, `0.0.5`, version code `2005`
- Result: `DONE_WITH_CONCERNS`, health score `86/100`
- Findings:
  - [#1142](https://github.com/DevelopersCoffee/airo/issues/1142):
    Settings header Back did nothing and Android Back exited Midas Stream.
  - [#1143](https://github.com/DevelopersCoffee/airo/issues/1143):
    cold start registered media-kit while `libmpv.so` and
    `libmediakitandroidhelper.so` were absent.

Baseline coverage that passed included playlist import/persistence, country
filtering, CNN search/playback, Aaj Tak HD playback, favorite persistence,
fullscreen, automatic picture-in-picture, and absence of app fatal/ANR errors.

## Fixed candidate

- Source branch: `fix/qa-v005-regressions`
- Source commits:
  - `953a40b8` — landscape Settings Back regression coverage
  - `2d70d18c` — video-player-only TV plugin/native-library contract
  - `9906c01f` — dedicated compact Theme settings section
- Final candidate SHA-256:
  `0bee05e7ce963ae44f784f47b805dabfb70aef7fcd590ba32616548a84480277`
- Package/version: `io.airo.app.tv`, `0.0.5`, local validation version code `5`
- Size: 31 MiB (32.0 MB build output)
- Signing: ephemeral local validation certificate; not a publishable artifact

### Automated evidence

- Settings hub and TV router widget suites: 21 tests passed.
- Focused Settings analyzer: no issues.
- All build-profile pubspecs resolved with the TV-only native-bundle stub.
- Native media contract fixtures:
  - video-player-only registrant/APK: accepted;
  - media-kit registrant: rejected;
  - excluded media-kit library in APK: rejected.
- Real arm64 release build passed `scripts/check-android-tv-release.sh`.
- APK contains video-player classes and contains no media-kit plugin,
  `libmpv.so`, or `libmediakitandroidhelper.so`.

### Pixel 9 physical regression

Passed:

- cold start with no `UnsatisfiedLinkError`, missing-media-library signature,
  app fatal exception, or ANR;
- Settings header Back in portrait and landscape;
- Settings Android Back in portrait and landscape;
- Settings Android Back after live playback was selected;
- Media3/video-player live playback (`CNA (1080p)`);
- playlist, selected channel, and favorite persistence after relaunch;
- Favorites page and Back navigation;
- fullscreen playback;
- automatic picture-in-picture (`mode=pinned`);
- dedicated Theme screen shows every existing theme;
- Theme selection plus header/system Back to Settings.

### Fire TV note

The connected Fire TV Stick (`AFTSSS`, Fire OS 7 / Android 9 base) is a
32-bit `armeabi-v7a` target. The arm64 Pixel candidate was intentionally
incompatible and failed with the expected missing arm32 `libflutter.so`.
The exact prior version-code-7 Fire TV APK was restored after this check.
This is not evidence against the arm64 fix; Fire TV qualification requires the
release workflow's separate `armeabi-v7a` artifact.

## Evidence retention decision

The raw `.gstack` directories are intentionally not committed:

- the baseline directory is approximately 257 MiB;
- it contains duplicate APKs (including a 213 MiB installed-package pull),
  full device logs, UI hierarchy dumps, and screenshots;
- those files are noisy, may expose device-specific metadata, and are not
  suitable for permanent source history.

This sanitized record is the committed archive. Raw evidence remains local in
the QA worktree for short-term debugging and may be deleted after the issues
and branch are merged. Publishable release evidence must be regenerated from
the final signed artifact and attached through the release qualification
workflow rather than committed under `.gstack`.
