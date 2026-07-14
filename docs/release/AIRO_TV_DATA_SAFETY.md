# Airo TV Data Safety And App Privacy Declarations

Console-ready privacy declaration worksheet for the Airo TV v2 release profile.
Use this when completing Google Play Data Safety and any future Apple App
Privacy labels. Final submission still requires a maintainer with store-console
access.

## Scope

| Field | Value |
| --- | --- |
| Product | Airo TV |
| Android package ID | `io.airo.app.tv` |
| Entrypoint | `app/lib/main_tv.dart` |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms URL | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |
| Current release | v0.0.2 |

This declaration is based on the current v2 TV release behavior:

- User-provided playlist URLs and app preferences are stored locally.
- Airo TV does not provide channels, playlists, streams, or subscriptions.
- App-owned Firebase Analytics and Firebase Crashlytics SDKs are not included
  in `app/pubspec_tv.yaml`.
- Google Cast analytics logging is explicitly disabled during Cast
  initialization.
- Firebase Core/Auth packages may be present for runtime initialization and
  future auth compatibility, but the TV flow does not require account sign-in
  for IPTV playback.

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
| Web browsing | No | No | Not applicable | Airo TV does not provide a browser. |
| App info and performance | No app-owned external collection | No | Diagnostics only if user shares logs manually | Crashlytics is not included in the TV pubspec. |
| Device or other IDs | No app-owned external collection | No | Not applicable | No advertising ID permission or analytics SDK is enabled. |
| IPTV playlist URLs | Local only | No | App functionality | User-provided playlist URLs are stored on device and used to fetch user-selected content. |
| Stream URLs | Local/runtime only | No | App functionality | Stream URLs are requested by the app/player/Cast receiver only to play user-selected content. |

Recommended Play Console answer:

```text
The app does not collect or share user data with the developer for the current
TV release. User-provided IPTV playlist URLs, preferences, and playback state
are stored locally on the device for app functionality. The app does not include
advertising, analytics, Crashlytics, purchases, location, contacts, camera, or
microphone data collection in the TV profile.
```

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
| Data Not Linked to You | None collected by the developer for the current TV profile |
| Diagnostics | None unless a crash-reporting SDK is added before submission |
| User Content | User-provided playlist URLs are local app functionality data, not collected by the developer |

## Human Console Actions

- Complete Google Play Data Safety using the final answers above.
- Complete App Store Connect App Privacy labels only if iOS/tvOS enters scope.
- Re-check this document if Firebase Analytics, Crashlytics, ads, account
  sign-in, cloud playlists, EPG sync, favorites sync, or server-side telemetry
  is added before release.
- Attach screenshots or console export evidence back to #583 after submission.
