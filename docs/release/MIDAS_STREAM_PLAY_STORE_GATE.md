# Midas Stream — first Play Store gate

Release-engineer scan of `origin/main` (`c23c8a23`) before the identity
refactor, plus the decisions that make the first Play listing friction-free.

This document is the working gate for `com.developerscoffee.tv.midas`. It does
not rewrite historical Midas Stream evidence under `docs/release/evidence/`.

## Scan findings (main)

| Surface | On `main` | First-release decision |
| --- | --- | --- |
| Android TV `applicationId` | `io.airo.app.tv` | **New listing** `com.developerscoffee.tv.midas`. Package IDs cannot be renamed in Play Console. |
| Gradle `namespace` | `io.airo.app` | Keep. Play cares about `applicationId`; moving Kotlin sources is out of scope. |
| Launcher label | `Midas Stream` | `Midas Stream` |
| macOS bundle ID | `com.developerscoffee.airo.tv` | Unchanged this wave. Not a Play Store artifact. |
| Store listing / legal URLs | Midas Stream copy | Relabeled to Midas Stream; same GitHub Pages paths. |
| iptv-org one-tap presets | Shipped in the playlist manager | **Removed.** One-tap public playlists are a Play intellectual-property rejection. |
| iptv-org catalogue fetch | `channels.json` / `feeds.json` / `streams.json` on browse | **Disabled.** `streams.json` is a public stream URL catalogue. |
| Empty-state disclaimer | Present, said "Airo" | Kept; product name is Midas Stream. |
| TV manifest `usesCleartextTraffic` | `false`, but network-security-config permits HTTP | Honest BYOC playback tradeoff; disclosed in privacy policy. |
| `RECEIVE_BOOT_COMPLETED` | Declared | Keep for WorkManager restore; justify in Play declarations. |
| `FOREGROUND_SERVICE_DATA_SYNC` | Missing on TV while WorkManager declares `dataSync` | **Added** so Android 14+ does not crash a foreground WorkManager job. |
| Firebase Android client | Registered for `io.airo.app.tv` | **Human:** register `com.developerscoffee.tv.midas` and refresh `GOOGLE_SERVICES_JSON`. |
| Digital Asset Links | `io.airo.app.tv` | **Human:** publish SHA-256 for the new package on `developerscoffee.github.io`. |

## Product identity

| Field | Value |
| --- | --- |
| App name | Midas Stream |
| Android package | `com.developerscoffee.tv.midas` |
| Entrypoint | `app/lib/main_tv.dart` |
| Pubspec | `app/pubspec_tv.yaml` |
| Category | Video Players & Editors |
| Content model | Media player for user-supplied M3U/M3U8 URLs only |
| Privacy Policy | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |

## Play policy posture

Midas Stream is a **bring-your-own-content player**. It does not provide,
host, sell, or recommend channels, playlists, or streams. The first listing
must not:

- ship or one-tap a public IPTV index (including iptv-org);
- claim "free live TV", "channels included", or a bundled catalogue;
- download a third-party stream URL database for enrichment;
- target children (privacy minimum age remains 16+).

Users paste an authorized playlist URL. Tests may still use iptv-org URLs as
**fixtures the test itself supplies**, which is not the same as shipping a
preset in production UI.

## Release plan

1. **v0.0.1 preview (this wave):** production-signed Pixel sideload / internal
   UAT. `versionName` is `0.0.1`, `versionCode` is **13**.
2. **v0.0.1 hard release (after UAT):** same `versionName` on Play. Keep
   `versionCode` at 13 if Pixel never received this build from Play; bump the
   code if a Play-signed install already shipped.

Pixel sideload uses the **upload** key. Play-installed APKs use Google's **app
signing** key. A Pixel preview install will **not** upgrade in place to the
Play listing — uninstall the sideload before installing from Play.

## Upgrade path (v0.0.1)

Android upgrades in place only when **package name**, **signing certificate**,
and **versionCode** all match. `versionName` (`0.0.1`) is cosmetic.

| Currently installed | Next Midas build | Upgrades in place? |
| --- | --- | --- |
| Sideloaded GitHub **Midas Stream** `io.airo.app.tv` | `com.developerscoffee.tv.midas` | **No.** Different `applicationId`. Uninstall Midas Stream first. |
| Same package, **ephemeral CI** cert | Production/dogfood-signed build | **No.** Different cert (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Uninstall first. |
| Same package, **same upload/production key**, lower `versionCode` | `0.0.1+13` | **Yes.** |
| Play-installed Midas (Play App Signing) | Later Play AAB, same upload key, higher `versionCode` | **Yes.** Play re-signs with the Google-held app signing key. |

`app/pubspec_tv.yaml` was `0.0.7+12` (`versionCode` 12). A Play listing of
`0.0.1+1` would be a **downgrade** over any already-installed Midas build with
code 12. Preview and first Play AAB must ship `versionCode >= 13`
(`0.0.1+13`).

That is why earlier CI/RC installs needed delete-and-reinstall: unsigned
ephemeral keystores change every run. Production signing from
`app/android/release.keystore` (GitHub `ANDROID_RELEASE_KEYSTORE_BASE64`) is
stable. Do not mix `~/airo-release.keystore`.

Public fingerprints: [midas-stream-play-app-signing.json](./midas-stream-play-app-signing.json).

## Human console actions (not code)

| Step | Status |
| --- | --- |
| Create Play Console app `com.developerscoffee.tv.midas` | Done (app id `4972670245912164415`) |
| Register Firebase Android client | Done (`1:906799550225:android:c5df8d843e7dd6002206b0`) |
| Confirm upload keystore + Play App Signing | Play App Signing enrolled; first AAB signed with `app/android/release.keystore` |
| GitHub production signing + `GOOGLE_SERVICES_JSON` | Set from local Gradle keystore and merged `google-services.json` |
| Complete IARC / Data Safety | Worksheets ready; Console submit still required |
| 512×512 icon + TV screenshots | Exported under `docs/store-assets/airo-tv/` |
| Pixel-line install and smoke | v0.0.1 preview UAT (this PR); Play hard release after UAT |

## Out of scope this wave

- Renaming the Airo super-app, Coins, or Mind packages.
- macOS bundle ID / Homebrew cask rename.
- Rewriting historical qualification evidence.
- Changing GitHub artifact filenames (`Airo-TV-*.apk`); Play uploads the AAB
  `applicationId`, not the GitHub file name.
