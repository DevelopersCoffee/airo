# AIRO Architecture Specification

# Part 7B — Domain Events & Event Processing

Version: 1.0 (Draft)

---

# 1. Objective

The Event Bus provides transport.

This document defines **what events exist**, **who publishes them**, **who consumes them**, and **how they evolve**.

Every meaningful state transition inside AIRO becomes a domain event.

Services communicate through events rather than direct dependencies whenever asynchronous processing is appropriate.

---

# 2. Vision

Instead of tightly coupled service calls:

```text
MeetingService

↓

KnowledgeService

↓

EmbeddingService

↓

SearchService

↓

Dashboard
```

AIRO operates as an event-driven system:

```text
Meeting Finished

↓

MeetingCompleted

↓

Knowledge Processor

↓

KnowledgeUpdated

↓

Embedding Processor

↓

EmbeddingsGenerated

↓

SearchIndexer

↓

SearchUpdated
```

Each subsystem evolves independently.

---

# 3. Design Principles

Domain events must be:

* Immutable
* Versioned
* Observable
* Replayable
* Ordered within a stream
* Idempotent
* Self-describing
* Independent of UI

---

# 4. Event Categories

### User Events

Examples

* UserSignedIn
* WorkspaceOpened
* WorkspaceClosed
* SearchPerformed
* ConversationStarted

---

### Knowledge Events

* DocumentImported
* KnowledgeCreated
* KnowledgeUpdated
* KnowledgeDeleted
* RelationshipCreated
* EmbeddingsGenerated

---

### Meeting Events

* MeetingStarted
* MeetingPaused
* MeetingResumed
* MeetingStopped
* TranscriptUpdated
* SummaryGenerated
* DecisionsExtracted
* TasksExtracted

---

### Memory Events

* MemoryCreated
* MemoryUpdated
* MemoryMerged
* MemoryArchived
* MemoryDeleted

---

### Runtime Events

* ModelLoaded
* ModelUnloaded
* ModelDownloadStarted
* ModelDownloadCompleted
* ModelDownloadFailed

---

### Workflow Events

* WorkflowStarted
* TaskCompleted
* WorkflowPaused
* WorkflowFailed
* WorkflowCompleted

---

### Plugin Events

* PluginInstalled
* PluginEnabled
* PluginUpdated
* PluginDisabled
* PluginRemoved

---

### System Events

* LowMemory
* BatteryLow
* StorageLow
* CrashRecovered
* BackgroundProcessingStarted

---

# 5. Event Structure

Every event follows a common schema.

```yaml
id:

type:

version:

timestamp:

workspace:

aggregate_id:

correlation_id:

causation_id:

producer:

payload:

metadata:
```

Every event is self-contained.

---

# 6. Aggregate Ownership

Each event belongs to an aggregate.

Examples

Workspace

Meeting

Conversation

Knowledge Object

Plugin

Workflow

Memory

Events never span multiple aggregates.

---

# 7. Event Producers

Only aggregate owners publish events.

Example

Meeting Aggregate

↓

MeetingCompleted

Knowledge Aggregate

↓

KnowledgeUpdated

Workflow Aggregate

↓

WorkflowCompleted

No external component fabricates domain events.

---

# 8. Event Consumers

Consumers subscribe independently.

Example

MeetingCompleted

↓

Summary Generator

↓

Knowledge Builder

↓

Memory Updater

↓

Search Indexer

↓

Dashboard

One event may have many consumers.

---

# 9. Event Choreography

Processing is decentralized.

Example

```text
MeetingCompleted

↓

SummaryGenerated

↓

KnowledgeCreated

↓

EmbeddingsGenerated

↓

SearchIndexed

↓

WorkspaceStatisticsUpdated
```

No central coordinator is required.

---

# 10. Event Versioning

Support

v1

v2

v3

Consumers declare supported versions.

Breaking changes create new versions rather than modifying old ones.

---

# 11. Event Replay

The Event Platform supports replay.

Examples

Rebuild Search Index

↓

Replay Knowledge Events

Rebuild Memory Graph

↓

Replay Memory Events

Replay never changes original history.

---

# 12. Idempotency

Every consumer must tolerate duplicate events.

Example

KnowledgeUpdated

↓

Indexer

↓

Already Indexed

↓

Ignore Duplicate

Processing remains safe.

---

# 13. Event Ordering

Ordering guarantees apply within an aggregate.

Example

MeetingStarted

↓

TranscriptUpdated

↓

SummaryGenerated

↓

MeetingCompleted

Cross-aggregate ordering is not guaranteed.

---

# 14. Event Correlation

Complex workflows share a correlation ID.

Example

Meeting Import

↓

OCR

↓

Embedding

↓

Knowledge

↓

Search

↓

Notification

All events reference the same correlation ID.

---

# 15. Event Retention

Retention policies

Critical

Permanent

Operational

90 Days

Diagnostics

30 Days

Telemetry

Configurable

Retention is category-based.

---

# 16. Dead Letter Queue

Events that repeatedly fail processing move to a Dead Letter Queue.

Metadata retained:

* Event ID
* Failure count
* Error
* Consumer
* Timestamp

Users may retry processing.

---

# 17. Event Priorities

Priority levels

Critical

High

Normal

Background

Low

The scheduler honors priority.

---

# 18. Event Filtering

Consumers subscribe using filters.

Examples

Meeting Events

Workspace Events

Knowledge Events

Plugin Events

Search Events

No unnecessary processing occurs.

---

# 19. Event Validation

Before publication:

Validate

Schema

Payload

Aggregate

Version

Producer

Invalid events are rejected.

---

# 20. Event Security

Events must never expose:

Passwords

Secrets

Raw encryption keys

Authentication tokens

Sensitive OS credentials

Events may reference protected objects instead.

---

# 21. Event Persistence

Persist:

Event

Metadata

Version

Correlation

Producer

Timestamp

Payload

Persistence enables replay and diagnostics.

---

# 22. Event Monitoring

Metrics

Publication rate

Consumer latency

Queue depth

Replay duration

Dead-letter count

Retry count

Average processing time

---

# 23. Event Catalog

Maintain a generated catalog.

Example

| Event             | Producer  | Consumers                 |
| ----------------- | --------- | ------------------------- |
| MeetingCompleted  | Meeting   | Knowledge, Search, Memory |
| KnowledgeUpdated  | Knowledge | Retrieval, Dashboard      |
| ModelLoaded       | Runtime   | UI, Telemetry             |
| WorkflowCompleted | Workflow  | Notification, Analytics   |

The catalog is generated from code.

---

# 24. Platform Components

DomainEvent

EventPublisher

EventConsumer

EventStore

ReplayEngine

DeadLetterQueue

CorrelationManager

EventCatalog

EventValidator

RetentionManager

---

# 25. Non-Functional Requirements

The event platform must

* Operate offline
* Support replay
* Guarantee aggregate ordering
* Handle duplicate delivery
* Scale to millions of events
* Support plugin-defined events
* Preserve backward compatibility

---

# 26. Architecture Decision Records

## ADR-076 — Domain Events as Integration Contracts

**Status**

Accepted

**Decision**

Subsystems communicate using domain events rather than direct asynchronous service dependencies.

**Reason**

Reduces coupling and improves extensibility.

---

## ADR-077 — Immutable Events

**Status**

Accepted

**Decision**

Published events are never modified.

**Reason**

Supports replay, auditing, and deterministic processing.

---

## ADR-078 — Aggregate Ownership

**Status**

Accepted

**Decision**

Only aggregate owners publish lifecycle events.

**Reason**

Maintains consistency and prevents conflicting event histories.

---

## ADR-079 — Replayable Event Store

**Status**

Accepted

**Decision**

Events are retained to rebuild derived data structures.

**Reason**

Allows reconstruction of search indexes, knowledge graphs, and analytics.

---

## ADR-080 — Idempotent Consumers

**Status**

Accepted

**Decision**

All consumers must safely process duplicate events.

**Reason**

Guarantees correctness during retries and replay.

---

# 27. Future Evolution

Phase 1

Core Domain Events

↓

Phase 2

Plugin Events

↓

Phase 3

Cross-Workspace Events

↓

Phase 4

Distributed Event Streaming

↓

Phase 5

Event-Sourced Platform

Future capabilities:

* Visual event explorer
* Time-travel debugging
* Event lineage graphs
* Event-driven analytics
* Cross-device synchronization
* Distributed replay
* AI-assisted event diagnostics
* Event simulation environment

The Domain Events & Event Processing architecture establishes a consistent language for every meaningful state transition in AIRO. By treating events as immutable integration contracts, the platform enables independent evolution of subsystems, deterministic recovery, plugin extensibility, and scalable asynchronous processing without sacrificing offline capability or architectural clarity.
