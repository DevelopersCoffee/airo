# Aika Stream ads

Aika Stream is a BYOC live IPTV player. Users paste playlists. We do not own
the HLS, do not rewrite provider manifests, and do not run IMA/DAI stitching.
Live linear Google DAI `/stream` request URLs are rewritten to the already
stitched `master.m3u8` so the player can open them as ordinary HLS.

## What we ship

In-app **AdMob Native Advanced** cards only, consumed from
[`airo_ads`](https://pub.dev/packages/airo_ads) `^1.1.0` via the
`packages/platform_ads` shim. 1.1.0 also ships banners, interstitials,
rewarded, and app-open managers — Aika Stream does not use those formats.

- one dismissible **full-width** native banner after the first four library
  tiles, shown as soon as the Mobile Ads SDK is ready (no session warmup)
- one dismissible card on the **fullscreen** player pause overlay
- 30-minute impression cooldown after a fill or dismiss
- fail silent (`SizedBox.shrink`) on no fill
- no browse slot on leanback, so Android TV never gets a blank fifth tile

Production IDs:

- App ID `ca-app-pub-7741544685082785~7502136325`
- Native unit `ca-app-pub-7741544685082785/9923898490` (`aika_browse_native`)

Use Google sample units only with `--dart-define=AIKA_ADS_USE_TEST_UNITS=true`
on local debug builds. Never put sample IDs in a Play AAB.

Layouts use Flutter `NativeTemplateStyle` (`TemplateType.small` browse,
`medium` pause). Browse is a 120px-tall full-width slot so advertiser
assets stay inside `NativeAdView` (do not clip the small template into an
88px list row or a 128px poster cell, and do not overlay a close button on
the native view). Do not add Android XML factories.

## What we reject

- IMA DAI stream-request APIs that are not stitched HLS/DASH manifests
  (for example on-demand DASH `/stream` endpoints)
- playlist or `#EXT-X-DISCONTINUITY` rewriting
- Magnite, FreeWheel, or other enterprise OTT SSPs
- Flutter-to-Rust ad proxies
- fullscreen, interstitial, or app-open ads
- ads over playing video
- ads on Cast
- ads on leanback / ten-foot Android TV
- ads on the empty-library onboarding view

Stitched `dai.google.com` live HLS (`master.m3u8`, including a live linear
`/stream` rewrite) plays as ordinary HLS. IMA-only APIs still show
[CAST_RECEIVER_COMPATIBILITY.md](./CAST_RECEIVER_COMPATIBILITY.md)'s
unsupported-source copy.

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
`iptvAdPlacementsProvider`. `AikaAdsGate` detects phone vs leanback at
runtime: Pixel 9 running Aika Stream mounts the fifth-tile native card
as soon as the SDK is ready; Android TV never mounts a browse slot.

## Play Console

The TV AAB must include `com.google.android.gms.permission.AD_ID` and the
AdMob App ID in `app/android/app/src/tv/AndroidManifest.xml`. Data Safety
must list Device or other IDs as collected for Advertising or marketing.
Do not Include draft 15. Send listing changes with the ads AAB.
