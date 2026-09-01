# Midas Stream — first Play Store gate

Release-engineer scan of `origin/main` (`c23c8a23`) before the identity
refactor, plus the decisions that make the first Play listing friction-free.

This document is the working gate for `com.developerscoffee.tv.midas`. It does
not rewrite historical Airo TV evidence under `docs/release/evidence/`.

## Scan findings (main)

| Surface | On `main` | First-release decision |
| --- | --- | --- |
| Android TV `applicationId` | `io.airo.app.tv` | **New listing** `com.developerscoffee.tv.midas`. Package IDs cannot be renamed in Play Console. |
| Gradle `namespace` | `io.airo.app` | Keep. Play cares about `applicationId`; moving Kotlin sources is out of scope. |
| Launcher label | `Airo TV` | `Midas Stream` |
| macOS bundle ID | `com.developerscoffee.airo.tv` | Unchanged this wave. Not a Play Store artifact. |
| Store listing / legal URLs | Airo TV copy | Relabeled to Midas Stream; same GitHub Pages paths. |
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

## Human console actions (not code)

These still block upload even after this branch is green:

1. Create a **new** Play Console app for `com.developerscoffee.tv.midas`.
2. Register a Firebase Android app for that package and update secrets.
3. Confirm the production upload keystore and Play App Signing.
4. Complete IARC / Data Safety using the worksheets in this folder.
5. Export a 512×512 high-res icon and TV screenshots under the Midas Stream name.
6. Pixel-line install and smoke (user-owned next step).

## Out of scope this wave

- Renaming the Airo super-app, Coins, or Mind packages.
- macOS bundle ID / Homebrew cask rename.
- Rewriting historical qualification evidence.
- Changing GitHub artifact filenames (`Airo-TV-*.apk`); Play uploads the AAB
  `applicationId`, not the GitHub file name.
