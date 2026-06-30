# ADR-0185: Hardware Delegate Abstraction

## Status
Accepted

## Context
LiteRT, ONNX Runtime, MNN, and Core ML often rely on hardware-specific acceleration (e.g. GPU, NPU, NNAPI, XNNPACK). If each engine builds its own hardware discovery and fallback logic, the platform loses the ability to globally control performance vs. efficiency trade-offs, and bug fixes to hardware profiles must be duplicated across every engine.

## Decision
We mandate a central `platform_delegates` package that abstracts accelerator discovery and selection.
Inference engines (like `platform_engine_litert`) DO NOT decide which hardware backend to execute on. Instead, they receive a `DelegateSelection` from the orchestrator and merely map it to their specific C-API bindings.

### Key Patterns
1. **Delegate Types**: CPU, GPU, NPU, NNAPI, XNNPACK, Metal, Core ML, Qualcomm HTP, OpenCL, Vulkan. These are accelerators, not engines.
2. **Delegate Selector**: Takes `HardwareProfile`, `EngineCapabilities`, and User Preferences to compute a fallback chain (e.g. HTP -> GPU -> NNAPI -> CPU).
3. **Engine Consumption**: `createSession` now involves mapping a selected platform delegate to a native backend binding.

## Consequences
- **Positive**: The orchestrator can globally throttle performance or bypass failing NPUs uniformly across all engines. Engine code sizes shrink significantly as they shed hardware-discovery logic.
- **Negative**: Engines must carefully maintain their binding maps from `DelegateTypes` to their internal flags.
