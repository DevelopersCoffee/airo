# ADR-0178: Hardware Abstraction Layer

## Status
Accepted

## Context
AIRO needs to understand the device it is running on to recommend and execute models correctly. Different operating systems and devices expose hardware capabilities in different ways. Furthermore, hardware constraints dictate model compatibility (e.g., RAM size limits parameter count, NPU presence allows efficient inference).

## Decision
We will introduce `platform_hardware`, an isolated package responsible solely for detecting and normalizing hardware capabilities into a platform-agnostic `HardwareProfile`. 

### Key Patterns:
1. **Normalized Hardware Model**: We expose `HardwareProfile` as the single source of truth across all platforms.
2. **Detector Composition**: The detection pipeline is composed of isolated, independent detectors (CPU, GPU, NPU, Memory, OS).
3. **Detection Confidence**: Every detected capability is paired with a `DetectionConfidence` score (Exact, Derived, Estimated, Unknown) since some OSs (like iOS) aggressively hide raw hardware specs.
4. **Explanation-First Compatibility**: Rather than a simple boolean, `CompatibilityEvaluator` returns a `CompatibilityReport` explaining exactly *why* a `ModelDescriptor` is or is not compatible with the `HardwareProfile`.

## Consequences
- **Positive**: Centralizes OS-specific detection logic, keeping runtime and inference layers clean. `platform_models` can now provide intelligent, explainable model recommendations based on RAM and accelerator constraints.
- **Negative**: Adds overhead for maintaining detector implementations for each supported operating system.
