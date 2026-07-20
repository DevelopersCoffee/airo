# CV-033 Real-Device Dogfood — Phone-Hosted Streaming

Tracks: airo #889. Related: #844 (CV-033 shipped), #849 (security fast-follows).

## Hardware used

- Phone: <model, Android version, Airo build>
- Receiver(s): <Fire TV Stick / Android TV model>
- Router: <model, band used (2.4GHz/5GHz)>
- Test file: <filename, size, codec — must be real H.264/AAC MP4, not sparse>
- Unsupported-format test file: <filename, format>

## Test matrix

| # | Test | Result | Timing | Notes |
|---|---|---|---|---|
| 1 | Cold handoff (PASS < 10s to first frame) | | | |
| 2 | Seek forward to ~90% (PASS < 5s resume) | | | |
| 3 | Seek backward to ~10% | | | |
| 4 | Pause 3 min → resume (idle timeout interaction) | | | |
| 5 | Sustained playback 30 min (rebuffer/battery/thermal) | | | |
| 6 | Zero bytes on TV (storage check before/after) | | | |
| 7 | Unsupported format (.avi/MPEG-2) | | | |
| 8 | Stop casting (server socket closed, curl refused) | | | |
| 9 | Token security spot-check (wrong token 404, right token 206) | | | |
| 10 | Wi-Fi drop 30s mid-playback | | | |
| 11 | App background-kill mid-playback | | | |
| 12 | Cross-receiver repeat (items 1-3) | | | |

## Evidence

- adb logcat excerpt (PhoneMediaServer/session events only, confirm no full URLs/tokens/paths):
- Screenshots/photos: <link or path per matrix item with a visual component>

## Follow-up issues filed

- Item 4: <issue link or "no issue needed">
- Item 10: <issue link or "no issue needed">
- Item 11: <issue link or "no issue needed">
- Other surprises: <issue links>

## Summary

<One paragraph: overall verdict, any FAILs, whether #844 comment was posted>
