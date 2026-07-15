# Airo TV Host Benchmark Report

| Field | Value |
| --- | --- |
| Schema | `1.0.0` |
| Captured at | `2026-07-15T10:29:49.105141Z` |
| Device class | `host_local` |
| Status | `accepted` |
| Blockers | `none` |
| Iterations | `5` |
| Channel count | `2000` |

## Dataset

| Field | Value |
| --- | --- |
| Profile | `synthetic-iptv-2000` |
| Kind | `live_iptv` |
| Live channels | `2000` |
| VOD items | `0` |
| EPG programs | `0` |
| Playlist sources | `1` |

## Budget

| Metric | Budget | Observed |
| --- | ---: | ---: |
| Total elapsed ms | `30000` | `17` |
| Peak memory MB | `512` | `0` |
| Storage MB | `64` | `not_recorded` |
| Rows/sec floor | `50.0` | `142318.37` |

## Samples

| Step | Operation | Records | Elapsed ms | Rows/sec | Memory MB | Storage MB |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `parse-m3u` | `import_batch` | `2000` | `14` | `142318.37` | `not_recorded` | `not_recorded` |
| `search-index` | `search_text` | `10000` | `3` | `3022061.05` | `not_recorded` | `not_recorded` |

## Notes

- Host benchmark fixtures are synthetic and contain no provider playlist data.
- Use this report for local regression review; device RSS/frame evidence is tracked separately.
