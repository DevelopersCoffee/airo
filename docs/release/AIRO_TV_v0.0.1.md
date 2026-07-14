# Airo TV v0.0.1

Airo TV v0.0.1 is the initial Android TV release from the Airo v2 release line.

## Release Metadata

- Product: Airo TV, part of Airo
- Package name: `io.airo.app.tv`
- Version: `0.0.1+1`
- Tag: `airo-tv-v0.0.1`
- Base branch: `v2`
- App category: Entertainment / Video Players & Editors

## Highlights

- IPTV M3U playlist URL import
- Channel search and play flow, including Music India search/play validation scope
- Android TV and Fire TV Leanback launcher support
- Pixel/mobile portrait and landscape fallback layout
- Cast UI states for discovery, pause/play, stop, reload, new session, and volume controls
- User-actionable Cast discovery failure messaging
- Accessibility labels and tooltips for key controls

## Play Store Readiness Notes

Airo TV is a player app. It does not provide IPTV channels, playlists, or copyrighted media. Users must supply authorized M3U playlist URLs and are responsible for the legality of their content sources.

Google Cast support depends on the receiver advertising `_googlecast._tcp` and allowing local network reachability on port `8009`. If discovery fails, users should verify the TV/Chromecast is powered on, on the same network, and not blocked by router/client isolation.

## Release Pipeline

Use the `Airo TV Release` GitHub Actions workflow to cut a release branch from `v2`, build Android TV artifacts, optionally upload to a Play testing track, and publish the GitHub release.

Default workflow inputs for this release:

- `version`: `airo-tv-v0.0.1`
- `build_name`: `0.0.1`
- `build_number`: `1`
- `release_ref`: `v2`
- `release_branch`: `release/airo-tv-v0.0.1`

## Verification Checklist

- `flutter analyze` for touched app/package areas
- App router / TV router focused tests
- IPTV screen and UI tests
- IPTV cast notifier/UI tests
- `platform_player` Cast controller tests
- Debug APK build with `lib/main_tv.dart`, `APP_VARIANT=tv`, `APP_PLATFORM=androidTv`
- Release AAB build with the same TV defines
