# Cast receiver compatibility

## V1 Scope

Airo TV uses Google Cast sender behavior. The mobile app starts a Cast
session, then the receiver fetches and plays the public media URL.

Supported V1 receivers:

- Chromecast
- Google TV
- Android TV with Google Cast support
- Cast-enabled smart TVs, including Sony Bravia / Google TV devices

Supported V1 media:

- public HLS (`.m3u8`) streams
- public progressive MP4 streams
- streams reachable by the receiver device itself

Unsupported V1 receivers:

- MacBook as a generic Google Cast receiver
- arbitrary browser tabs as receivers
- local laptop receiver without a custom receiver app
- AirPlay receiver from Android / Pixel sender
- local file receiver

## MacBook Testing

A MacBook is useful for developer validation, but it is not the same as a Cast
receiver for the Pixel 9 sender path.

Use these paths separately:

- Pixel 9 to Chromecast / Google TV: validates real Google Cast.
- Pixel 9 screen mirroring over ADB tooling: validates phone UI on the Mac, not
  media casting.
- iPhone / iPad / Mac to Mac AirPlay Receiver: validates Apple AirPlay, not
  Android Google Cast.
- Browser receiver prototype: future scope requiring custom receiver work.

Do not mark MacBook playback as Google Cast V1 success unless the Mac is running
a deliberate custom Cast-compatible receiver implementation.

## Network Requirements

- Sender and receiver must be on the same Wi-Fi or routable local network.
- Router client isolation must be disabled.
- mDNS / Bonjour discovery must be available for receiver discovery.
- The receiver must be able to fetch the media URL directly.
- Streams requiring user-agent, referrer, cookies, auth headers, or phone-local
  addresses are unsupported in V1 unless a future proxy/receiver feature handles
  them explicitly.

## Test Matrix

| Sender | Receiver | Expected result |
| --- | --- | --- |
| Pixel 9 standalone IPTV APK | Chromecast / Google TV | Receiver appears in picker and plays public HLS/MP4 |
| Pixel 9 standalone IPTV APK | MacBook | Not expected to appear as a Google Cast receiver |
| iPhone / iPad sender | Chromecast / Google TV | Receiver appears after local-network permission |
| iPhone / iPad / Mac | MacBook AirPlay Receiver | AirPlay path only, outside Google Cast V1 |
| Web app in browser | Browser tab | Web validation only, not receiver playback |

## References

- Google Cast overview: https://developers.google.com/cast/docs/overview
- Google Default Media Web Receiver: https://developers.google.com/cast/docs/web_receiver
- Apple AirPlay to Mac: https://support.apple.com/guide/mac-help/stream-video-and-audio-with-airplay-mchld7e543a0/mac
