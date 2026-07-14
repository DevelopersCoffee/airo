# Store Compliance Guide

Store-submission checklist for Airo release profiles. Use this as the
pre-submission working document; account setup, credentials, and final store
metadata decisions remain tracked in the linked GitHub issues.

## Live Legal URLs

These URLs were verified with HTTP 200 responses on July 14, 2026.

| Page | URL | Status |
| --- | --- | --- |
| Privacy Policy | `https://developerscoffee.github.io/airo/legal/privacy-policy/` | Live |
| Terms & Conditions | `https://developerscoffee.github.io/airo/legal/terms-conditions/` | Live |

The Terms page opens with the IPTV content disclaimer: Airo TV is a media
player only and does not provide channels, playlists, or streams.

## Android Release Profiles

The current v2 profile matrix is maintained in
[V2 Distribution Matrix](./V2_DISTRIBUTION_MATRIX.md).

| Profile | Package ID | Device class | Entrypoint | Store status |
| --- | --- | --- | --- | --- |
| `tv` | `io.airo.app.tv` | Android TV, Google TV, Fire TV-compatible APK testing | `app/lib/main_tv.dart` | TV release workflow builds APK and Play AAB; real Play upload needs #585/#681 setup |
| `iptv-standalone` | `io.airo.app.iptv` | Android phone and tablet IPTV-only builds | `app/lib/main_airo_iptv.dart` | Mobile/tablet release workflow builds APK and Play AAB; real publish setup needs #585/#681/#682 |
| `mobile-streaming` | `io.airo.app.streaming` | Android phone and tablet streaming builds | `app/lib/main_mobile_streaming.dart` | Mobile/tablet release workflow builds APK and Play AAB; real publish setup needs #585/#681/#682 |
| `ios-spm` | `com.developerscoffee.airo` | iOS/iPadOS validation profile | `app/lib/main.dart` | Deferred from the first v2 Android publishing wave |

The Android Gradle config currently uses:

- `compileSdk = 36`
- `targetSdk = 36`
- `minSdk = 26`
- R8 minification and resource shrinking enabled for release builds
- release signing from `app/android/key.properties` locally or CI signing
  secrets in release workflows

## Airo TV Metadata

| Field | Current value | Status |
| --- | --- | --- |
| App name | `Airo TV` | Ready |
| Package ID | `io.airo.app.tv` | Ready pending Play Console confirmation |
| Category | Entertainment / Video Players & Editors | Pending final store entry in #581 |
| Short description | Draft in #581 | Pending stakeholder approval |
| Full description | Draft in #581 | Pending stakeholder approval |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` | Ready |
| Terms URL | `https://developerscoffee.github.io/airo/legal/terms-conditions/` | Ready |
| Content disclaimer | User-provided IPTV content only; no bundled streams or playlists | Ready |
| App icon | Android launcher icon present | Needs Play 512x512 asset confirmation in #581 |
| TV banner | `app/android/app/src/tv/res/drawable-xhdpi/tv_banner.png` | Present |
| Screenshots | TV screenshots required, 1920x1080 landscape | Pending #581 |
| Feature graphic | 1024x500 PNG/JPG required for Play | Pending #581 |

### Airo TV Permissions

The TV manifest is `app/android/app/src/tv/AndroidManifest.xml`.

| Permission / feature | Reason | Status |
| --- | --- | --- |
| `android.software.leanback` | Android TV launcher eligibility | Required |
| `android.hardware.touchscreen` (`required=false`) | Allow TV/non-touch devices | Required |
| `INTERNET` | Stream playback, playlist fetches, EPG fetches, Cast/network media behavior | Required |
| `ACCESS_NETWORK_STATE` | Network-aware playback and error handling | Required |
| `CHANGE_WIFI_MULTICAST_STATE` | Local Cast/device discovery support | Required |
| `RECEIVE_BOOT_COMPLETED` | WorkManager/plugin compatibility for scheduled/background work | Review before public TV submission |
| `FOREGROUND_SERVICE` | Foreground playback/service support | Required |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android media playback foreground service declaration | Required |
| `WAKE_LOCK` | Keep playback/session work stable during media use | Required |

The TV manifest explicitly removes biometric/fingerprint, Google Services read,
and AI Core bind-service permissions inherited from broader dependencies.

## Google Play Checklist

| Item | Status | Owner / link |
| --- | --- | --- |
| Play Console app/package created for TV | Pending | #681, #585 |
| Play Console app/package created for mobile/tablet | Registered package IDs confirmed; Play listing strategy still pending | #675, #677, #681 |
| First Play tracks selected | Pending | #681 |
| Play service account JSON stored as GitHub secret | Pending | #585, #681 |
| Production Android signing secrets stored in GitHub | Pending | #585, #677 |
| AAB build for TV | Ready in CI | `.github/workflows/airo-tv-release.yml` |
| AAB build for mobile/tablet | Ready in CI for selected v2 profile | `.github/workflows/airo-mobile-tablet-release.yml` |
| GitHub Release asset publication | Ready in orchestrator for selected v2 profiles | `.github/workflows/v2-release-orchestrator.yml` |
| IARC content rating completed | Pending store-console action | #584 |
| Data Safety form completed | Pending store-console action | #584/#581 |
| Store metadata finalized | Pending | #581 |
| TV screenshots and feature graphic uploaded | Pending | #581 |
| Release qualification evidence attached | Pending actual release evidence | #683 |

## App Store / iOS Checklist

iOS/iPadOS publication is deferred from the first v2 Android publishing wave.
Keep this section as a readiness tracker only until maintainers explicitly add
iOS to the release scope.

| Item | Status | Owner / link |
| --- | --- | --- |
| Apple Developer Program membership | Human setup required | #585 |
| App Store Connect API key and signing setup | Human setup required | #585 |
| iOS deployment target | Pending final iOS release scope | #585/#675 |
| App privacy nutrition labels | Pending App Store Connect action | #584/#585 |
| TestFlight upload automation | Deferred | #585 |

## IPTV Content Disclaimer

Airo TV is a media player for user-provided playlists and streams. It does not
provide, host, endorse, verify, or distribute channels, playlists, or streams.
Users are responsible for ensuring that every content source they load is legal
in their jurisdiction and that they have the required rights to access it.

Use this disclaimer in the Play full description, release notes, support docs,
and any direct APK download page.

## Pre-Submission Sign-Off

Before submitting a public v2 Android release:

- [ ] Review [V2 Distribution Matrix](./V2_DISTRIBUTION_MATRIX.md) and confirm
      the selected public profiles.
- [ ] Confirm mobile/tablet listing strategy for the registered
      `io.airo.app.*` package IDs in #675/#677.
- [ ] Complete account, credential, signing, and repository-governance items in
      [V2 Publishing Human Setup](./V2_PUBLISHING_HUMAN_SETUP.md).
- [ ] Finalize Airo TV store metadata in #581.
- [ ] Complete content rating and data-safety store-console forms in #584.
- [ ] Attach release qualification evidence or an explicit waiver per
      [V2 Release Qualification](./V2_RELEASE_QUALIFICATION.md).
- [x] Confirm every public APK/AAB has `SHA256SUMS` and a release manifest.
- [ ] Confirm no public release asset uses debug-looking names such as
      `app-release.apk`.

## Related Issues

- #575, #577, #578, #579: legal/docs foundation.
- #581: final Play/App Store listing metadata and screenshots.
- #584: IARC/content rating and App Store age-rating questionnaires.
- #585: Fastlane/store credentials and signing setup.
- #675: supported v2 device/profile artifact matrix.
- #677: mobile/tablet APK and AAB build workflow.
- #681: Google Play upload automation.
- #682: Firebase App Distribution upload automation.
- #683: release qualification matrix and evidence.
- #687: license and third-party license review.
- #689: repository health gates for public release readiness.
