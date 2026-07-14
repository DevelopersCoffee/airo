# Airo TV Content Rating Worksheet

Console-ready worksheet for Airo TV content rating submissions. Use this when
completing the Google Play IARC questionnaire and any future App Store Connect
age rating questionnaire. Final ratings are assigned by the store consoles and
must be saved by a maintainer with console access.

## Scope

| Field | Value |
| --- | --- |
| Product | Airo TV |
| Android package ID | `io.airo.app.tv` |
| Entrypoint | `app/lib/main_tv.dart` |
| Current release | v0.0.2 |
| Privacy minimum age posture | Not directed to children under 16 |
| Content model | Media player for user-provided playlist and stream URLs |

## Recommended Store Position

| Store | Expected result | Reason |
| --- | --- | --- |
| Google Play / IARC | Teen / 12+ or stricter if questionnaire output requires it | The app UI has no mature content, but users can load external media streams. |
| App Store Connect | 12+ or stricter if questionnaire output requires it | Future iOS/tvOS scope would allow user-provided streaming URLs. |
| Target audience | 16+ | Aligns with the current Privacy Policy children's privacy posture. |

Do not market Airo TV as child-directed. Do not select a lower age target
unless legal/privacy copy is changed first.

## Questionnaire Answers

| Topic | Recommended answer | Evidence / notes |
| --- | --- | --- |
| User-generated content | No social or in-app user-generated content platform | Users provide private playlist/stream URLs; Airo TV does not publish, host, or share user content. |
| Unrestricted internet / web access | Yes if the questionnaire treats user-entered playlist or stream URLs as unrestricted network content | Users can load external media URLs they provide. |
| Violence in app UI | No | Airo TV UI does not include violent content. User-loaded streams are outside app-provided content. |
| Sexual content or nudity in app UI | No | Airo TV UI does not include sexual content or nudity. |
| Profanity or crude humor in app UI | No | Airo TV UI does not include profanity or crude humor. |
| Alcohol, tobacco, drugs, or regulated goods in app UI | No | No app-provided regulated-goods content. |
| Gambling or contests | No | No gambling feature, betting flow, or contest mechanic. |
| Horror/fear content in app UI | No | No app-provided horror/fear content. |
| Ads | No | No advertising SDK or ad placement in the v2 TV release profile. |
| In-app purchases | No | No purchase flow in the v2 TV release profile. |
| User interaction / chat | No | No chat, social feed, or user-to-user communication in the TV IPTV flow. |
| Location sharing | No | No location permission in the TV manifest. |
| Account creation required | No | IPTV playback does not require account sign-in. |
| Content disclaimer | Yes | Airo TV is a media player only and does not provide channels, playlists, streams, or subscriptions. |

## Store Notes

Recommended note for internal review:

```text
Airo TV is a media player for user-provided IPTV playlist and stream URLs. The
app does not provide channels, subscriptions, playlists, streams, ads, gambling,
chat, purchases, or app-hosted mature content. Because users can enter external
media URLs, choose the questionnaire option that best represents unrestricted
user-provided media/network content and accept the resulting Teen/12+ or
stricter rating.
```

## Human Console Actions

- Complete the Google Play IARC questionnaire for `io.airo.app.tv`.
- Save the resulting Play rating certificate or console screenshot.
- Complete App Store Connect age rating only if iOS/tvOS enters release scope.
- Attach rating evidence back to #584 before closing the issue.
- Re-run this review if ads, purchases, chat, cloud playlists, EPG sync,
  account-gated services, curated content, or bundled streams are added.
