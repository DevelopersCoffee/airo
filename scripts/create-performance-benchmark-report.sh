#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-performance-benchmark-report.sh [output-file]

Creates a markdown report template for release benchmark capture.

If no output file is supplied, the script writes to:
  artifacts/performance/YYYY-MM-DD-release-benchmark.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

report_date="$(date +%F)"
output_file="${1:-artifacts/performance/${report_date}-release-benchmark.md}"
mkdir -p "$(dirname "$output_file")"

cat > "$output_file" <<EOF
# Release Performance Benchmark Report

- Date: ${report_date}
- Release / branch:
- Device class:
- OS / build:
- Operator:

## Execution Environment

- Host-only checks run:
- Physical Android device used:
- Android emulator used:
- Notes:

## Required Metrics

| Metric | Scenario | Environment | Command / source | Result | Pass/Fail | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Cold start | Full app launch from terminated state | Physical Android preferred | \`adb shell am start -W ...\` | | | |
| Warm start | Relaunch after recent open | Physical Android preferred | \`adb shell am start -W ...\` | | | |
| Model loading time | Gemini Nano warm path | Host or Android | \`make benchmark-gemini-warmup\` | | | |
| First transcript latency | Meeting flow sample | Physical Android | Manual scripted run | | | |
| Summary generation time | Meeting flow sample | Physical Android | Manual scripted run | | | |
| Embedding speed | Representative local AI task | Physical Android | Manual scripted run | | | |
| Speaker detection latency | Meeting flow sample | Physical Android | Manual scripted run | | | |
| Memory usage | App steady state during benchmark | Android | \`adb shell dumpsys meminfo\` | | | |
| CPU usage | App active benchmark window | Android | Android Studio / \`top\` sample | | | |
| GPU/NPU utilization | On-device AI workload | Android | Vendor tooling / profiler | | | |
| Battery consumption | Full benchmark pass | Physical Android | \`adb shell dumpsys batterystats\` or Battery Historian | | | |
| Storage growth | Before vs after model/download run | Android | \`adb shell du\` / app storage screen | | | |

## Release Decision

- Blocking regressions:
- Follow-up issues:
- Attached artifacts:

## Raw Notes

- 
EOF

echo "Created benchmark report template: $output_file"
