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
