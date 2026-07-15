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

## Airo TV Logo Scroll Report

After a physical Android TV or 1 GB profile logo-grid scroll run, write the
sanitized #773 evidence artifact with:

```bash
dart run tool/write_logo_scroll_report.dart \
  --report-id shield-tv-logo-scroll-10k \
  --scenario-id large-logo-grid-scroll \
  --playlist-channels 12000 \
  --visible-cells 24 \
  --duration-seconds 180 \
  --baseline-rss-mb 180 \
  --peak-rss-mb 242 \
  --steady-rss-mb 230 \
  --rss-plateau-delta-mb 8 \
  --image-cache-peak-mb 14 \
  --frame-jank-count 0 \
  --decode-jank-frame-count 0
```

The command evaluates the captured run against the constrained Android TV
memory budget and writes:

- `artifacts/performance/airo-tv-logo-scroll-report.json`
- `artifacts/performance/airo-tv-logo-scroll-report.md`

Reports contain aggregate channel counts, RSS, image-cache, and jank counts
only. Do not include raw playlist URLs, logo URLs, device serials, LAN IPs,
local paths, profile traces, or screenshots in issue comments.

## Airo TV D-pad Traversal Report

After a physical Android TV / Fire TV D-pad pass, write the sanitized #589
evidence artifact with:

```bash
dart run tool/write_dpad_traversal_report.dart \
  --report-id shield-tv-dpad-traversal \
  --device-profile shield-tv-physical \
  --viewport-profile android-tv-1080p \
  --required-actions 9 \
  --reachable-actions 9 \
  --channel-cards-traversed 12 \
  --help-opened true \
  --help-dismissed true \
  --focus-loss-count 0 \
  --overflow-count 0 \
  --render-error-count 0
```

The command evaluates the captured run and writes:

- `artifacts/performance/airo-tv-dpad-traversal-report.json`
- `artifacts/performance/airo-tv-dpad-traversal-report.md`

Reports contain aggregate D-pad reachability, focus-loss, overflow, and render
error counts only. Do not include device serials, receiver identifiers, raw
playlist URLs, logo URLs, LAN IPs, local paths, screenshots, or logcat dumps in
issue comments.

## Cast Channel Switch Report

After a physical sender-to-receiver active Cast channel-switch pass, write the
sanitized #590 evidence artifact with:

```bash
dart run tool/write_cast_channel_switch_report.dart \
  --report-id pixel9-bravia-switch-pass \
  --sender-profile pixel9-physical \
  --receiver-profile bravia-chromecast \
  --playlist-profile iptv-org-public \
  --attempted-switches 2 \
  --successful-switches 2 \
  --receiver-reconnects 0 \
  --stale-previous-statuses 0 \
  --previous-channel-errors 0 \
  --latest-error-matched-selected true \
  --local-playback-restarts 0 \
  --recovery-actions 0
```

The command evaluates active receiver channel switching and writes:

- `artifacts/performance/cast-channel-switch-report.json`
- `artifacts/performance/cast-channel-switch-report.md`

Reports contain aggregate switch, reconnect, stale-status, error-attribution,
local-playback, and recovery counts only. Do not include raw stream URLs,
receiver identifiers, LAN IPs, device serials, local paths, or logcat dumps in
issue comments.

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
