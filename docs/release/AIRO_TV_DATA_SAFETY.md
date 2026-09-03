# Aika Stream Data Safety And App Privacy Declarations

Console-ready privacy declaration worksheet for the Aika Stream v2 release profile.
Use this when completing Google Play Data Safety and any future Apple App
Privacy labels. Final submission still requires a maintainer with store-console
access.

## Scope

| Field | Value |
| --- | --- |
| Product | Aika Stream |
| Android package ID | `com.developerscoffee.tv.midas` |
| Entrypoint | `app/lib/main_tv.dart` |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms URL | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |
| Current release | v0.0.1+13 |

This declaration is based on the current v2 TV release behavior:

- User-provided playlist URLs and app preferences are stored locally.
- Aika Stream does not provide channels, playlists, streams, or subscriptions.
- App-owned Firebase Analytics and Firebase Crashlytics SDKs are not included
  in `app/pubspec_tv.yaml`.
- Google Cast analytics logging is explicitly disabled during Cast
  initialization.
- Firebase Core/Auth packages may be present for runtime initialization and
  future auth compatibility, but the TV flow does not require account sign-in
  for IPTV playback. Because `firebase_core` ships, a Firebase installation ID
  may be generated and sent to Google; this is declared under "Device or other
  IDs" below.
- Playlist and program-guide requests go directly from the device to the
  servers the user configured. The app does not download a public IPTV
  catalogue. The user's playlist is never uploaded anywhere.

## Google Play Data Safety

### Data Collection Summary

| Data type | Collected by app? | Shared? | Purpose | Notes |
| --- | --- | --- | --- | --- |
| Name | No | No | Not applicable | TV playback does not require account creation. |
| Email address | No | No | Not applicable | Firebase Auth is present but not required by the TV IPTV flow. |
| User IDs | No | No | Not applicable | No app-owned account identifier is required for TV playback. |
| Precise or approximate location | No | No | Not applicable | No location permission is declared in the TV manifest. |
| Contacts | No | No | Not applicable | Contact permissions are removed from the TV release profile. |
| Photos, videos, or audio files | No | No | Not applicable | No camera, microphone, or media-library permission is declared for TV. |
| Financial info | No | No | Not applicable | No purchases or payment flow in the TV release. |
| Health and fitness | No | No | Not applicable | Not used. |
| Messages | No | No | Not applicable | Not used. |
| App activity | No app-owned external collection | No | App functionality | Preferences and playlist state are stored on device. |
| Web browsing | No | No | Not applicable | Aika Stream does not provide a browser. |
| App info and performance | No app-owned external collection | No | Diagnostics only if user shares logs manually | Crashlytics is not included in the TV pubspec. |
| Device or other IDs | **Yes — collected by Firebase SDK, not by the developer** | No | App functionality | `firebase_core` is in `app/pubspec_tv.yaml`. Where Firebase generates a Firebase installation ID (FID), it is sent to Google under Google's own privacy policy. It is not received by DevelopersCoffee, not linked to a user or account, not used for advertising or cross-app tracking, and reset on uninstall or clear-data. No advertising ID permission or analytics SDK is enabled. |
| IPTV playlist URLs | Local only | No | App functionality | User-provided playlist URLs are stored on device and used to fetch user-selected content. |
| Stream URLs | Local/runtime only | No | App functionality | Stream URLs are requested by the app/player/Cast receiver only to play user-selected content. |

Recommended Play Console answer:

```text
The app does not collect or share user data with the developer for the current
TV release. User-provided IPTV playlist URLs, preferences, and playback state
are stored locally on the device for app functionality. The app does not include
advertising, analytics, Crashlytics, purchases, location, contacts, camera, or
microphone data collection in the TV profile.

The app includes the Firebase core library. Where Firebase generates a Firebase
installation ID, that identifier is transmitted to Google under Google's privacy
policy. It is declared under "Device or other IDs" for app functionality. It is
not received by the developer, not linked to a user or account, not used for
advertising or tracking, and is reset when the app is uninstalled or its data
cleared.
```

### Why "Device or other IDs" is declared Yes

Play's Data Safety scope covers data collected by **third-party SDKs bundled in
the app**, not only data the developer receives. `firebase_core` ships in the TV
profile, so the honest answer is to declare the identifier and describe its
narrow purpose, rather than answer No on the grounds that DevelopersCoffee never
sees it. Under-declaring is a policy-enforcement risk; declaring it with an
accurate purpose is not.

This must stay consistent with the published privacy policy, which describes the
same identifier in its "Network Connections" section. If `firebase_core` is ever
removed from `app/pubspec_tv.yaml`, revisit both together.

### Security Practices

| Question | Recommended answer |
| --- | --- |
| Is all user data collected encrypted in transit? | Not applicable for developer collection. Network requests initiated by users use the URL scheme of the playlist or stream they provide. |
| Can users request that data be deleted? | Local app data is removed by clearing app storage or uninstalling the app. No developer-hosted account data is collected for TV playback. |
| Is data shared with third parties? | No app-owned user data sharing. Users may load playlist/stream URLs from third-party providers they choose. |
| Does the app use advertising ID? | No. |
| Does the app use tracking for ads or cross-app profiling? | No. |

## Apple App Privacy Draft

iOS/iPadOS publication is deferred from the first v2 Android release wave. If
maintainers later add iOS/tvOS to scope, use this draft only after re-checking
the active iOS dependency set and runtime behavior.

| App Privacy category | Draft answer |
| --- | --- |
| Data Used to Track You | None |
| Data Linked to You | None for the current TV IPTV playback flow |
| Data Not Linked to You | Identifiers — the Firebase installation ID, if generated. Nothing collected by the developer. |
| Diagnostics | None unless a crash-reporting SDK is added before submission |
| User Content | User-provided playlist URLs are local app functionality data, not collected by the developer |

## Local Preflight

Generate deterministic local evidence before entering store-console forms:

```bash
AIRO_RELEASE_PROFILE=tv melos run release:data-safety-preflight
```

The preflight reads the TV pubspec and Android TV manifest, confirms Analytics,
Crashlytics, advertising SDK, and sensitive permission signals, then writes JSON
and Markdown under `artifacts/release/`. It intentionally does not submit or
replace Google Play/App Store forms.

## Human Console Actions

- Complete Google Play Data Safety using the final answers above.
- Complete App Store Connect App Privacy labels only if iOS/tvOS enters scope.
- Re-check this document if Firebase Analytics, Crashlytics, ads, account
  sign-in, cloud playlists, EPG sync, favorites sync, or server-side telemetry
  is added before release.
- Attach screenshots or console export evidence back to #583 after submission.
