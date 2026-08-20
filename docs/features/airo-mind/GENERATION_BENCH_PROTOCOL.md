# Generation bench protocol

How Airo measures on-device generation speed. This is **not** a CUDA kernel
microbenchmark suite. Airo consumes llama.cpp / whisper.cpp; it does not
ship custom GPU kernels. The protocol adopts the Jan.ai practices that
still apply on phones, TVs, Macs, and a future Windows CUDA box.

Source of the methodology: [How we (try to) benchmark GPU kernels accurately](https://www.jan.ai/post/how-we-benchmark-kernels).

## What we measure

Each timed `generate()` already splits **prefill** (time to first token)
from **decode** (tokens/sec). The protocol:

1. Runs `warmup_iterations` (default 3) and **discards** them — first-load
   shader compile, mmap page-in, and graph build stay out of the number.
2. Runs `timed_iterations` (default 5) and reports the **median**.
3. Records accelerator, clock policy, thread count, and gpu-layer count
   with the number so a Metal reading cannot be compared to a CUDA one as
   if they were the same measurement.

Absolute tok/s is **not** a CI gate. GPU clocks are stochastic (Jan §6);
Mind CI keeps scaling-ratio gates, not wall-clock thresholds.

## Accelerators

| `AccelBackend` / `InferenceAccelBackend` / `GpuBackend` | Status |
|---|---|
| `none` | CPU |
| `metal` | macOS default for `airo_mind_llama` |
| `openCl` / `vulkan` | Config enum; Android path via `llama_flutter_android` |
| `cuda` | **Named seam for Windows testing.** `airo_mind_llama`'s `cuda` Cargo feature exists but does not yet enable `llama-cpp-2/cuda` (that needs nvcc on the Windows rig). Flip that feature when the toolkit is present; the protocol already accepts `Cuda`. |
| `auto` | Caller has not pinned a backend |

`GpuClockControl` (`unlocked` / `base` / `maxBoost`) is recorded so a later
`ncu --clock-control` pass on Windows CUDA does not mix locked-clock
numbers with user-experience (unlocked boost) numbers.

What we deliberately do **not** port from Jan: CUDA events, L2 cache
flush, dummy 4096² FP32 matmul, `ncu` as a CI tool. Those belong to custom
kernel work on a datacenter GPU, not llama.cpp decode on a phone.

## Code

- Rust: `airo_mind_core::bench` (`run_generation_bench`, `aggregate`)
- Dart: `packages/feature_mind/lib/src/model_bench/model_bench_protocol.dart`
- Product port: `ModelPort.benchmark()` on `RustMindRuntime` — runs the
  protocol when a `GenerationBenchRunner` is injected (production:
  `BridgeGenerationBenchRunner` over a loaded llama engine). Stays
  `MindPortUnavailable` rather than inventing tok/s when no runner is
  present. `ModelPort.thermal()` probes `DeviceCapabilityService`.
