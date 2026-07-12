# Google Cast V1 QA Guide

## Scope

V1 verifies Google Cast only. It does not test AirPlay, local files, browser
receivers, custom receivers, proxies, or multi-device casting.

## Required Devices

- Android phone with Airo debug or release build.
- iPhone with Airo debug or TestFlight build.
- Chromecast-enabled TV, preferably Sony Bravia / Android TV / Google TV.
- Shared Wi-Fi network for phone and TV.

See [Cast receiver compatibility](CAST_RECEIVER_COMPATIBILITY.md) for the
MacBook distinction and the full supported receiver matrix.

## Test Matrix

| Case | Steps | Expected Result |
| --- | --- | --- |
| Android discovery | Open Stream, play a channel, tap Cast | TV appears in picker |
| iOS discovery | Open Stream, accept local network permission, tap Cast | TV appears in picker |
| HLS cast | Select TV for a `.m3u8` channel | TV starts playback without Airo installed on TV |
| Stop cast | Tap Stop in mini controller | Receiver stops and Airo returns to local playback-ready state |
| Replace session | Cast to TV A, then cast to TV B | TV A session ends before TV B starts |
| MacBook receiver check | Tap Cast while only a MacBook is available | MacBook is not treated as a Google Cast receiver |
| No devices | Turn TV off and tap Cast | App shows no-device guidance and Refresh |
| Receiver disconnect | Start cast, disconnect TV network | App clears active session and shows recoverable state |
| Mobile leaves Wi-Fi | Start cast, move phone off Wi-Fi | App does not crash and can reconnect after returning to Wi-Fi |

## Evidence

Record:

- App build number.
- Sender platform and OS version.
- Receiver model and OS version.
- IPTV channel ID used for HLS success.
- Screenshots of picker, active mini controller, and error state.

## V1 Exclusions

- No TV-side Airo application is required.
- No phone-hosted proxy or local HTTP server is used.
- No custom request headers are forwarded to receivers.
- No browser, laptop, AirPlay, local-file, or multi-receiver UI is exposed.
