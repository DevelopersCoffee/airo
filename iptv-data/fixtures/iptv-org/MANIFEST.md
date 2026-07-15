# iptv-org Benchmark Fixture

This directory stores the public M3U snapshot used by the host-only Airo TV
benchmark harness. The vendored file is sanitized for repository use: line
endings are normalized to LF and stream URL query strings are stripped so public
fixture data does not commit credential-like parameters.

| Field | Value |
| --- | --- |
| Fixture id | `iptv-org-index-sanitized-2026-07-15` |
| Source URL | `https://iptv-org.github.io/iptv/index.m3u` |
| Captured at | `2026-07-15T10:32:55Z` |
| Content type | `audio/x-mpegurl` |
| Last modified | `Wed, 15 Jul 2026 00:23:54 GMT` |
| ETag | `"6a56d31a-2c23aa"` |
| Upstream byte count | `2892714` |
| Vendored byte count | `2848163` |
| Vendored SHA-256 | `02525c806380aa700026838b66803d57cc9c3060ec1aefbb69e5cad3a321a0e3` |

The generated benchmark JSON and markdown artifacts record fixture metadata,
counts, and timing data only. They must not include raw playlist stream URLs,
logo URLs, local paths, credentials, or user-provided playlist data.
