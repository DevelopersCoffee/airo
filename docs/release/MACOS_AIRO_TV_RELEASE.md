# Airo TV macOS Release

This runbook covers the first macOS release path for the existing v2 `tv`
profile. The release remains scoped to the modular Airo TV IPTV player and uses
GitHub Release assets plus generated Homebrew Cask metadata. Mac App Store,
Setapp, MacPorts, and sandbox submission are out of scope.

| Field | Value |
| --- | --- |
| Profile | `tv` |
| Entrypoint | `app/lib/main_tv.dart` |
| Pubspec | `app/pubspec_tv.yaml` |
| Flutter defines | `APP_VARIANT=tv`, `APP_PLATFORM=androidTv`, `APP_VERSION=<build_name>` |
| App bundle | `Airo TV.app` |
| Bundle ID | `com.developerscoffee.airo.tv` |

`APP_PLATFORM=androidTv` is intentional for the macOS build because it is the
existing IPTV-only TV feature gate. Firebase initialization remains skipped on
macOS unless real macOS Firebase options are supplied.

## Cut And Build

Use the `Airo TV macOS Release` workflow for macOS-only validation or the `V2
Release Orchestrator` workflow when publishing the full Airo TV release set.

Recommended workflow inputs:

```text
profile=tv
version=airo-tv-v0.0.5
build_name=0.0.5
build_number=5
release_ref=main
release_branch=release/airo-tv-v0.0.5
require_notarization=false
```

The macOS workflow fetches `origin/main` and `origin/main`, verifies the selected
ref contains latest `origin/main`, creates or updates the release branch, builds
`Airo TV.app`, and packages release artifacts.

For local validation on macOS:

```bash
scripts/build-macos-tv.sh
```

## In-App Update Check

The macOS TV build exposes an `Update` action in the Airo TV header. It checks
the latest GitHub Release and opens the release page when a newer release
contains a macOS `.zip` or `.dmg` asset. Android TV/mobile releases are ignored
for this check, so users do not see an update prompt unless a desktop artifact
is actually available.

This is a manual direct-download flow for the GitHub Release channel. It does
not silently install updates and it does not replace Homebrew Cask updates.
Release builds must pass `APP_VERSION=<build_name>` through `--dart-define` so
the app compares against the installed version.

## Signing And Notarization

Unsigned local and CI artifacts are allowed for development validation. They are
not distributable public macOS builds.

Set these secrets before requiring public notarized artifacts:

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `MACOS_CODESIGN_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Generate redacted local readiness evidence before dispatching a public macOS
release workflow:

```bash
dart pub global run melos run release:macos-signing-preflight
```

When `require_notarization=true`, the workflow fails unless Developer ID
signing, notarytool submission, stapling, and `spctl` assessment succeed.

## Artifacts

The workflow uploads:

```text
Airo-TV-<build_name>-macOS.zip
Airo-TV-<build_name>-macOS.dmg
Airo-TV-<build_name>-macOS-Release-Manifest.json
SHA256SUMS
homebrew/airo-tv.rb
```

The generated Homebrew Cask points to:

```text
https://github.com/DevelopersCoffee/airo/releases/download/<release_tag>/Airo-TV-<build_name>-macOS.zip
```

## Validation Checklist

- `git merge-base --is-ancestor origin/main HEAD`
- `scripts/check-build-profiles.py`
- `scripts/test-generate-release-manifest.sh`
- `flutter test` in `packages/core_release`
- `flutter analyze lib/main_tv.dart` under `app/pubspec_tv.yaml`
- `flutter build macos --release --target=lib/main_tv.dart`
- App launches without Firebase macOS options.
- IPTV import/playback/navigation smoke paths work with pointer input.
- The macOS `Update` action reports no update when the latest GitHub Release
  has no newer macOS ZIP/DMG, and opens the release page when one exists.
- Player fullscreen opens the full-window TV player from cursor input and
  requests native macOS fullscreen when the Runner channel is available.
- Cast-only mobile behavior is hidden or no-op on macOS.
- Unsigned artifacts are labeled `unsigned` and `not_notarized`.
- Signed artifacts pass `codesign --verify`.
- Notarized artifacts pass `spctl --assess`.
