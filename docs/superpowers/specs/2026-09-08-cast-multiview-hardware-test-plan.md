# Cast MultiView + 8-layout mosaic — hardware test plan

For the agent with physical devices. Host tests already cover protocol,
bridge, stage mosaics, and the phone picker. This file is the live loop.

App IDs:
- Production default Cast receiver: `CC1AD845` (untouched).
- Cast MultiView / Cast Connect (unpublished, test devices only): `F353F9C7`.
- Override: `--dart-define=CAST_MULTIVIEW_RECEIVER_APP_ID=F353F9C7`.

Phone: Pixel 9. TV: Android TV / Google TV with Aika Stream (`com.developerscoffee.tv.midas`). Fire TV is out of scope for Cast Connect.

## A. Local MultiView layouts (Pixel 9, no Cast)

1. Add 1–4 channels to MultiView. Defaults: 1 pane, side-by-side, two-over-one, 2×2.
2. Open the grid-view layout button on the video stage.
3. Confirm all eight mosaics are shown: 1 pane, 2 split, 2 stack, 1 over 2, 2 over 1, 1 + 2, 2×2, 1 + 3.
4. Pick **1 + 3** with only two channels running — two live tiles + two Empty cells. Playing tiles must not freeze.
5. Pick **2 stack** with two channels — stacked, not side-by-side.
6. Pick **1 + 2** with three channels — large left, two stacked right.
7. Adding a fifth channel is still rejected at the device budget (phone is typically 2; TV up to 4). A 3- or 4-tile mosaic is disabled when `tileCount` exceeds capacity.
8. Audio: only the featured tile is audible; promoting another tile moves audio. No freeze after promote (the `mixWithOthers` fix).

## B. Phone remote → TV MultiView (needs registered Cast serial)

Phone build: Android sender with `CAST_MULTIVIEW_RECEIVER_APP_ID=F353F9C7`.
TV build: `APP_VARIANT=tv`, same app id, Cast Connect receiver wired.

1. TV: Aika Stream running, playlist loaded.
2. Phone: Ways to Watch → Cast MultiView.
3. Cast to the TV. Phone shows **TV Connected**.
4. Tap **1 + 3**. TV stage switches to spotlight even before every slot is filled.
5. Create / launch a saved layout of 2–4 channels. TV grid matches; phone live list matches `multiview.state`.
6. Promote (focus audio) and remove a tile from the phone. TV updates live.
7. Disconnect: phone returns to Not connected; TV MultiView stays as last commanded (local).

## Blocked / do not fail this PR for

- Native `MediaLoadCommandCallback` media receiver (only if `F353F9C7` becomes the app-wide default).
- iOS Cast Connect (Android TV / Google TV only).
- `MULTIVIEW_V1.md` Fire TV 4-stream dropped-frames + RSS vs #779 (separate qual gate).
