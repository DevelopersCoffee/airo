# Release Performance Benchmark Report

- Date: 2026-07-28
- Release / branch: `codex/milestone-2-reliability-20260728` at
  `eefc35b76306943358ff509762e347593637180f`
- Device class: Android phone emulator, `sdk_gphone64_arm64`
- OS / build: Android 16 / API 36,
  `google/sdk_gphone64_arm64/emu64a:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys`
- Operator: Codex

## Execution Environment

- Host-only checks run: `make benchmark-gemini-warmup` (3/3 passed)
- Physical Android device used: No
- Android emulator used: `airo_api36`, serial `emulator-5554`
- Notes: Normal full-profile debug APK, version `0.0.5+7`, SHA-256
  `e6ac31486931a76dc297addee41f58f8f8ce096de66022c1ecf7590b5adb1194`.
  The Android integration test
  `gemini_nano_warmup_mobile_run_test.dart` also passed 1/1, but it mocks the
  platform channel and therefore is contract evidence, not a real model timing.
  Issue #520 does not currently opt into `AIRO_ALLOW_ANDROID_EMULATOR=true`;
  all emulator measurements in this report are exploratory and are not release
  or closure evidence.

## Required Metrics

| Metric | Scenario | Environment | Command / source | Result | Pass/Fail | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Cold start | Full app launch from terminated state | API 36 emulator | `adb -s emulator-5554 shell am start -W ...` | `TotalTime=6397 ms`, `WaitTime=6621 ms` | Captured | Informational; no release budget is defined and a physical target is preferred. |
| Warm start | Relaunch after recent open | API 36 emulator | `adb -s emulator-5554 shell am start -W ...` | `WaitTime=127 ms` | Captured | Existing task brought to foreground; informational only. |
| Model loading time | Gemini Nano warm path | Host and API 36 emulator | Host make target and Android integration contract test | Host 3/3; Android 1/1 | Partial | Both paths mock native availability; no real Gemini Nano timing captured. |
| First transcript latency | Meeting flow sample | Physical Android | Manual scripted run | Not run | Blocked | Requires a physical-device meeting flow. |
| Summary generation time | Meeting flow sample | Physical Android | Manual timed run | Not run | Blocked | Real provider is still unavailable under #506. |
| Embedding speed | Representative local AI task | Physical Android | Manual timed run | Not run | Blocked | Real embedding provider #355 remains open. |
| Speaker detection latency | Meeting flow sample | Physical Android | Manual timed run | Not run | Blocked | Speaker provider #267/#504 remains open. |
| Memory usage | App steady state after launch | API 36 emulator | `adb -s emulator-5554 shell dumpsys meminfo io.airo.app` | PSS `417822 KB`; RSS `529320 KB` | Captured | Debug build, emulator-only snapshot. |
| CPU usage | App idle after launch | API 36 emulator | `adb -s emulator-5554 shell top -b -n 1 -p 5739` | `0.0%` point sample | Captured | Point sample is not an active-workload benchmark. |
| GPU/NPU utilization | On-device AI workload | Android | Vendor tooling / profiler | Not run | Blocked | No real AI workload/provider on the emulator. |
| Battery consumption | Full benchmark pass | Physical Android | `adb shell dumpsys batterystats` or Battery Historian | Not run | Blocked | Emulator battery data is not release evidence. |
| Storage growth | Before vs after model/download run | API 36 emulator | `adb shell run-as io.airo.app du -sk ...` | Baseline: files 40 KB; cache 60 KB; no_backup 176 KB; databases 8 KB | Partial | No real model/download run, so growth is not measured. |

## Release Decision

- Blocking regressions: No threshold decision is possible from this partial
  emulator pass. Cold-start and memory numbers are informational.
- Follow-up issues: #520 remains open; #355, #267/#504, and #506 block real AI
  workload metrics. Physical-device transcript, battery, and accelerator
  evidence remains required.
- Attached artifacts: This report.

## Raw Notes

- The app built, installed, and launched successfully on Android 16/API 36.
- No physical device was modified during this pass.
- Logcat reported 280 and 424 skipped frames during cold startup; this should
  be investigated on a profile/release build before a performance decision.
