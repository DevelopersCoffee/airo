# Fire TV PR #1244 follow-up verification fixture

Tracking issue: [#1272](https://github.com/DevelopersCoffee/airo/issues/1272)

This is a preparation guide, not device-pass evidence. Do not mark any item
PASS until the sequence is completed on a physical Fire TV with remote-only
input.

## Build and install

1. Build the follow-up PR's exact head as the TV debug application.
2. Record the commit SHA and APK SHA-256 in the device report.
3. Uninstall `io.airo.app.tv` from the Fire TV.
4. Install the APK as a fresh install, not an in-place `-r` update.
5. Use a playlist fixture containing:
   - one playable live stream;
   - one deterministic terminal/geo-blocked stream;
   - one stream exposing at least two qualities;
   - one stream exposing at least two audio tracks and two subtitle tracks.

The checked-in A/B fixtures also carry the current iptv-org entries for
**Vevo Pop**, **YRF Music**, and **B4U Music** as the real-stream playback set.
Before device use, confirm their URLs still return an HLS manifest because
public playlist endpoints can change independently of Airo.

## Player actions and selectors

1. Start the playable stream and enter fullscreen.
2. Press MENU. If Fire OS intercepts MENU on the device, reveal the transport
   bar with CENTER and open the visible **More** action using only the D-pad.
3. Confirm the **Player actions** sheet opens with visible focus on
   **Listen only**.
4. Traverse every rendered row with UP and DOWN, capture each focused row,
   and activate each row with CENTER in a separate pass.
5. Open Quality, Subtitles, and Audio. Confirm the current option is focused;
   confirm **Off** is focused when no subtitle is selected; traverse and apply
   every option.
6. Press BACK inside each selector and sheet. Confirm only the top surface
   closes and focus returns to its launching row/control.
7. While a sheet is open, send repeated UP/DOWN and confirm the Mini Guide and
   underlying player state do not change.

## Playback recovery

1. Start the deterministic terminal/geo-blocked stream.
2. Wait for **Playback could not start on this device**.
3. Confirm **Try Again** has a visible ring without an extra key press.
4. Traverse Try Again → Skip Channel → Report dead link with RIGHT, then back
   with LEFT.
5. Activate Try Again with CENTER. If retry fails and the recovery surface
   mounts again, confirm Try Again visibly owns focus again.
6. Wait at least five seconds after moving focus to Skip Channel and confirm
   delayed control-hide work does not return focus to the player surface.

## CV-017 favorite re-import fixture

The deterministic host fixture is
`packages/feature_iptv/test/iptv/presentation/widgets/favorite_reimport_review_banner_test.dart`.
It creates the old favorite and a name-based replacement candidate, then
proves Keep/Dismiss focus, closed-loop traversal, and separate CENTER actions.

For physical verification:

1. From the repository root, serve `docs/testing/fixtures` on the verification
   LAN (for example, `python3 -m http.server 8765 --directory
   docs/testing/fixtures`). Import
   `http://<host-lan-ip>:8765/fire-tv-cv017-playlist-a.m3u`. Its working
   `Fixture News HD` channel deliberately has no `tvg-id`; the URL-derived
   channel id will therefore change in playlist B.
2. Open the fullscreen transport bar, choose **Info**, and add the channel to
   favorites from the channel-actions overlay.
3. Reimport
   `http://<host-lan-ip>:8765/fire-tv-cv017-playlist-b.m3u`. Its URL-derived
   id differs and its normalized name `fixture-news` matches
   `Fixture News HD`, forcing name-based review rather than an exact-id or
   `tvg-id` remap.
4. Open Favorites and confirm the review banner appears.
5. Confirm Keep visibly owns focus, RIGHT moves to Dismiss, and another RIGHT
   does not leak behind the banner.
6. In separate fresh cases, activate Keep and Dismiss with CENTER and verify
   the resulting favorite id.

## #1189 Play file on TV fixture

This path requires two real devices and must not be claimed as passing from a
host-only widget test.

1. Put an Airo phone build and the Fire TV receiver build from the same commit
   on the same non-guest Wi-Fi network. Disable AP/client isolation.
2. Pair the phone with the receiver and keep the receiver visible/awake.
3. Place a small supported H.264/AAC MP4 file on the phone. Use a filename
   without credentials or private identifiers because it may appear in local
   diagnostics.
4. From the phone's local-file source, choose **Play file on TV** and select
   the paired Fire TV.
5. Confirm opening the sheet does not immediately show a false failure, the
   intended primary action visibly owns focus, and the sheet works without
   touch.
6. Run a separate failure case by stopping the phone host or disconnecting
   Wi-Fi after selection; confirm the real failure state is shown.
7. Record phone model/OS, Fire TV model, network topology, source media codec
   and size, commit SHA, and screenshots. Do not record the full local path,
   receiver token, or session URL.

## Preserved regressions

After the checks above:

1. Enter fullscreen, wait eight seconds, press UP, and confirm Mini Guide opens
   (#1238).
2. Send five sequential DOWN events in a long channel list and confirm focus
   moves exactly one item per event (#1185).
3. On a fresh install, confirm the empty-playlist heading, copy, and Add
   playlist action clear the permanent rail at 1920×1080 and the focused
   action ring is not clipped.

## Fire OS playback-log classification

Issue [#1243](https://github.com/DevelopersCoffee/airo/issues/1243) records
three `vendor.dpframework` property denials emitted at display-buffer cadence
on the MediaTek-based AFTSSS. A repository-wide audit found no Airo source call
that reads those properties. Do not disable hardware acceleration or hide
logcat globally: that would trade a platform diagnostic quirk for playback
regressions and could conceal real errors.

With visible playback active, run:

```bash
scripts/check-fire-tv-playback-logs.sh \
  --output artifacts/release-qualification/fire-tv-playback-log-report.md
```

The check launches the declared leanback activity, samples only the Aika Stream
PID for a bounded window, aggregates the three exact known signatures, and
fails if any other error remains. It never publishes raw logcat, which may
contain media URLs, LAN identifiers, or device identifiers.
