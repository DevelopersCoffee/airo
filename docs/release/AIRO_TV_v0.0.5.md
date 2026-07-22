# Airo TV v0.0.5

Airo TV v0.0.5 is a product-surface consolidation and playback usability
release for the Airo TV profile. It keeps Airo TV as the focused IPTV product,
removes obsolete standalone Streaming/IPTV product targets from the release
surface, and improves phone, tablet, Android TV, and macOS browse/playback
flows without bundling media content.

## Highlights

- Keeps the public product matrix focused on `Airo` and `Airo TV`; obsolete
  Airo Streaming and Airo IPTV release targets are removed from build and
  release configuration.
- Adds TV Explorer-inspired Airo TV browse controls: search, category, country,
  and language filters with clearer country names and deduplicated categories.
- Adds first-run country selection and a Settings path to change country later.
- Restores important Settings affordances for theme selection and playback/PiP
  preferences.
- Improves player overlays so Airo TV keeps one consistent control layer across
  compact portrait, compact landscape, and fullscreen playback.
- Adds bounded channel-health warmup around the visible/current channel window
  so channel switching can avoid obviously unavailable streams and feel closer
  to normal TV surfing.

## Distribution and verification

- Android TV direct-install APK and Play Store AAB assets are built from
  `app/lib/main_tv.dart` with package `io.airo.app.tv`.
- Full Airo Android artifacts remain built from `app/lib/main.dart` with package
  `io.airo.app`.
- macOS Airo TV artifacts remain direct-download validation artifacts unless
  signing and notarization secrets are supplied.
- The release workflows default to `airo-tv-v0.0.5`, build name `0.0.5`, build
  number `5`, and release branch `release/airo-tv-v0.0.5`.

## Known limitations

- Airo TV does not provide playlists, channels, subscriptions, or media. Users
  must provide content they are authorized to access.
- Recording/DVR storage and cloud playlist sync are not included.
- Picture-in-picture and cast behavior have automated coverage and local
  dogfood evidence, but final public device qualification must be attached to
  the release evidence before broad publication claims.
- Production Android signing, Firebase distribution, Play upload, and macOS
  notarization still require maintainer-owned secrets and console access.
- Fire TV and legacy Android TV boxes remain compatible/experimental until
  dedicated physical-device evidence is attached.

## Full changelog

See the [repository changelog](../../CHANGELOG.md) and compare
[`airo-tv-v0.0.4...airo-tv-v0.0.5`](https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.4...airo-tv-v0.0.5).
