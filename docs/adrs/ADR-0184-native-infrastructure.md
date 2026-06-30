# ADR-0184: Native Infrastructure Layer

## Status
Accepted

## Context
Future iterations of AIRO will rely heavily on native code via `dart:ffi` to drive performance-critical execution across multiple runtimes (llama.cpp, Whisper, OCR preprocessing). If each engine implements its own C/C++ lifecycle management, memory allocation tracking, and library loading routines, the platform will suffer from code duplication, memory leaks, and fragmented error handling.

## Decision
We extract all native orchestration into a dedicated `platform_native` package. 
Engine wrappers (like `platform_engine_llama`) are only permitted to consume native behavior through `platform_native`.

### Key Patterns
1. **Dynamic Library Loading**: Centralizes FFI `DynamicLibrary.open` cross-platform resolution.
2. **Memory Management**: Enforces strict Arena-based allocation and manual pointer cleanup to prevent memory leaks in the Dart isolate.
3. **Thread Management**: Prevents individual engines from arbitrarily spawning unbounded native threads by bridging worker configurations.
4. **Thin Wrappers**: Native SDK engines (like `platform_engine_llama`) are prohibited from writing generic FFI lifecycle utilities. They must strictly bind the specific capabilities (like GGUF initialization) exposed by their backend.

## Consequences
- **Positive**: Hardens the application against memory leaks. A single package owns crash isolation and native lifecycle. Subsequent native engines (Whisper, ONNX) will be much faster to implement.
- **Negative**: Adds a layer of indirection (NativeRuntime) between the engine code and the raw C-API.
