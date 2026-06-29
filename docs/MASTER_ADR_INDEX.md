# AIRO Architecture Decision Catalog

## Master ADR Index

Version: 1.0

---

# Purpose

This document indexes every Architecture Decision Record (ADR) that governs AIRO.

Individual ADRs remain with their relevant design documents, but this catalog provides a single place to discover, review, and understand all architectural decisions.

Every new ADR must be added to this catalog.

---

# ADR Categories

## Product Architecture

|     ADR | Decision                                       | Status   |
| ------: | ---------------------------------------------- | -------- |
| ADR-001 | AIRO is an offline-first AI workspace          | Accepted |
| ADR-002 | Workspaces are the primary organizational unit | Accepted |
| ADR-003 | Platform capabilities are reusable by default  | Accepted |
| ADR-004 | Conversations are workspace scoped             | Accepted |
| ADR-005 | Features build on shared platforms             | Accepted |

---

## Runtime Architecture

|     ADR | Decision                         | Status   |
| ------: | -------------------------------- | -------- |
| ADR-020 | Runtime abstraction layer        | Accepted |
| ADR-021 | Multi-model routing              | Accepted |
| ADR-022 | Streaming-first inference        | Accepted |
| ADR-023 | Hardware-aware runtime selection | Accepted |
| ADR-024 | Local-first model execution      | Accepted |

---

## Knowledge & Memory

|     ADR | Decision                     | Status   |
| ------: | ---------------------------- | -------- |
| ADR-040 | Unified knowledge platform   | Accepted |
| ADR-041 | Workspace-scoped knowledge   | Accepted |
| ADR-042 | Explicit memory review       | Accepted |
| ADR-043 | Transparent memory retrieval | Accepted |
| ADR-044 | Citation-first responses     | Accepted |

---

## Workflow & Automation

|     ADR | Decision                                         | Status   |
| ------: | ------------------------------------------------ | -------- |
| ADR-060 | Central workflow engine                          | Accepted |
| ADR-061 | Event-driven automation                          | Accepted |
| ADR-062 | Background job scheduler                         | Accepted |
| ADR-063 | Automation history is persisted                  | Accepted |
| ADR-064 | Workflow plugins extend, not replace, the engine | Accepted |

---

## Plugin Platform

|     ADR | Decision                             | Status   |
| ------: | ------------------------------------ | -------- |
| ADR-080 | Single plugin SDK                    | Accepted |
| ADR-081 | Plugin sandboxing                    | Accepted |
| ADR-082 | Capability-based permissions         | Accepted |
| ADR-083 | Stable plugin APIs                   | Accepted |
| ADR-084 | Backward-compatible extension points | Accepted |

---

## Security & Privacy

|     ADR | Decision                  | Status   |
| ------: | ------------------------- | -------- |
| ADR-100 | Offline-first privacy     | Accepted |
| ADR-101 | Explicit network access   | Accepted |
| ADR-102 | Workspace isolation       | Accepted |
| ADR-103 | Signed models and plugins | Accepted |
| ADR-104 | Local audit logging       | Accepted |

---

## Engineering

|     ADR | Decision                                              | Status   |
| ------: | ----------------------------------------------------- | -------- |
| ADR-120 | Platform-first development                            | Accepted |
| ADR-121 | Shared services over feature-specific implementations | Accepted |
| ADR-122 | Documentation evolves with code                       | Accepted |
| ADR-123 | Tests are mandatory for new capabilities              | Accepted |
| ADR-124 | Performance budgets enforced in CI                    | Accepted |

---

## Release Engineering

|     ADR | Decision                                 | Status   |
| ------: | ---------------------------------------- | -------- |
| ADR-140 | Automated CI/CD pipeline                 | Accepted |
| ADR-141 | Variant-based distribution               | Accepted |
| ADR-142 | Model and plugin validation              | Accepted |
| ADR-143 | Structured release documentation         | Accepted |
| ADR-144 | Rollback support for platform components | Accepted |

---

## Autonomous Engineering

|     ADR | Decision                                      | Status   |
| ------: | --------------------------------------------- | -------- |
| ADR-160 | AI coding agents are first-class contributors | Accepted |
| ADR-161 | Repository analysis before implementation     | Accepted |
| ADR-162 | Continuous architecture conformance           | Accepted |
| ADR-163 | Autonomous maintenance workflows              | Accepted |
| ADR-164 | Regression preservation                       | Accepted |

---

# ADR Lifecycle

Every ADR progresses through the following states:

```text
Proposed
   ↓
Under Review
   ↓
Accepted
   ↓
Implemented
   ↓
Superseded (optional)
   ↓
Deprecated (optional)
```

No architectural decision should be implemented before reaching the **Accepted** state.

---

# ADR Template

Every new ADR includes:

* Identifier
* Title
* Status
* Context
* Problem Statement
* Decision
* Alternatives Considered
* Consequences
* Migration Strategy
* Related ADRs
* Related Packages
* Implementation Notes

---

# Governance Rules

* Every architectural change requires an ADR.
* ADR identifiers are immutable.
* Superseded ADRs remain in the repository for historical reference.
* Breaking architectural changes reference all affected ADRs.
* Quarterly architecture reviews verify that implementation still conforms to accepted ADRs.

---

# Review Cadence

The catalog is reviewed:

* Before introducing new platform capabilities
* During quarterly architecture reviews
* Before major release planning
* When introducing new engineering streams

---

# Success Criteria

A healthy architecture exhibits:

* Clear decision history
* Minimal contradictory decisions
* Stable long-term principles
* Discoverable architectural rationale
* Consistent implementation across the repository

The Architecture Decision Catalog is the institutional memory of AIRO. It records not only what the platform does, but why it was designed that way, ensuring that future contributors—human or AI—can evolve the system without losing its architectural intent.
