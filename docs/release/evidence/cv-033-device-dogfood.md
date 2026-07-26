# CV-033 Real-Device Dogfood — Phone-Hosted Streaming

Tracks: airo #889. Related: #844 (CV-033 shipped), #849 (security fast-follows).

## Hardware used

- Phone: Pixel 9, Android 17 (API 37), Airo debug build from `efccdc49`
  (`io.airo.app`, APK SHA-256
  `6116e407fc0e622a6db1464998ae99c2ece0528c096299f9a810e0364bd67cdb`).
- Receiver: Fire TV AFTSSS, Android 9 (API 28), Amazon Cast sink
  `com.amazon.cast.sink` version 9.
- Network: both devices were reachable on the same `192.168.1.0/24` LAN.
  Router model and radio band were not exposed by the available ADB diagnostics
  and remain unrecorded. SSID and BSSID were deliberately omitted.
- Initial discovery fixture: local MP4, 3.99 MB. The filename is omitted from
  the public evidence. This fixture was selected only to reach receiver
  discovery; playback and codec support were not exercised.
- Required large-file fixture: unavailable. The phone had no real approximately
  5 GB H.264/AAC MP4. Its largest local movie was a real 6.10 GB MKV, which
  does not satisfy the positive-path fixture requirement.
- Unsupported-format candidate: local MKV, 6.10 GB. The filename is omitted
  from the public evidence. It was not submitted because no compatible receiver
  could be discovered.

## Test matrix

| # | Test | Result | Timing | Notes |
|---|---|---|---|---|
| 1 | Cold handoff (PASS < 10s to first frame) | BLOCKED | Discovery observed for 15 s | Google Cast initialized with receiver app `CC1AD845` and actively browsed `_googlecast._tcp.local`, but returned zero devices. The Fire TV exposes Amazon Cast, not a Google Cast receiver. No session or media URL was created. |
| 2 | Seek forward to ~90% (PASS < 5s resume) | NOT RUN | — | Blocked before session start. |
| 3 | Seek backward to ~10% | NOT RUN | — | Blocked before session start. |
| 4 | Pause 3 min → resume (idle timeout interaction) | NOT RUN | — | Blocked before session start. |
| 5 | Sustained playback 30 min (rebuffer/battery/thermal) | NOT RUN | — | Blocked before session start. Pixel baseline was 55% battery and 35.8°C while charging. |
| 6 | Zero bytes on TV (storage check before/after) | NOT RUN | — | Fire TV baseline `/data` usage was 3.2 GB of 4.9 GB with 1.5 GB available. No playback session started. |
| 7 | Unsupported format (.avi/MPEG-2) | NOT RUN | — | No compatible receiver was discoverable. |
| 8 | Stop casting (server socket closed, curl refused) | NOT RUN | — | No server socket was opened. |
| 9 | Token security spot-check (wrong token 404, right token 206) | NOT RUN | — | No tokenized session URL was created. |
| 10 | Wi-Fi drop 30s mid-playback | NOT RUN | — | No playback session started. |
| 11 | App background-kill mid-playback | NOT RUN | — | No playback session started. |
| 12 | Cross-receiver repeat (items 1-3) | NOT RUN | — | No second compatible receiver was available. |

## Evidence

- Screenshot: [Fire TV not found by Google Cast discovery](assets/cv-033-fire-tv-no-google-cast.jpg).
- Redacted Pixel logcat excerpt:

  ```text
  [AiroCast] initialized receiverApp=CC1AD845
  [AiroCast] session update null
  DiscoveryManager: onDevicesChanged []
  MdnsDiscoveryManager: Registering listener for serviceType:
    _googlecast._tcp.local
  ```

  The captured discovery excerpt contains no media URL, session token, file
  path, SSID, or BSSID. `PhoneMediaServer` did not start because discovery
  never produced a receiver.

## Follow-up issues filed

- Item 4: not reached.
- Item 10: not reached.
- Item 11: not reached.
- Receiver protocol mismatch: [#1151](https://github.com/DevelopersCoffee/airo/issues/1151).

## Summary

The available Pixel 9 and Fire TV pair cannot execute the CV-033 playback
matrix. CV-033 is a Google Cast sender, while the Fire TV AFTSSS exposes an
Amazon Cast sink and did not appear in active Google Cast discovery. The
positive-path large MP4 fixture is also missing. This run therefore records a
real, reproducible qualification blocker rather than a playback result. Issue
#1151 tracks the receiver-protocol mismatch. #844 has not been given a matrix
completion comment because the matrix is not complete.
