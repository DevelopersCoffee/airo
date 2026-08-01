# Fire TV playback log classification

- Status: `PASS_WITH_KNOWN_PLATFORM_NOISE`
- Sample window: 5s
- Package: `io.airo.app.tv`
- Total app-scoped error lines: 489
- Known Fire OS/MediaTek property denials: 489
- Other actionable error lines: 0
- Fatal signatures among actionable lines: 0

| Known signature | Count |
| --- | ---: |
| `vendor.dpframework.log.enable` | 253 |
| `vendor.dpframework.dumpbuffer.checksum` | 118 |
| `vendor.dpframework.dumpbuffer.enable` | 118 |

Raw logcat is intentionally excluded because it can contain stream URLs,
network identifiers, or device identifiers. Known property denials are
aggregated only; every other error remains an actionable qualification failure.
