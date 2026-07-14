# Privacy Policy

Airo TV is an IPTV player for user-supplied playlists. It is designed so playlist usage can remain local to the device.

## Data Collection

Airo TV does not provide IPTV channels, media content, or playlists.

Airo TV does not upload playlist files or playlist URLs to Airo-operated servers as part of normal playback.

## Local Data

The app may store the following on the device:

- Playlist URLs or imported playlist metadata.
- Playback and UI preferences.
- Cast device selection state.
- Diagnostic state needed to show user-actionable error messages.

## Analytics

No analytics are documented for Airo TV v0.0.2. If analytics are added in a future release, this policy must be updated before release.

## Network Access

Airo TV uses network access to:

- Load user-supplied playlist URLs.
- Play user-selected media streams.
- Discover Google Cast receivers on the local network.
- Connect to selected Cast receivers.

## Chromecast Discovery

Cast discovery depends on local network service discovery for `_googlecast._tcp` and receiver reachability, commonly on port `8009`.

Discovery can fail if the TV or Chromecast is powered off, connected to a different network, or blocked by router isolation or firewall rules.

## Permissions

Permissions are limited to the capabilities required by the app and platform integrations. Permissions should be documented in release notes when they change.

## Content Responsibility

Users are responsible for supplying legally authorized IPTV playlists. Airo TV does not host, validate, or license third-party media content.

## Contact

Report privacy-impacting bugs through the private security process in `SECURITY.md`.
