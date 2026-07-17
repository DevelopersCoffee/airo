---
layout: default
title: iPad Air 4 Playback Soak Test Report
---

# Airo TV Playback Soak Test Report (iPad Air 4)

This report documents the memory and performance metrics gathered during a continuous playback soak test of the Airo TV app running on a physical **iPad Air 4**.

## Test Summary

| Metric | Value | Budget / Target | Status |
| --- | --- | --- | --- |
| **Device Platform** | iOS (iPad Air 4, iOS 26.5.2) | iPad Air 4 | - |
| **Test Duration** | 34.0 minutes | 30 minutes | ✅ Complete |
| **Peak Process RAM (RSS)** | **212.98 MiB** | **≤ 250.00 MiB** | ✅ Pass |
| **Average RAM (RSS)** | 205.60 MiB | - | - |
| **Peak Dart Heap** | 38.50 MiB | ≤ 60.00 MiB (Target) | ✅ Pass |
| **Average Dart Heap** | 30.64 MiB | - | - |
| **Dart Heap Drift** | -2.87 MiB | ≤ 5.00 MiB / hr (Target) | ✅ Pass |
| **LeakTracker Leaks** | **0** | **0** | ✅ Pass |
| **Overall Verdict** | **PASSED** | - | **✅ PASS** |

## Verdict & Performance Details

The Airo TV app running on iPad Air 4 **PASSED** the memory budget requirements. The Peak RSS (physical RAM footprint) during the entire playback soak test was **212.98 MiB**, which remains well under the allocated budget of **250 MiB**.

### Memory Growth & Stability
- **Dart heap footprint** remained highly stable, with a drift of **-2.87 MiB** from the start to the end of the test. This indicates excellent garbage collection and no signs of progressive Dart memory leaks.
- **LeakTracker** integration reports **0 leaks**, verifying that all disposed widgets and controllers were successfully garbage collected.

## Memory Timeline (Sampled every 5 minutes)

| Time | RSS (MiB) | Peak RSS (MiB) | Dart Heap (MiB) |
| --- | --- | --- | --- |
| 0m 0s | 193.91 | 212.98 | 31.83 |
| 5m 0s | 202.69 | 212.98 | 33.54 |
| 10m 0s | 203.25 | 212.98 | 34.27 |
| 15m 0s | 204.20 | 212.98 | 34.52 |
| 20m 1s | 207.05 | 212.98 | 34.79 |
| 25m 1s | 208.31 | 212.98 | 35.02 |
| 30m 1s | 210.36 | 212.98 | 35.26 |
| 34m 2s | 211.02 | 212.98 | 32.24 |
