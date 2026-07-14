# Airo Trust And Transparency

Airo v2 public releases are designed around user-controlled media, transparent
release artifacts, and privacy-aware engineering.

## What Airo TV Is

Airo TV is an IPTV player for user-supplied, legally authorized playlists. It
does not provide IPTV channels, playlists, subscriptions, or media content.

Users are responsible for the playlists and media sources they choose to load.

## User Media And Playlists

For the Airo TV player flow:

- playlists are supplied by the user;
- playlist URLs and imported playlist metadata are intended to remain
  local-first;
- Airo does not upload playlist files or playlist URLs to Airo-operated servers
  as part of normal playback;
- Cast discovery uses local-network receiver discovery and can fail when local
  network access is blocked.

Future sync, account, analytics, or cloud features must document their data flow
before release.

## Accounts And Telemetry

Airo TV does not require a mandatory account for the basic player flow.

No hidden telemetry is documented for Airo TV v0.0.2. If analytics, crash
reporting, or diagnostics are added to a future public release, the privacy
policy, release notes, and relevant settings must be updated before that release
ships.

## Release Artifacts

Public release artifacts are published through GitHub Releases:

<https://github.com/DevelopersCoffee/airo/releases>

Release artifacts should include:

- APK files for supported direct-install profiles;
- AAB files for store upload workflows, when applicable;
- `SHA256SUMS` for direct verification;
- release notes describing supported profiles and known limits.

See [VERIFY_DOWNLOAD.md](VERIFY_DOWNLOAD.md) before installing direct-download
APKs.

## Open Development

Airo development is tracked publicly where possible:

- [Issues](https://github.com/DevelopersCoffee/airo/issues)
- [Roadmap](ROADMAP.md)
- [Changelog](CHANGELOG.md)
- [Security policy](SECURITY.md)
- [Privacy policy](PRIVACY.md)
- [Airo TV threat model](docs/security/AIRO_TV_THREAT_MODEL.md)

Sensitive security reports should use the private vulnerability reporting path
described in [SECURITY.md](SECURITY.md), not public issues.

## What Airo Does Not Promise

Airo does not promise that every playlist, stream, codec, TV, or network setup
will work. IPTV streams can fail because of unsupported codecs, provider-side
headers, receiver CORS behavior, network isolation, VPNs, expired links, or
playlist quality.

Release notes and device qualification reports should describe the profiles and
devices that were actually validated for each release.
