# Performance Benchmarks

Airo release validation now requires a benchmark artifact, not just a verbal
claim that the app feels fast.

Use this runbook with issue `#520` and the release checklist in
[`docs/release/RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md).

## Output Artifact

Create a benchmark report before release:

```bash
make benchmark-report
```

Default output:

```text
artifacts/performance/YYYY-MM-DD-release-benchmark.md
```

Fill in the measured results, attach profiler screenshots if used, and link the
report from the release PR or release notes.

## Benchmark Matrix

| Metric | Why it matters | Environment | Minimum evidence |
| --- | --- | --- | --- |
| Cold start | Verifies startup regression | Physical Android preferred | `adb shell am start -W` result captured in report |
| Warm start | Detects lifecycle regressions | Physical Android preferred | `adb shell am start -W` result captured in report |
| Model loading time | Verifies on-device AI readiness | Host-only or Android | `make benchmark-gemini-warmup` output |
| First transcript latency | Verifies meeting responsiveness | Physical Android | Manual timed run recorded in report |
| Summary generation time | Verifies end-to-end AI flow | Physical Android | Manual timed run recorded in report |
| Embedding speed | Verifies retrieval/indexing cost | Physical Android | Manual timed run recorded in report |
| Speaker detection latency | Verifies meeting pipeline | Physical Android | Manual timed run recorded in report |
| Memory usage | Detects OOM risk and retention leaks | Android | `adb shell dumpsys meminfo` snapshot |
| CPU usage | Detects runaway loops and thermal risk | Android | profiler or `top` sample linked in report |
| GPU/NPU utilization | Verifies on-device acceleration path | Android | profiler screenshot or tooling note |
| Battery consumption | Detects release-unfriendly workloads | Physical Android | `batterystats` or Battery Historian export |
| Storage growth | Verifies model/download storage impact | Android | before/after storage capture |

## Host-Only Checks

These are safe on a laptop CI-style host and should be run on every benchmark
iteration:

```bash
melos run bench
melos run bench:report
melos run bench:xmltv-fixture
cargo bench --manifest-path rust/Cargo.toml --bench m3u_parser
make benchmark-gemini-warmup
make test-integration
```

`melos run bench` is the v2 Airo TV host benchmark smoke. It generates a
fixture-backed M3U workload from the vendored public `iptv-org` snapshot, runs
parser/search workloads for at least five iterations, evaluates the median
metrics against the platform benchmark budget, and writes both machine-readable
JSON and a markdown report:

```text
artifacts/performance/airo-tv-host-benchmark.json
artifacts/performance/airo-tv-host-benchmark.md
```

`melos run bench:report` regenerates only the markdown report from the latest
JSON artifact.

`melos run bench:xmltv-fixture` regenerates the deterministic synthetic XMLTV
fixture used by large-guide EPG/parser benchmark work:

```text
iptv-data/fixtures/xmltv/generated-50mb.xml
iptv-data/fixtures/xmltv/generated-50mb.manifest.json
```

The XMLTV fixture contains no provider URLs, credentials, or user data. The
manifest records byte count, SHA-256, channel count, programme count, and the
generator version for reproducible local validation.

Rust parser benchmark smoke:

```bash
cargo bench --manifest-path rust/Cargo.toml --bench m3u_parser
```

The criterion bench reads the sanitized public `iptv-org` fixture and reports
local parser throughput. Benchmark output is local Cargo target data and is not
committed.

`benchmark-gemini-warmup` is the minimum host-runnable proof that the Gemini
Nano support check, initialize path, and warmup path are still wired correctly
without requiring a connected device.

## Android Device Checks

Prefer a physical Android device. Use the emulator only when the issue accepts
`AIRO_ALLOW_ANDROID_EMULATOR=true`.

### Startup timing

```bash
adb shell am force-stop io.airo.app
adb shell am start -W io.airo.app/.MainActivity
```

Capture `TotalTime`, `WaitTime`, and `ThisTime` in the report.

### Memory snapshot

```bash
adb shell dumpsys meminfo io.airo.app
```

### Battery snapshot

```bash
adb shell dumpsys batterystats --reset
# run the benchmark scenario
adb shell dumpsys batterystats io.airo.app
```

### Storage snapshot

```bash
adb shell run-as io.airo.app du -sh files cache 2>/dev/null
```

If `run-as` is unavailable on the target build, record the same measurement from
the Android app info storage UI.

## Release Rule

Do not mark release validation complete until:

1. A benchmark report exists under `artifacts/performance/` or is attached to
   the release PR.
2. Host-only checks have been rerun on the release candidate.
3. Physical Android-only metrics are either captured or explicitly waived with
   a linked reason.
