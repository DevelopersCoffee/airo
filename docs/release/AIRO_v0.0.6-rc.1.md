# Airo v0.0.6-rc.1 — Preview Release

Preview (release-candidate) cut for **direct download / APKPure**, not a store
submission. Google Play, App Store, Firebase App Distribution, iOS/iPadOS, and
macOS notarization are out of scope for this cut.

## Release wave (published artifacts)

| Profile | Package / bundle | Artifact | Version line |
| --- | --- | --- | --- |
| Android TV (`tv`) | `io.airo.app.tv` | `Airo-TV-0.0.6-rc.1.*` APK + AAB | `0.0.6-rc.1+6` |
| Full app (`full`) | `io.airo.app` | `Airo-0.0.6-rc.1-8-arm64.apk` + AAB | `0.0.6-rc.1+8` |
| macOS TV | `com.developerscoffee.airo.tv` | direct-download `.zip` / `.dmg` | `0.0.6-rc.1` |

Per-line RC tags follow the established scheme: `airo-tv-v0.0.6-rc.1` and
`v0.0.6-rc.1` (full). Each product keeps its own cadence, matching the tag
history (`airo-tv-v*` and `v*`).

## Not in this release (qualification / deferred / internal)

| Artifact / profile | Source | Status |
| --- | --- | --- |
| Airo Coins (`coins`) | `pubspec_coins.yaml` | **CI qualification only** — package size + architecture gate at 25 MiB. Not published. |
| iOS / iPadOS SPM | `ios-spm` | Deferred — not in the Android/macOS preview wave; no Apple account. |
| Web validation | `web-validation` | Local/CI browser-engine validation only; no public web deploy. |
| Raw gradle APKs | `app-release.apk`, `app-arm64-v8a-release.apk` | Renamed to `Airo-*` / `Airo-TV-*` before publish; raw names never shipped. |
| Debug symbols / obfuscation maps | `.symbols`, `.map` | Retained privately as a restricted workflow artifact for symbolication. |
| Credentials & secrets | `*.jks`, `google-services.json`, service accounts | Never attached to public assets or the release manifest. |

## What is new since v0.0.5

- Apple picture-in-picture wiring and player-layer lifecycle in
  `platform_player`.
- EPG programme-enrichment metadata contract and programme-details dialog
  (`platform_epg`, `platform_iptv_org_api`).
- IPTV source-management extension seam and source-diagnostics entitlement
  (`feature_iptv`, `core_entitlements`).
- Bootstrap provider overrides; agent chat prefers an installed Gemma model.
- CI: deterministic cross-platform validation, safe partial APK-baseline
  merges, physical-device rig as the default run path, and Airo Coins promoted
  into the CI size/architecture qualification matrix.

## Distribution and verification

- Android artifacts ship single-arm64 APKs plus Play-Store AABs (AAB kept as
  release evidence; no Play upload in this cut).
- macOS TV artifacts are direct-download validation builds; not notarized.
- Every published asset is covered by `SHA256SUMS` and mapped in
  `Airo-0.0.6-rc.1-Release-Manifest.json`.

## Known limitations and blockers

- **Signing:** without a stable dogfood keystore (`DOGFOOD_KEYSTORE_BASE64`),
  every RC is signed with an ephemeral CI cert and will not upgrade over a
  previous build (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). APKPure keys updates
  off the signature. Generate and register a dogfood keystore before publishing
  upgradeable previews.
- **Fire TV D-pad focus (#1272):** focus paths and modal focus ownership from
  #1244 remain unmet on physical Fire TV; empty IPTV state renders under the
  nav rail.
- Midas Stream ships no playlists, channels, or media; users provide their own
  authorized content.
