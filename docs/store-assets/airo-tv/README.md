# Aika Stream Store Assets

Store-ready Android TV listing assets for `com.developerscoffee.tv.midas`.
The checked-in images remain the reviewed baseline; release candidates are
captured from the live Flutter TV runtime and uploaded as workflow evidence.

## Assets

| File | Size | Purpose |
| --- | --- | --- |
| `play-icon-512x512.png` | 512x512 | Play Console high-res icon (32-bit PNG from xxxhdpi launcher) |
| `01-tv-home-channel-grid.png` | 1920x1080 | TV browse surface with channel categories and grid |
| `02-tv-now-playing.png` | 1920x1080 | TV now-playing state with highlighted current channel |
| `03-tv-search-dialog.png` | 1920x1080 | Channel search dialog |
| `04-tv-playlist-source.png` | 1920x1080 | Bring-your-own-playlist source sheet |
| `05-mobile-multiple-playlist-sources-1080x1920.png` | 1080x1920 | Phone listing candidate for touch multi-playlist management |
| `feature-graphic-1024x500.png` | 1024x500 | Google Play feature graphic |

The checked-in screenshots use realistic demo channel names and nonfunctional
`https://demo.airo.app/...` URLs. Automated captures use the repository-owned
`e2e/fixtures/airo-tv-viewport.m3u` playlist and local video fixture. Neither
path includes private playlists, tokens, MAC addresses, device serial numbers,
or personal account details.

`05-mobile-multiple-playlist-sources-1080x1920.png` is a sanitized Pixel 9
qualification capture. Third-party playback imagery, channel branding, and
personal notification icons were replaced with owned Airo demo artwork. It is
a candidate for the next qualified mobile listing; the published
`v0.0.6-rc.1` release does not include multiple-playlist merge. It is a manual
physical-device capture, not output of the generator script below, still
carries the older "Airo TV" header and iptv-org sample playlist URLs, and is
**not part of the first Aika Stream TV listing** — it is left untouched until
it is recaptured for that rebrand.

## Capture a release candidate

Run from the repository root:

```bash
scripts/capture-airo-tv-store-assets.sh
```

This builds `main_tv.dart`, drives Browse, Search, Player, and Guide through
Playwright, then writes RGB/no-alpha PNGs and `store-assets.json` under
`artifacts/store-listing/processed/`. The portrait capture is padded when
needed to satisfy the Play Store 2:1 maximum aspect ratio. The feature graphic
is always cropped to exactly 1024x500.

The mobile screenshot is maintained separately from the automated TV capture
set because it records physical Pixel 9 qualification evidence. Keep it at
1080x1920, re-sanitize every replacement capture, and re-run the public page
audit before publication.

The feature background in `source/feature-graphic-background.png` was generated
for Airo from this text-only brief: “Abstract cinematic TV media library
backdrop in deep navy, teal and warm amber, visual interest on the right,
negative space on the left, no text, no logos, no people, no copyrighted
characters, no claims.” It is an owned source asset, not a third-party poster.

For the older deterministic composition generator, run:

```bash
python3 packages/feature_iptv/tool/airo_tv_store_assets.py
```
