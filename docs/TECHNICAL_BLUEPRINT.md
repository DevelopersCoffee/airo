# AIRO Technical Blueprint

## Repository Structure, Package Boundaries & Ownership

Version: 1.0

---

# 1. Purpose

This document defines the physical structure of the AIRO repository.

It specifies package boundaries, ownership, dependency rules, public APIs, and module responsibilities.

The repository layout is treated as an architectural artifact.

---

# 2. Repository Principles

The repository is organized by **capability**, not by framework or feature.

Each package has:

* A single responsibility
* A documented public API
* Clear ownership
* Explicit dependencies
* Independent tests

No package should exist solely to support one screen.

---

# 3. Top-Level Layout

```text
airo/
├── apps/
│   ├── mobile/
│   ├── desktop/                 # Future
│   └── benchmark/
│
├── packages/
│   ├── ui/
│   ├── design_system/
│   ├── chat/
│   ├── runtime/
│   ├── memory/
│   ├── knowledge/
│   ├── meetings/
│   ├── workflow/
│   ├── search/
│   ├── downloads/
│   ├── storage/
│   ├── settings/
│   ├── plugins/
│   ├── security/
│   ├── diagnostics/
│   └── notifications/
│
├── platform/
│   ├── core/
│   ├── bootstrap/
│   ├── dependency_injection/
│   ├── lifecycle/
│   ├── jobs/
│   └── configuration/
│
├── plugins/
│
├── tools/
│
├── scripts/
│
├── docs/
│
├── benchmarks/
│
├── examples/
│
└── assets/
```

---

# 4. Dependency Rules

Dependencies flow inward toward shared platforms.

```text
Apps
  ↓
Feature Packages
  ↓
Platform Packages
  ↓
Infrastructure
```

Feature packages must never depend on each other directly when a shared platform package can provide the capability.

---

# 5. Package Responsibilities

### ui

* Shared widgets
* Layout primitives
* Navigation components

### design_system

* Typography
* Color tokens
* Spacing
* Icons
* Motion

### chat

* Conversation orchestration
* Streaming renderer
* Attachments

### runtime

* Model routing
* Inference
* TTS
* Whisper
* Embeddings

### memory

* Memory lifecycle
* Retrieval
* Review

### knowledge

* OCR
* Indexing
* Citations
* Knowledge graph

### meetings

* Recording
* Transcription
* Summaries

### workflow

* Scheduler
* Automation
* Event processing

### search

* Semantic search
* Full-text search
* Ranking

### downloads

* Download manager
* Verification
* Resume
* Background execution

### storage

* SQLite
* Repository interfaces
* Migrations

### settings

* Preferences
* Feature flags
* Configuration

### plugins

* SDK
* Registry
* Loading
* Sandboxing

### security

* Encryption
* Permissions
* Audit logging

### diagnostics

* Logging
* Metrics
* Health checks

### notifications

* Local notifications
* Background alerts

---

# 6. Package Ownership

Every package has:

* Technical owner
* Public API
* Test suite
* Documentation
* ADR references

Ownership is explicit.

---

# 7. Public API Policy

Only documented APIs are public.

Internal implementation details remain private.

Breaking API changes require:

* ADR update
* Migration guide
* Semantic version increment

---

# 8. Shared Models

Shared data models belong in dedicated packages.

Avoid feature-specific copies of:

* Conversation
* Workspace
* Memory
* Document
* Task
* Meeting

One model, many consumers.

---

# 9. Code Generation

Generated code is isolated.

Example:

```text
generated/
```

Generated files are never manually edited.

---

# 10. Assets

Assets are organized by type:

```text
assets/
├── icons/
├── fonts/
├── illustrations/
├── animations/
├── onboarding/
├── prompts/
└── templates/
```

No feature-owned asset directories.

---

# 11. Benchmarks

Benchmarks live outside production packages.

They measure:

* Startup
* Inference
* Search
* Downloads
* Memory usage
* Rendering

---

# 12. Examples

Reusable examples demonstrate:

* Plugin development
* Workflow creation
* Runtime integration
* UI composition

Examples act as living documentation.

---

# 13. Internal Layering

Within each package:

```text
lib/
├── api/
├── application/
├── domain/
├── infrastructure/
├── presentation/   # UI packages only
└── testing/
```

This keeps responsibilities clear.

---

# 14. Package Evolution

Packages may evolve independently as long as public APIs remain stable.

New capabilities should extend existing packages before introducing new ones.

---

# 15. Repository Governance

Any proposal to add:

* A new top-level package
* A new platform service
* A new infrastructure layer

requires architecture review and an ADR.

---

# 16. Blueprint Goals

The repository should:

* Encourage reuse
* Minimize coupling
* Enable parallel development
* Support AI coding agents
* Scale to hundreds of capabilities without becoming a monolith

The Technical Blueprint is the structural map of the AIRO codebase. It ensures that implementation follows the architectural intent, keeping the repository modular, discoverable, and maintainable as the platform grows.
