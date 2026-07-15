# Core Release

Release profile and artifact matrix contracts for Airo.

This package owns the reusable, automation-facing release matrix for supported
profiles, device classes, artifact naming, distribution channels, and deferred
platform decisions. Release workflows and docs should consume this package
instead of duplicating profile rules in CI scripts.

## Scope

- V2 profile matrix for IPTV, Streaming, TV, macOS Airo TV distribution, iOS
  SPM validation, and web validation profiles.
- Stable APK, AAB, macOS zip/DMG, checksum, release-notes, and manifest
  filename helpers.
- Android phone, tablet, Android TV, Google TV, Fire TV, macOS, iOS/iPadOS,
  web, and legacy TV support status contracts.
- Tablet strategy contract that keeps the current release wave on adaptive
  mobile artifacts until maintainers approve a separate tablet flavor/listing.
- Distribution-channel behavior for GitHub Releases, Firebase App
  Distribution, Google Play, Amazon Appstore, F-Droid, direct APK, direct macOS
  download, Homebrew Cask, and local validation.
- Data Safety/App Privacy preflight for source-level TV privacy posture checks
  before maintainers enter store-console forms.
- Google Play upload planning for no-upload, internal, alpha, beta, and
  production modes before workflows write credentials or run upload tools.
- Content-rating preflight for Google Play/IARC and future App Store Connect
  questionnaire posture before maintainers enter store-console forms.
- Redacted Fastlane credential preflight for Play Store and App Store Connect
  setup checks before humans run upload lanes.
- Validation findings for duplicate profile/package IDs and incomplete Android
  release candidates.

This package does not perform signing, upload artifacts, read credentials, call
store APIs, generate checksums, or decide pending maintainer questions.
