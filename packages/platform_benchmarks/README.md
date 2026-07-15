# platform_benchmarks

Host-runnable benchmark and evidence tools for Airo platform performance.

## Airo TV Memory Timeline

Use the local ADB memory capture when a physical Android TV device or 1 GB test
profile is connected:

```bash
AIRO_TV_PACKAGE=io.airo.app \
AIRO_TV_MEMORY_SAMPLES=60 \
AIRO_TV_MEMORY_INTERVAL_SECONDS=30 \
AIRO_TV_MEMORY_BUDGET=constrained \
melos run bench:tv-memory
```

The command samples:

```bash
adb shell dumpsys meminfo <package>
```

and writes sanitized evidence to:

- `artifacts/performance/airo-tv-adb-memory-timeline.json`
- `artifacts/performance/airo-tv-adb-memory-timeline.md`

Reports use `platform_device_profile` memory budgets and include aggregate RSS
values, optional Dart heap/image cache placeholders, retained channel-list copy
counts, and stable budget violation codes. They do not include raw `dumpsys`
output, local file paths from the device, playlist payloads, or user data.

## Cast Proxy Benchmark Report

After a physical sender-device Cast proxy run, write the sanitized benchmark
artifact with:

```bash
dart run tool/write_cast_proxy_benchmark_report.dart \
  --sample-id pixel9-cast-proxy-20mbps \
  --scenario-id 20mbps-10m-cast-relay \
  --target-mbps 20 \
  --observed-mbps 21.4 \
  --cpu-percent 3.2 \
  --duration-seconds 600 \
  --dropped-connections 0 \
  --battery-percent-per-hour 4.2
```

The command evaluates the sample with `platform_player` cast proxy benchmark
policy and writes:

- `artifacts/performance/cast-proxy-benchmark.json`
- `artifacts/performance/cast-proxy-benchmark.md`

The repository shortcut requires measured throughput and sender CPU values:

```bash
CAST_PROXY_OBSERVED_MBPS=21.4 \
CAST_PROXY_CPU_PERCENT=3.2 \
melos run bench:cast-proxy-report
```

Reports contain aggregate throughput, CPU, duration, connection, and optional
battery metrics only. Do not include raw media URLs, receiver identifiers, LAN
IPs, credentials, local paths, or diagnostic dumps in issue comments.
