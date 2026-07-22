# V2 License Review

This document records the current license-readiness baseline for the v2 Android
publishing wave.

Implementation work for this release line must start from latest `origin/main`.

## Current Status

| Area | Status | Notes |
| --- | --- | --- |
| Root `LICENSE` | Ready | Root project license is MIT. |
| README license badge | Ready | README links to the root MIT license. |
| Internal package license files | Ready | Airo-owned package `LICENSE` files use the root MIT license text. |
| Vendored Cast library | Documented | `packages/platform_player/third_party/flutter_chrome_cast` declares BSD-3-Clause. Its notice is recorded in `docs/release/V2_THIRD_PARTY_NOTICES.md`. |
| Private/commercial dependencies | Unknown | Maintainers must confirm whether any private or commercial dependency is bundled in release builds. |

## V2 Release Profiles Reviewed

The current v2 Android publishing candidates are documented in
`docs/release/V2_DISTRIBUTION_MATRIX.md` and `.github/airo-build-profiles.json`:

- `full`
- `tv`

The `ios-spm` and `web-validation` profiles are not part of the first v2
Android publishing wave.

## Direct Dependency Surface

The following direct dependencies appear in at least one v2 Android release
profile pubspec:

```text
audio_service
audioplayers
cached_network_image
connectivity_plus
core_ai
core_auth
core_data
core_domain
core_ui
cupertino_icons
dio
drift
equatable
feature_iptv
file_picker
firebase_auth
firebase_core
flame
flutter
flutter_chrome_cast
flutter_contacts
flutter_image_compress
flutter_local_notifications
flutter_riverpod
flutter_tts
go_router
google_mlkit_text_recognition
google_sign_in
hive
hive_flutter
image_picker
intl
just_audio
package_info_plus
path
path_provider
pdfx
permission_handler
riverpod
rxdart
share_plus
shared_preferences
sqlite3_flutter_libs
stockfish
timezone
url_launcher
uuid
video_player
wakelock_plus
```

Several heavy packages are stubbed in edge profiles through
`dependency_overrides`; this reduces bundled release code for those profiles but
does not remove the need to confirm license compatibility for any package that
is actually included in a shipped artifact.

## Native And Vendored Components

Known native or vendored components that require explicit review before public
distribution:

- Flutter engine and Android Gradle build outputs.
- Firebase and Google Sign-In Android libraries when included.
- SQLite native libraries from `sqlite3_flutter_libs`.
- Media playback and audio service native components.
- ML/OCR/game/audio packages if a selected profile bundles them instead of a
  local stub.
- Vendored `flutter_chrome_cast` BSD-3-Clause source under
  `packages/platform_player/third_party/flutter_chrome_cast`.

## Required Before Public Distribution

- Keep the root MIT `LICENSE` and package license files aligned.
- Keep `docs/release/V2_THIRD_PARTY_NOTICES.md` with the release asset set.
- Generate redacted local legal/provenance evidence before public release:

  ```bash
  dart pub global run melos run release:legal-preflight
  ```

- Regenerate or re-check third-party notices when v2 release profile
  dependencies change.
- Confirm whether any private, commercial, gated, or restricted-license
  dependency is bundled in each release artifact.
- Confirm that Play Store, direct APK, and any other listing text matches the
  selected project license and third-party notice obligations.

## Human Decisions Still Needed

- Whether SHA256-only release provenance is sufficient for the first v2 wave or
  whether signed/SLSA provenance is required.
- Whether any private/commercial dependency is present in v2 release artifacts.
