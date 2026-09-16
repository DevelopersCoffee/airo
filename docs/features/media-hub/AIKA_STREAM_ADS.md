# Aika Stream ads

Aika Stream is a BYOC live IPTV player. Users paste playlists. We do not own
the HLS, do not rewrite manifests, and do not run IMA/DAI stitching.

## What we ship

In-app **AdMob Native Advanced** cards only, consumed from
[`airo_ads`](https://pub.dev/packages/airo_ads) via the
`packages/platform_ads` shim:

- one dismissible tile in the phone/tablet browse grid (index 4)
- one dismissible card on the **fullscreen** player pause overlay
- 5-minute session warmup, then a 30-minute impression cooldown
- fail silent (`SizedBox.shrink`) on no fill

Production IDs:

- App ID `ca-app-pub-7741544685082785~7502136325`
- Native unit `ca-app-pub-7741544685082785/9923898490` (`aika_browse_native`)

Use Google sample units only with `--dart-define=AIKA_ADS_USE_TEST_UNITS=true`
on local debug builds. Never put sample IDs in a Play AAB.

Layouts use Flutter `NativeTemplateStyle` (`TemplateType.small` browse,
`medium` pause). Do not add Android XML factories.

## What we reject

- SSAI / IMA DAI / `dai.google.com` stream-request APIs
- playlist or `#EXT-X-DISCONTINUITY` rewriting
- Magnite, FreeWheel, or other enterprise OTT SSPs
- Flutter-to-Rust ad proxies
- fullscreen, interstitial, or app-open ads
- ads over playing video
- ads on Cast
- ads on leanback / ten-foot Android TV
- ads on the empty-library onboarding view

`dai.google.com` stays an unsupported source. See
[CAST_RECEIVER_COMPATIBILITY.md](./CAST_RECEIVER_COMPATIBILITY.md).

## Runtime gates

`AikaAdPolicy` (pure Dart) and `AikaAdManager` skip serving when:

- the surface is web
- `AiroDeviceFormFactor` is TV or desktop
- `AiroTvShell.showVideoStage` is false (grid-first ten-foot)
- `VideoPlayerWidget.useTvTransportBar` is true
- `iptvCastProvider` reports an active Cast session
- the player is the 16:9 browse preview, not fullscreen

`google_mobile_ads` lives in `app/pubspec_tv.yaml`. The phone pubspec uses
`packages/stubs/google_mobile_ads_stub` so `main_tv.dart` still analyzes.
`feature_iptv` never depends on AdMob; it only exposes
`iptvAdPlacementsProvider`.

## Play Console

The TV AAB must include `com.google.android.gms.permission.AD_ID` and the
AdMob App ID in `app/android/app/src/tv/AndroidManifest.xml`. Data Safety
must list Device or other IDs as collected for Advertising or marketing.
Do not Include draft 15. Send listing changes with the ads AAB.
