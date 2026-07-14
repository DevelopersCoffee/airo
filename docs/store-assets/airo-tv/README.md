# Airo TV Store Assets

Store-ready Android TV listing assets generated from deterministic Airo TV
listing compositions.

## Assets

| File | Size | Purpose |
| --- | --- | --- |
| `01-tv-home-channel-grid.png` | 1920x1080 | TV browse surface with channel categories and grid |
| `02-tv-now-playing.png` | 1920x1080 | TV now-playing state with highlighted current channel |
| `03-tv-search-dialog.png` | 1920x1080 | Channel search dialog |
| `04-tv-playlist-source.png` | 1920x1080 | Bring-your-own-playlist source sheet |
| `feature-graphic-1024x500.png` | 1024x500 | Google Play feature graphic |

The screenshots use realistic demo channel names and nonfunctional
`https://demo.airo.app/...` URLs. They do not include private playlists,
tokens, MAC addresses, device serial numbers, or personal account details.

## Regenerate

Run from the repository root:

```bash
python3 packages/feature_iptv/tool/airo_tv_store_assets.py
```

The generator writes PNG files into `docs/store-assets/airo-tv/`.
It requires Pillow (`python3 -m pip install Pillow`) when the local Python
environment does not already provide it.
