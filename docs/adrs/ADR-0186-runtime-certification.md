# ADR-0186: Runtime Certification

## Status
Accepted

## Context
As the AIRO platform scales to support multiple backends (llama.cpp, LiteRT, Core ML, ONNX, etc.), the orchestration layer (`platform_runtime`) must remain completely unaware of the underlying engine's identity. If engines exhibit diverging behaviors (e.g., throwing different exceptions for unsupported modalities, structuring diagnostic payloads differently), the platform's stability will fracture.

## Decision
We establish **Runtime Certification & Cross-Engine Conformance** as a mandatory release gate. 
1. **Golden Scenarios**: Immutable sequences of operations (e.g., streaming cancellation, invalid artifacts) must be executed by all engines.
2. **Cross-Engine Assertion**: The `CrossEngineSuite` must run all engines side-by-side during CI, asserting identical behavioral state machines and exception types.
3. **API Freeze**: The Runtime, Engine SDK, Native, and Delegate interfaces are now formally frozen.

## Consequences
- **Positive**: The platform becomes a true "operating system for AI" where backends are plug-and-play implementations. Future subsystems (Chat, Memory, Tools) can rely entirely on stable `platform_runtime` contracts.
- **Negative**: Adds a high burden on new engine integrations, as they must conform perfectly to established semantic quirks and error boundaries.
