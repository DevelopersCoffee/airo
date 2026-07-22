# Airo TV Feature Matrix

Current public release: [`airo-tv-v0.0.4`](https://github.com/DevelopersCoffee/airo/releases/tag/airo-tv-v0.0.4).

| Feature | Status | Notes |
| --- | --- | --- |
| M3U playlists | Supported | User supplies authorized playlist URLs. |
| M3U8 streams | Supported | Playback depends on the stream URL and codec support on the device. |
| Local channel and guide search | Supported | Deterministic search across user-imported channels and available XMLTV guide data; no cloud or LLM query is required. |
| Android TV | Supported | Package `io.airo.app.tv`; Leanback launcher enabled. |
| Pixel/mobile fallback | Supported | Used for smoke testing and responsive layout coverage. |
| Chromecast controls | Supported | Discovery, play, pause, stop, reload, new session, volume. |
| Favorites | Supported | Mark/unmark channels from browse and player flows; stored locally. |
| XMLTV guide | Supported | User-configured XMLTV sources only; no bundled guide feed. |
| Smart playlists and canonical channels | Supported | Local filtering and canonical identity matching help preserve personal organization across imports. |
| Provider add-flows | Supported | User-authorized Xtream, Stalker, Jellyfin, and M3U sources. |
| Picture-in-picture | Under qualification | Video-only PiP layout is test-covered; device evidence is still being gathered. |
| Phone-hosted TV streaming | Under qualification | Debug entry point and protocol tests exist; real phone-to-receiver dogfood is not yet complete. |
| Recording | Not supported | No recording or DVR storage. |
| AI Search | Planned | Local search is intentionally deterministic in this release. |
| Cloud playlists | Not supported | Playlists stay local unless users load a remote URL directly. |
| Bundled channels | Not supported | Airo TV does not provide IPTV content. |
