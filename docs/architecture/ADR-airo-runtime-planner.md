# ADR-0001: Airo Edge Intelligence Runtime Architecture

Status: Accepted
Date: 2026-07-29

## Status governance

This foundational ADR may transition from `Proposed` to `Accepted` to
`Superseded`. Future ADRs that change runtime boundaries, contract ownership, or
platform isolation must reference this document.

## Architecture Freeze v1

ADR-0001, the Runtime Conformance Specification, and the Runtime Implementation
Guide are normative artifacts. After this freeze, engineering work is
implementation-focused. Architectural changes are permitted only when an
implementation exposes a concrete limitation that cannot be resolved within the
existing contracts, and must be approved through a new ADR or reviewed
versioned amendment.

## Rationale

Airo Mind needs one deterministic policy layer that can select among runtimes,
models, accelerators, and resource constraints without coupling Flutter to any
specific implementation. Rust provides the cross-platform source of truth;
typed registries and adapters keep platform and backend variation replaceable.

## Alternatives considered

- Android-first LiteRT orchestration was rejected because it couples policy to
  one platform and prevents independent backend evolution.
- A Flutter-owned planner was rejected because it duplicates policy across
  clients and blocks desktop, CLI, and future service consumers.
- One universal inference backend was rejected because hardware and runtime
  capabilities differ materially across platforms.

## Non-goals

- Implementing a custom inference engine in this ADR.
- Promising mmap, dynamic KV, layer streaming, or tensor paging for LiteRT.
- Defining the `.airopack` artifact format.
- Choosing a vendor-specific fallback model.
- Adding cloud inference or telemetry upload policy.

## Migration impact

The existing Flutter model catalog/download flow remains usable behind model and
storage adapters. The existing LiteRT MethodChannel becomes an implementation
detail of the first backend adapter. Feature screens migrate to generated Rust
contracts incrementally; no product screen should import runtime-specific APIs.

## Decision

Airo's runtime policy is owned by a platform-neutral Rust planner core. Flutter is a presentation
client through generated `flutter_rust_bridge` bindings. Runtime backends execute
plans but do not select policy. Models expose metadata through manifests, and
platform adapters expose hardware facts that Rust cannot obtain portably.

The boundary rule is:

> The planner owns policy. Backends own execution. Models own metadata. Platform
> adapters own hardware access. Flutter owns presentation.

## Contract versioning and identifiers

Core contracts are versioned from their first release: Runtime API v1, Planner
API v1, Model Manifest v1, and Telemetry v1. Runtime, backend, accelerator,
capability, error, and lifecycle values use stable typed identifiers such as
`RuntimeId` and `CapabilityId`. Wire formats use stable IDs and explicit
migrations rather than display names or string literals.

## Module boundaries

The Rust workspace is split into these crates:

- `airo_core`: shared identifiers, errors, value types, and time/units.
- `airo_models`: versioned model manifests and capability metadata.
- `airo_registry`: runtime, capability, hardware, and installed-model registries.
- `airo_platform`: platform probes and adapters.
- `airo_planner`: device profiling, scoring, execution plans, and recovery.
- `airo_runtime`: backend lifecycle and request orchestration.
- `airo_telemetry`: aggregate execution history and planner feedback.
- `airo_conformance`: backend behavior and recovery suites.

Backends register themselves with `RuntimeRegistry`; the planner never imports a
concrete backend. LiteRT is the first backend, not the platform foundation.

No planner, model, registry, contract, or backend API may reference Android,
iOS, LiteRT, MLX, Metal, Vulkan, or another platform/runtime-specific API.
Concrete platform adapters and backend implementations are the only permitted
locations for those dependencies; they expose normalized facts and typed
capabilities through registries.

## Platform-neutral adapters

`PlatformProbe` supplies normalized facts for memory, CPU, GPU/accelerator,
storage, thermal state, battery state, and foreground/background pressure.
Android, iOS/iPadOS, macOS, Windows, Linux, and Web provide separate adapters.
The planner consumes `MemoryProfile` (`total`, `available`, `pressure`, and
`reclaimable`) rather than an operating-system-specific memory API.

Model storage and downloads are also abstracted:

- `ModelStorage`: install, remove, verify, and open model artifacts;
- `ModelDownloader`: enqueue, pause, resume, cancel, and observe downloads.

Platform implementations may use Android background workers, `NSURLSession`,
desktop transports, or Web APIs, but those details never enter planner policy.

Execution plans select a platform-neutral `ComputeAccelerator` such as CPU,
Vulkan, Metal, Core ML, Apple Neural Engine, NNAPI, OpenCL, or CUDA. The
accelerator is resolved by capability registries; the planner does not branch on
operating-system names.

## Inference IR

The planner produces a typed, backend-neutral Inference IR rather than a
runtime-specific execution plan. The pipeline is:

`InferenceRequest -> Planner -> Inference IR -> Backend adapter`.

The IR contains requested model capability, selected runtime and backend,
context/output limits, decoding parameters, safety limits, execution priority,
and negotiated features. Adapters translate the IR into LiteRT, llama.cpp,
ONNX, MLX, or other runtime APIs.

The planner is pure and compiler-like: for identical `DeviceProfile`, model and
runtime manifests, registry state, and `PlannerConfig`, it produces identical
IR. It performs no I/O, platform calls, hidden-state reads, or telemetry writes.

## Resource planning

`RuntimePlanner` orchestrates independent resource planners:

- `MemoryPlanner`
- `ComputePlanner`
- `StoragePlanner`
- `ThermalPlanner`
- `BatteryPlanner`

This keeps resource policy composable and prevents a monolithic decision engine.

## Runtime sessions and scheduling

Inference runs inside a reusable `RuntimeSession` with initialize, multiple
generations, cancellation, KV reuse, recovery, and shutdown. A typed inference
scheduler orders interactive chat ahead of background summaries, embeddings, and
model downloads; requests do not use an uncontrolled first-request-wins model.

Backends share the lifecycle state machine:

`Created -> Initializing -> Ready -> Busy -> Recovering -> Ready -> ShuttingDown -> Stopped`.

Any state may transition to `Failed` with a typed error code and recovery detail.

## Model lifecycle

Model registry state is explicit and persisted:

`NotInstalled`, `Downloading`, `Installing`, `Verifying`, `Ready`, `Loading`,
`Loaded`, `Running`, `Recovering`, `Updating`, `Corrupted`, and `Uninstalling`.

## Capability graph and negotiation

Capabilities are represented as a graph rather than a flat list. For example,
`Chat` contains `General`, `Coding`, `Reasoning`, and `Translation`; `Vision`
contains `OCR`, `Caption`, and `Detection`. The planner matches requests against
this graph and installed model manifests.

Before execution, the planner negotiates typed backend features including
vision, streaming, tool calling, grammar, JSON mode, cancellation, and other
capabilities. Unknown is distinct from unsupported.

## Plugin boundaries

Planner, backend, platform, model, and telemetry integrations are replaceable
plugins behind typed registries. Backends and platform plugins are discovered via
registries; the planner does not compile against concrete implementations.

## Flutter boundary

Planner and runtime contracts are Rust-first and exposed through
`flutter_rust_bridge`. Flutter must not import runtime-specific APIs or inspect
exception strings.

Method channels remain only for platform facts unavailable to portable Rust,
including Android `ActivityManager`, thermal, battery, storage, NPU, and iOS
device APIs.

## Versioned schemas

Persistence uses versioned JSON schemas from the beginning:

- `device_profile_v1.json`
- `planner_state_v1.json`
- `telemetry_v1.json`
- `runtime_cache_v1.json`
- independent model, device, and runtime manifests

Schemas are versioned independently from download artifacts.

## Planner inputs and outputs

`DeviceProfile` separates static facts (CPU, GPU, NPU, RAM, storage, OS) from
dynamic facts (available RAM, battery, thermal state, charging, pressure, and
foreground state).

`ExecutionPlan` is immutable and contains runtime, backend, thread count,
context, batch, warmup strategy, output limit, temperature, top-k, and top-p.

`RuntimeCapabilities` uses `Supported`, `Unsupported`, or `Unknown` states rather
than booleans.

Runtime health states are `Ready`, `Initializing`, `Recovering`, `LowMemory`,
`ThermallyLimited`, `Unavailable`, and `Failed`.

Recovery is ordered and data-driven:

1. preflight;
2. memory cleanup;
3. recheck;
4. backend retry;
5. reduced context/output/batch;
6. retry;
7. switch to the highest-scoring installed model matching the requested
   capability;
8. return a structured failure.

The planner never names or hardcodes models such as Gemma or Qwen.

## Profiling and learning

Stage A performs immediate static/dynamic detection without benchmarks. Stage B
runs storage/runtime/thermal benchmarks only while idle or charging. Stage C
continuously learns from aggregate execution history.

Telemetry is aggregated at write time. It stores averages, P95 latency, peak
memory, failures, throughput, and success rates rather than unbounded raw events.

Runtime selection uses a score combining speed, memory, battery, thermals, and
reliability. Telemetry never blocks inference.

## Conformance requirements

Every backend must pass the same suites before registration:

- lifecycle: initialize, shutdown, restart, health;
- requests: streaming, cancellation, concurrency;
- planner: deterministic selection, memory/context reduction, retry policy;
- failures: OOM, unavailable runtime, corrupt model, invalid manifest, timeout;
- recovery: retry, fallback selection, state cleanup;
- performance: startup, first-token, and sustained throughput metrics.

Backends are certified before registration. Each declares its supported Runtime
API version, capability matrix, conformance-suite version, and backend version.
`RuntimeRegistry` rejects incompatible or uncertified registrations.

## Execution traces

Debug builds expose a structured execution trace with planner decisions,
selected runtime and accelerator, memory checks, recovery attempts, warmup, and
generation outcomes. Diagnostics use typed fields and error codes, never parsed
exception strings. Tracing is observable but never blocks inference.

Adding a runtime must require zero planner changes. Adding a model must require
only a manifest and registration data.

## Architectural invariants

1. Flutter never contains inference logic.
2. The planner never imports runtime implementations.
3. Backends never contain product policy.
4. Models never contain runtime logic.
5. Platform adapters never make planner decisions.
6. All runtime communication uses typed contracts, never exception-string parsing.
7. Every backend passes the same conformance suite.
8. Adding a backend requires zero planner changes.
9. Adding a model requires only a manifest.
10. Adding hardware support requires only a platform adapter.
11. Platform/runtime-specific APIs may exist only inside their concrete adapters;
    planner, model, registry, contract, and backend interfaces remain neutral.

## Consequences

This creates a Rust-first cross-platform contract and keeps LiteRT replaceable.
It does not claim mmap, dynamic KV, layer streaming, or tensor paging for LiteRT;
those capabilities are advertised only when a backend actually supports them.
The first implementation remains an adapter around the existing LiteRT Android
engine while future controllable backends can be added without changing Flutter
feature code.
