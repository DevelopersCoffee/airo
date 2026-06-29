# AIRO Architecture Specification

# Part 2 — AI Runtime Platform Architecture

Version: 1.0 (Draft)

---

# 1. Objective

The AI Runtime Platform is the heart of AIRO.

Its responsibility is **not** to perform inference directly. Instead, it manages and orchestrates every AI engine running on the device.

The runtime platform should provide:

* Stable execution
* Hardware-aware optimization
* Memory management
* Model lifecycle management
* Background scheduling
* Streaming
* Tool execution
* Multi-model orchestration

Every AI feature in AIRO must use this platform.

---

# 2. Why a Runtime Platform?

A typical AI application tightly couples features with inference engines.

Example:

```
Meeting Screen
    ↓
Whisper
```

```
Chat Screen
    ↓
Llama.cpp
```

```
OCR Screen
    ↓
OCR Engine
```

This architecture becomes difficult to maintain.

Instead:

```
Meeting

↓

Runtime Platform

↓

Inference Engine
```

Every feature uses the same runtime.

---

# 3. Runtime Responsibilities

The runtime owns:

* Model loading
* Model unloading
* Warm models
* Backend selection
* Memory budgeting
* Context allocation
* Context cleanup
* Streaming
* Tool execution
* Workflow execution
* Resource scheduling
* Runtime diagnostics

---

# 4. Runtime Architecture

```
Flutter UI
      │
      ▼
Application Services
      │
      ▼
Runtime Platform
 ├── Runtime Manager
 ├── Scheduler
 ├── Model Registry
 ├── Capability Registry
 ├── Backend Selector
 ├── Memory Manager
 ├── Session Manager
 ├── Workflow Engine
 ├── Tool Engine
 ├── Streaming Engine
 └── Diagnostics
      │
      ▼
Inference Engines
 ├── Whisper
 ├── llama.cpp
 ├── LiteRT
 ├── MNN
 ├── ONNX Runtime
 ├── MediaPipe
 └── OCR Engines
```

---

# 5. Runtime Manager

The Runtime Manager is the entry point for every AI request.

Responsibilities:

* Start runtime
* Stop runtime
* Load model
* Unload model
* Switch models
* Preload models
* Maintain residency
* Recover after failure

No feature may directly instantiate an inference engine.

---

# 6. Model Registry

The registry stores metadata for every installed model.

Example:

```yaml
id: whisper-large-v3

family: whisper

capabilities:
  transcription: true
  streaming: true
  diarization: false

runtime:
  engine: whisper.cpp

hardware:
  min_ram: 6GB
  gpu: optional
```

The registry is the source of truth.

---

# 7. Capability Registry

Capabilities are discovered dynamically.

Supported capabilities include:

* Chat
* Vision
* OCR
* Audio
* Embeddings
* Translation
* Thinking
* Streaming
* Tool Calling
* Function Calling
* JSON Output
* Structured Output

The UI never checks model names.

Instead:

```
supportsVision

supportsAudio

supportsStreaming

supportsThinking
```

---

# 8. Backend Selector

The selector determines where inference executes.

Supported backends:

Android

* CPU
* Vulkan
* OpenCL
* NNAPI
* Qualcomm HTP

iOS

* CPU
* Metal
* Core ML
* Apple Neural Engine

Future

* CUDA
* DirectML
* ROCm

Selection order:

```
Hardware Detection

↓

Compatibility Check

↓

Performance Benchmark

↓

Choose Backend

↓

Cache Decision
```

---

# 9. Runtime Profiles

Profiles simplify configuration.

## Performance

* Maximum GPU
* Large context
* Large KV cache

---

## Balanced

Default profile.

---

## Battery Saver

* CPU preferred
* Small context
* Reduced threads

---

## Low Memory

* Lightweight model
* Small context
* Cache cleanup enabled

Profiles may switch automatically.

---

# 10. Session Manager

Sessions persist runtime state.

Each session owns:

* Conversation
* KV cache
* Context
* Tool state
* Memory
* Streaming state

Sessions can be resumed.

---

# 11. Model Residency Manager

Loading models repeatedly wastes time.

Maintain:

* Warm models
* Recently used models
* Memory budget
* Startup cost

Eviction policy considers:

* Last use
* Memory footprint
* Load time
* User behavior

---

# 12. Memory Manager

Continuously monitor:

* Heap
* Native memory
* GPU memory
* KV cache
* Embedding cache

Actions:

* Clear caches
* Shrink context
* Pause background jobs
* Evict models
* Recommend smaller models

Memory pressure should never crash the application.

---

# 13. Scheduler

Every AI operation becomes a scheduled job.

Examples:

Critical

* Live transcription

High

* Meeting summary

Medium

* Embedding generation

Low

* Search indexing

Idle

* Model warming

The scheduler prevents resource contention.

---

# 14. Streaming Engine

Streaming should support:

* Tokens
* Audio
* Tool responses
* Search
* OCR
* Downloads

Responsibilities:

* Incremental updates
* Backpressure
* Cancellation
* Resume
* Flow control

---

# 15. Workflow Engine

Instead of implementing feature logic inside screens:

Create reusable workflows.

Meeting Workflow

```
Audio

↓

Whisper

↓

Speaker Detection

↓

Embeddings

↓

Summary

↓

Knowledge Index

↓

Task Extraction
```

Document Workflow

```
Import

↓

OCR

↓

Embeddings

↓

Knowledge

↓

Search
```

---

# 16. Runtime Diagnostics

Track:

* Active model
* Tokens/sec
* Memory
* Backend
* Context length
* Cache usage
* Scheduler queue
* Download queue
* Battery usage

Diagnostics should help users and developers understand runtime behavior.

---

# 17. Failure Recovery

The runtime should recover automatically from:

* Model load failure
* OOM
* Backend failure
* Interrupted inference
* Native crash
* Context corruption

Recovery order:

```
Retry

↓

Fallback Backend

↓

Smaller Model

↓

Graceful Failure
```

---

# 18. Runtime Lifecycle

```
Install Model

↓

Register Metadata

↓

Capability Discovery

↓

Load Model

↓

Warm Runtime

↓

Create Session

↓

Inference

↓

Cache Session

↓

Evict or Persist
```

---

# 19. Platform Components

Core services:

* RuntimeManager
* ModelRegistry
* CapabilityRegistry
* BackendSelector
* RuntimeProfileManager
* SessionManager
* ResidencyManager
* MemoryManager
* Scheduler
* WorkflowEngine
* StreamingEngine
* DiagnosticsService

---

# 20. Architecture Decision Records

## ADR-005 — Central Runtime Platform

Status: Accepted

Decision

All AI requests must pass through a single Runtime Platform.

Reason

Provides consistent lifecycle management, diagnostics, scheduling, and optimization.

---

## ADR-006 — Capability-Driven Execution

Status: Accepted

Decision

Runtime behavior is determined by capabilities rather than model families.

Reason

Simplifies support for future models and reduces feature-specific logic.

---

## ADR-007 — Adaptive Backend Selection

Status: Accepted

Decision

Backend selection is automatic based on hardware, model compatibility, and performance.

Reason

Maximizes performance while avoiding unsupported configurations.

---

## ADR-008 — Managed Model Residency

Status: Accepted

Decision

Models remain resident based on usage patterns and memory availability.

Reason

Reduces startup latency and improves user experience.

---

## ADR-009 — Runtime Scheduling

Status: Accepted

Decision

Every AI task is scheduled with explicit priority and resource awareness.

Reason

Prevents contention between live transcription, summarization, indexing, and downloads.

---

## ADR-010 — Graceful Degradation

Status: Accepted

Decision

The runtime must always attempt recovery before reporting failure.

Recovery sequence:

* Retry
* Backend fallback
* Context reduction
* Model downgrade
* User-visible error

Reason

Improves reliability across a wide range of devices.

---

# 21. Future Evolution

Phase 1

Single local runtime

↓

Phase 2

Multiple local runtimes

↓

Phase 3

Local + LAN providers

↓

Phase 4

Enterprise providers

↓

Phase 5

Distributed AI orchestration

The Runtime Platform is intentionally designed so future providers can be added without changing application logic. Every new engine, backend, or provider integrates through the same runtime interfaces, preserving a stable architecture as AIRO evolves.
