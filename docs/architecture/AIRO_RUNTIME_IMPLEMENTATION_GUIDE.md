# Airo Runtime Implementation Guide

Status: Accepted
Version: 1
Related: ADR-0001, `AIRO_RUNTIME_CONFORMANCE_SPEC.md`

This guide is normative for Architecture Freeze v1. Amendments require an
approved ADR or an explicitly reviewed versioned update.

This guide explains where runtime engineering belongs and how contributors add
backends, platforms, models, and capabilities without weakening the Airo Mind
architecture.

## Ownership map

| Responsibility | Crate | Rule |
| --- | --- | --- |
| Shared IDs, errors, units, versions | `airo_core` | No platform or backend imports |
| Inference IR and request contracts | `airo_core` | Typed, versioned, immutable values |
| Model manifests and lifecycle | `airo_models` | Metadata only; no runtime logic |
| Runtime/capability/hardware registries | `airo_registry` | Registration and certification only |
| Platform probes, storage, downloads | `airo_platform` | Platform APIs stay here |
| Resource planners and scoring | `airo_planner` | Pure policy; no I/O or backend imports |
| Sessions and backend orchestration | `airo_runtime` | Executes IR through registered adapters |
| Aggregate telemetry and history | `airo_telemetry` | Non-blocking, bounded aggregates |
| Mock and backend conformance | `airo_conformance` | Shared behavior specification |
| Flutter presentation | Flutter app | Uses generated Rust bindings only |

## Stable public APIs

The following are stable at version 1:

- Runtime API v1
- Planner API v1
- Model Manifest v1
- Telemetry v1
- Inference IR v1
- Execution Plan v1

Changes to these contracts require an explicit version bump and migration. All
other internal APIs may evolve while the implementation is being built.

## Adding a backend

1. Implement the typed runtime/session contract in a backend adapter.
2. Declare Runtime API version, backend version, conformance version, lifecycle,
   capabilities, accelerators, and supported manifest formats.
3. Register through `RuntimeRegistry`; do not add planner branches.
4. Pass the complete conformance suite using `MockRuntime` as the behavioral
   reference.
5. Add compatibility metadata and execution diagnostics.

The planner must not import the backend. Flutter must not import backend APIs.

## Adding a platform

1. Implement `PlatformProbe` and normalized `MemoryProfile` facts.
2. Implement platform storage and downloader adapters.
3. Register supported runtimes and accelerators for the platform.
4. Add platform fitness tests and conformance evidence.

Platform adapters may call OS APIs. They must not select models, runtimes, or
planner policy.

## Adding a model or capability

Models are added through a versioned manifest and registry entry only. A model
manifest describes capabilities, architecture, quantization, context, memory,
formats, runtimes, and accelerators; it contains no execution code.

Capabilities are added to the capability graph with stable `CapabilityId`s,
parent/child relationships, and planner matching tests. No planner branch may
refer to a vendor or model name.

## Runtime compatibility matrix

This is the documentation source of truth and must remain aligned with registry
and CI metadata:

| Runtime | Android | iOS | iPadOS | macOS | Windows | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LiteRT | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| MLX | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| llama.cpp | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| ONNX | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| WebGPU backend | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

## MockRuntime

`MockRuntime` is a first-class reference implementation, not disposable test
scaffolding. It must deterministically simulate success, OOM, timeout,
cancellation, thermal throttling, corrupted manifests, unsupported features,
partial streaming, backend crashes, restart, and recovery.

Tests must be able to inject each condition without a physical device or native
runtime. Mock behavior is the contract reference for production backend tests.

## Required tests and CI gates

Every runtime or planner change must pass:

- ADR architecture fitness/dependency-boundary tests;
- contract and conformance suites;
- planner determinism tests;
- MockRuntime lifecycle, request, failure, and recovery tests;
- manifest/schema migration tests;
- compatibility-matrix and registry certification checks;
- `git diff --check` and focused package analysis/tests.

No public API change may merge without a contract version bump and migration
coverage. Telemetry and execution traces must remain non-blocking.

## Phase 1 definition of done

- Planner executes entirely through versioned runtime contracts.
- MockRuntime passes 100% of the conformance suite.
- LiteRT passes the same suite through its adapter.
- Flutter has no direct LiteRT dependency.
- Android-specific APIs exist only in platform adapters.
- A second backend can be registered without planner changes.
- Planner determinism, recovery, diagnostics, and architecture fitness are
  enforced in CI.

Do not expand the architecture during Phase 1 unless implementation exposes a
concrete contract gap; record such changes in a new ADR.
