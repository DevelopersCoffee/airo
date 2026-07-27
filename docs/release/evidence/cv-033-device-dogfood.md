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
- Android document lease cannot be served:
  [#1155](https://github.com/DevelopersCoffee/airo/issues/1155).
- Cast SDK logcat exposes the tokenized media URL:
  [#1156](https://github.com/DevelopersCoffee/airo/issues/1156).
- Phone UI remains in Playing after receiver failure:
  [#1157](https://github.com/DevelopersCoffee/airo/issues/1157).

## Google Cast receiver rerun — 2026-07-26

After the original Fire TV protocol blocker was recorded, a compatible Sony
BRAVIA became available on the same LAN. It advertised
`_googlecast._tcp.local` and the Default Media Receiver on Cast port 8009.

- Phone: Pixel 9, Android 17 (API 37).
- Build: current `origin/main` at `2dd0fa57`, debug APK built with
  `ENABLE_PHONE_MEDIA_RECEIVER=true`, SHA-256
  `4c71371b603c58af9706c91c0c72dd4eb1196ba6864e8d0c166bdc2bac2b97d2`.
- Receiver: Sony BRAVIA Google Cast receiver. Stable device identifiers are
  omitted from public evidence.
- Phone baseline: 100% battery and 27.5°C while charging.
- Fixture: a real local MP4 selected through Android DocumentsUI. Its name,
  content URI, and path are omitted. This first rerun intentionally used the
  smaller supported fixture to prove the production picker/receiver path before
  attempting the required multi-gigabyte case.

| # | Test | Result | Timing | Notes |
|---|---|---|---|---|
| 1 | Cold handoff (PASS < 10s to first frame) | FAIL | Cast connected in about 5s; load failed in under 1s | Discovery, receiver selection, Cast connection, Default Media Receiver launch, and phone server startup succeeded. The first receiver request produced `PathAccessException`; the receiver reported `idle/error`, the server closed, and no first frame appeared. |
| 2 | Seek forward to ~90% | NOT RUN | — | Blocked by item 1 source-read failure. |
| 3 | Seek backward to ~10% | NOT RUN | — | Blocked by item 1 source-read failure. |
| 4 | Pause 3 min → resume | NOT RUN | — | Blocked by item 1 source-read failure. |
| 5 | Sustained playback 30 min | NOT RUN | — | Blocked by item 1 source-read failure. |
| 6 | Zero bytes on TV | INCONCLUSIVE | — | No first frame or sustained playback; no full-file transfer was observed. |
| 7 | Unsupported format | NOT RUN | — | Positive-path failure captured first; do not mix fixes or additional diagnosis into this run. |
| 8 | Stop casting / socket close | PARTIAL PASS | <1s after receiver error | The phone server emitted `session_close` immediately after the receiver load error. User-initiated stop remains untested. |
| 9 | Token security spot-check | FAIL (logging gate) | — | A Cast SDK status log exposed the complete tokenized content URL. The token is omitted here and the session was torn down. |
| 10 | Wi-Fi drop | NOT RUN | — | Blocked by item 1 source-read failure. |
| 11 | App background-kill | NOT RUN | — | Blocked by item 1 source-read failure. |
| 12 | Cross-receiver | NOT RUN | — | The Fire TV remains protocol-incompatible with this Google Cast baseline. |

Redacted event sequence:

```text
[AiroCast] connect start device=<receiver>
[AiroCast] session update state=connected device=<receiver>
[PhoneMediaServer] session_open {serverId: <stable-redacted-id>}
[AiroCast] load request sent
[PhoneMediaServer] request_error {errorType: PathAccessException}
[AiroCast] media status player=idle idle=error
[PhoneMediaServer] session_close {serverId: <stable-redacted-id>}
```

The run also found that the phone sheet continued to display Playing after the
receiver and server had failed. No D-pad, TV focus, or remote-navigation
behavior was exercised.

## Summary

The Fire TV remains incompatible with the CV-033 Google Cast protocol. A later
Pixel-to-BRAVIA run proved compatible discovery and connection but exposed a
production Android source-handle failure before first frame, plus a tokenized
URL logging violation and stale Playing UI. The required large-file, seek,
lifecycle, storage, and thermal matrix remains blocked until #1155 and #1156
are resolved. #844 is complete as the host-tested baseline; #889 remains open
as the physical qualification gate.
