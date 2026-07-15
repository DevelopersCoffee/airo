# Airo TV Host Benchmark Report

| Field | Value |
| --- | --- |
| Schema | `1.0.0` |
| Captured at | `2026-07-15T10:37:16.628855Z` |
| Device class | `host_local` |
| Status | `accepted` |
| Blockers | `none` |
| Iterations | `5` |
| Channel count | `12038` |
| Fixture | `iptv-org-index-sanitized-2026-07-15` |
| Fixture source | `file_m3u` |
| Fixture bytes | `2848163` |
| Fixture SHA-256 | `02525c806380aa700026838b66803d57cc9c3060ec1aefbb69e5cad3a321a0e3` |

## Dataset

| Field | Value |
| --- | --- |
| Profile | `iptv-org-index-sanitized-2026-07-15` |
| Kind | `live_iptv` |
| Live channels | `12038` |
| VOD items | `0` |
| EPG programs | `0` |
| Playlist sources | `1` |

## Budget

| Metric | Budget | Observed |
| --- | ---: | ---: |
| Total elapsed ms | `30000` | `91` |
| Peak memory MB | `512` | `0` |
| Storage MB | `64` | `not_recorded` |
| Rows/sec floor | `50.0` | `144165.94` |

## Samples

| Step | Operation | Records | Elapsed ms | Rows/sec | Memory MB | Storage MB |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `parse-m3u` | `import_batch` | `12038` | `83` | `144165.94` | `not_recorded` | `not_recorded` |
| `search-index` | `search_text` | `60190` | `8` | `6970469.02` | `not_recorded` | `not_recorded` |

## Notes

- Host benchmark artifacts record fixture metadata, counts, and timings only.
- Public fixture runs must not copy raw stream URLs, logo URLs, or local paths into reports.
- Use this report for local regression review; device RSS/frame evidence is tracked separately.
