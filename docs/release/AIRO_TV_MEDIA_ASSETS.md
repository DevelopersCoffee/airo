# Airo TV Release Media Assets

Every Airo TV release should include screenshots and a short demo video before store submission.

## Current Store Assets

The current Android TV store assets are in
[`docs/store-assets/airo-tv`](../store-assets/airo-tv/).

| Asset | Status |
| --- | --- |
| 1920x1080 TV screenshots | Ready: browse, now-playing, search, playlist source |
| 1024x500 feature graphic | Ready |
| App preview video | Optional; not prepared |

Regenerate the PNG assets with:

```bash
python3 packages/feature_iptv/tool/airo_tv_store_assets.py
```

The generator requires Pillow (`python3 -m pip install Pillow`) when the local
Python environment does not already provide it.

## Screenshot Coverage

- Android TV Home
- Now playing
- Search
- Playlist Import

The current v0.0.2 release does not include EPG, favorites, recording, cloud
playlists, or AI Search. Do not add store screenshots for planned features until
[Airo TV Feature Matrix](./AIRO_TV_FEATURE_MATRIX.md) marks them supported.

## Demo Video

Target length: 60-90 seconds.

Recommended sequence:

1. Install the APK.
2. Import an authorized playlist.
3. Search for a channel.
4. Play a channel.
5. Use Cast controls.
6. Show the playlist source controls.

## Publishing Notes

- Do not include private playlists, tokens, MAC addresses, device serial numbers, or personal account details.
- Use only legally authorized demo content.
- Store screenshots and videos as release artifacts or link to the final hosted media from the GitHub release notes.
