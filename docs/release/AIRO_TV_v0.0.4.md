# Airo TV v0.0.4

Airo TV v0.0.4 closes the user-visible IPTV loop while preserving the
bring-your-own-content boundary. It adds local search, favorites, guide setup,
provider add-flows, smarter personal lists, clearer playback diagnostics, and
large-playlist import telemetry without adding accounts, cloud sync, DVR, or
bundled media.

## Highlights

- Search imported channels and available XMLTV guide data locally, with
  deterministic ranking and no remote query service.
- Create locally filtered smart playlists and preserve favorites/history more
  reliably through canonical channel identity matching.
- Add authorized M3U, Xtream, Stalker, Jellyfin, and XMLTV sources from the
  product flow.
- Mark favorites from browse or player surfaces; open a real guide-source flow
  when no guide data is available.
- Diagnose unavailable playback without blaming the device, record watch
  history only after playback starts, and show video-only Android PiP.
- Import large playlists through the Rust/worker boundary with safe aggregate
  parsed, skipped, malformed, and elapsed counters.

## Distribution and verification

- Android TV direct-install APK and Play Store AAB assets are published with
  checksums and a release manifest for `io.airo.app.tv`.
- macOS ZIP, DMG, and Homebrew Cask metadata are included as unsigned,
  non-notarized release evidence.
- This release records automated artifact verification. Android TV/Google TV
  and Fire TV device qualification remain explicitly limited until the
  corresponding real-device evidence is attached; Fire TV is
  compatible/experimental rather than a general-support claim.

## Known limitations

- Airo TV does not provide playlists, channels, subscriptions, or media.
  Users must provide content they are authorized to access.
- No accounts, cloud sync, recording/DVR, or bundled catalog are included.
- Phone-hosted media streaming and the real phone-to-receiver dogfood matrix
  remain under qualification.
- Web is validation-only and iOS/iPadOS are not part of this TV release.

## Full changelog

See the [repository changelog](../../CHANGELOG.md) and compare
[`airo-tv-v0.0.3...airo-tv-v0.0.4`](https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.3...airo-tv-v0.0.4).
