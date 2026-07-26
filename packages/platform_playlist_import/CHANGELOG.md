## 0.0.1

- Added `IndexedM3uPlaylistService`, a bounded page/search adapter over the
  native Playlist Engine v2. Native-unavailable environments return null so
  callers can select the existing deterministic worker-backed fallback.
