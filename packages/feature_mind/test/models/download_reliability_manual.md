# Mind first-run download reliability — manual note

## Acceptance

- Retry UI shows **Resume download** / **Try again** after fail or stall
- Progress persists across restart when WorkManager / URLSession retains partials
- Failed file names are named on screen (not silent skip)
- Unit tests cover coordinator + provider stall watchdogs (no 570 MB CI download)

## Device verification

**Blocked on Pixel 9 for this agent pass:** `adb devices` listed no
attached devices (daemon started empty). No emulator was provisioned for the
~570 MB scribe bundle walk.

Covered instead by:

```bash
cd packages/core_ai && flutter test test/download/
cd packages/feature_mind && flutter test test/models/download_model_provider_test.dart
cd packages/feature_mind && flutter test test/models/model_download_coordinator_test.dart
cd packages/feature_mind && flutter test test/model_acquisition_test.dart
```

Re-run on Pixel 9 before release dogfood: kill the app mid-download of the
scribe bundle, relaunch Mind, confirm **Resume download** continues from the
`.part` file rather than `modelsMissing` with a silent hang.
