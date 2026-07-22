# Fastlane Credential Setup

Fastlane configuration is present for Android and iOS, but real store uploads
remain human-gated until account owners configure store accounts, signing, and
repository secrets.

## Android / Google Play

The Android Appfile is `app/android/fastlane/Appfile`.

It reads:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SUPPLY_JSON_KEY` or `SUPPLY_JSON_KEY_FILE` | `play-store-credentials.json` | Path to the Google Play service account JSON file used by Fastlane Supply. |
| `SUPPLY_PACKAGE_NAME` | `io.airo.app.tv` | Package ID to upload. Override for mobile/tablet profiles. |

Release workflows already write the Play service account JSON from
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` to
`app/android/play-store-credentials.json` before invoking Play upload steps.

Use these package values for v2 Android profiles:

| Profile | `SUPPLY_PACKAGE_NAME` |
| --- | --- |
| `tv` | `io.airo.app.tv` |
| `full` | `io.airo.app` |

Human setup still required:

- Create or confirm Play Console apps for the selected public packages.
- Create a Play service account and grant release permissions for the selected
  apps.
- Store the service account JSON as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- Confirm the first track for each profile: `internal`, `alpha`, `beta`,
  `production`, or `none`.

Run the redacted local preflight before upload. It checks package/profile
alignment and whether credentials are present without printing secret values:

```bash
AIRO_RELEASE_PROFILE=tv melos run release:fastlane-preflight
```

Local smoke check after credentials are available:

```bash
cd app/android
SUPPLY_PACKAGE_NAME=io.airo.app.tv \
SUPPLY_JSON_KEY=play-store-credentials.json \
bundle exec fastlane supply init
```

## iOS / App Store Connect

iOS/iPadOS publication is deferred from the first v2 Android release wave.
The iOS Appfile is `app/ios/fastlane/Appfile` and reads account-specific values
from the environment:

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_IDENTIFIER` | `com.developerscoffee.airo` | App Store bundle identifier. |
| `APPLE_ID` | unset | Apple ID email for legacy Fastlane flows. |
| `TEAM_ID` | unset | Apple Developer Program team ID. |
| `ITC_TEAM_ID` | unset | App Store Connect team ID, when different. |

Human setup still required before TestFlight/App Store upload:

- Confirm Apple Developer Program membership.
- Create App Store Connect API credentials.
- Configure signing certificates and provisioning profiles.
- Store `MATCH_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
  `ASC_KEY_CONTENT` as GitHub Actions secrets if iOS enters release scope.

When iOS upload enters scope, make App Store Connect findings blocking in the
same local preflight:

```bash
AIRO_IOS_UPLOAD_IN_SCOPE=true melos run release:fastlane-preflight
```
