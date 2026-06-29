# AIRO Architecture Specification

# Part 7A — Event Bus & Messaging Architecture

Version: 1.0 (Draft)

---

# 1. Objective

The Event Bus is the communication backbone of AIRO.

Instead of subsystems directly calling one another, they communicate through events. This reduces coupling, enables extensibility, supports plugins, and allows background processing without tightly binding components together.

The Event Bus is an internal messaging system. It is not a network message broker and does not require internet connectivity.

---

# 2. Vision

Traditional application

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

AIRO

```text
MeetingCompleted

↓

Event Bus

├── Knowledge Processor
├── Embedding Generator
├── Memory Processor
├── Search Indexer
├── Analytics
├── Dashboard
└── Plugin Extensions
```

The publisher never knows who consumes an event.

---

# 3. Design Principles

The Event Bus must be:

* Offline-first
* Lightweight
* Observable
* Asynchronous
* Deterministic
* Replayable
* Extensible
* Plugin-aware

---

# 4. High-Level Architecture

```text
Domain

↓

Event Publisher

↓

Event Bus

↓

Event Router

↓

Subscriber Registry

↓

Consumers

↓

Domain Events
```

---

# 5. Responsibilities

The Event Bus is responsible for:

* Delivering events
* Routing subscribers
* Preserving ordering within aggregates
* Tracking delivery
* Retrying transient failures
* Publishing telemetry
* Supporting replay
* Isolating subscriber failures

It is **not** responsible for business logic.

---

# 6. Event Lifecycle

```text
Create Event

↓

Validate

↓

Publish

↓

Route

↓

Deliver

↓

Acknowledge

↓

Archive
```

Failures follow a retry policy before moving to the Dead Letter Queue.

---

# 7. Event Types

### Domain Events

Represent business state changes.

Examples

* MeetingCompleted
* KnowledgeCreated
* WorkflowFinished

---

### Integration Events

Expose platform changes to plugins.

Examples

* PluginInstalled
* ModelLoaded
* SearchCompleted

---

### System Events

Represent infrastructure state.

Examples

* LowMemory
* BatteryLow
* NetworkAvailable
* StorageLow

---

### UI Events

Represent presentation-layer interactions.

Examples

* WorkspaceChanged
* ThemeChanged
* NavigationCompleted

UI events never modify business state.

---

# 8. Event Bus Components

Core components:

```text
EventBus

EventPublisher

EventRouter

SubscriberRegistry

EventQueue

EventDispatcher

RetryManager

DeadLetterQueue

ReplayEngine

EventTelemetry
```

Each component has a single responsibility.

---

# 9. Event Publisher

Every aggregate publishes events through the EventPublisher.

Example

```text
Meeting Aggregate

↓

MeetingCompleted

↓

EventPublisher

↓

EventBus
```

Publishers never know who receives the event.

---

# 10. Subscriber Registry

Every subscriber registers declaratively.

Example

```yaml
event:

MeetingCompleted

handler:

KnowledgeBuilder
```

Registration occurs during application startup.

Plugins register dynamically.

---

# 11. Event Routing

Routing is capability-based.

```text
MeetingCompleted

↓

Knowledge

Memory

Search

Analytics

Plugins
```

Multiple subscribers receive the same event independently.

---

# 12. Delivery Guarantees

The Event Bus guarantees:

* At-least-once delivery
* Aggregate ordering
* Retry for transient failures
* Persistent delivery for critical events

Consumers must be idempotent.

---

# 13. Ordering

Ordering is guaranteed **within the same aggregate**.

Example

```text
MeetingStarted

↓

TranscriptUpdated

↓

SummaryGenerated

↓

MeetingCompleted
```

Ordering across unrelated aggregates is not guaranteed.

---

# 14. Event Queue

Queues exist per priority.

```text
Critical

High

Normal

Background

Maintenance
```

Queues are persistent.

---

# 15. Priority Rules

Critical

Application integrity

High

User-visible work

Normal

Business processing

Background

Knowledge enrichment

Maintenance

Cleanup

---

# 16. Synchronous vs Asynchronous Events

Synchronous

* UI refresh
* Navigation updates

Asynchronous

* Embeddings
* OCR
* Knowledge graph
* Summaries
* Downloads

The publisher chooses the dispatch mode.

---

# 17. Event Filtering

Subscribers filter events using:

* Event type
* Aggregate
* Workspace
* Plugin
* Priority
* Correlation ID

No unnecessary dispatch occurs.

---

# 18. Event Metadata

Every event contains:

```yaml
event_id:

event_type:

version:

timestamp:

workspace:

aggregate:

priority:

producer:

correlation_id:

causation_id:
```

Metadata is immutable.

---

# 19. Event Serialization

Supported formats:

* JSON
* Binary (future)

Serialization must be deterministic.

---

# 20. Event Replay

Replay allows rebuilding derived state.

Examples

Replay:

KnowledgeCreated

↓

Rebuild Search Index

Replay:

MemoryUpdated

↓

Recompute Memory Graph

Replay does not modify original history.

---

# 21. Retry Manager

Policies

Immediate

Linear Backoff

Exponential Backoff

Manual

Never Retry

Each subscriber defines its retry strategy.

---

# 22. Dead Letter Queue

Repeated failures are isolated.

Stored information:

* Event
* Error
* Subscriber
* Retry count
* Timestamp

Users may retry or inspect failed events.

---

# 23. Event Transactions

Critical events are transactional.

Example

```text
KnowledgeCreated

↓

Persist

↓

Publish Event

↓

Commit
```

Events are never published before successful persistence.

---

# 24. Plugin Integration

Plugins may:

Publish events

Subscribe to events

Define new event types

Plugins cannot intercept or modify existing platform events.

---

# 25. Security

The Event Bus enforces:

* Workspace isolation
* Permission validation
* Plugin boundaries
* Immutable payloads
* Event schema validation

Sensitive content is never exposed outside authorized scopes.

---

# 26. Performance

The Event Bus must:

* Handle thousands of events per minute
* Add minimal latency
* Avoid blocking UI threads
* Batch low-priority dispatches
* Prioritize user-visible work
* Scale with plugin growth

---

# 27. Diagnostics

Expose:

* Queue depth
* Delivery latency
* Subscriber failures
* Retry statistics
* Event throughput
* Processing time
* Replay history

Available through Developer Mode.

---

# 28. Platform Components

EventBus

EventPublisher

EventDispatcher

EventRouter

SubscriberRegistry

PriorityQueue

RetryManager

ReplayEngine

DeadLetterQueue

EventMetrics

---

# 29. Non-Functional Requirements

The Event Bus must:

* Operate completely offline
* Be deterministic
* Preserve aggregate ordering
* Support replay
* Recover after crashes
* Support plugins
* Scale to millions of events
* Minimize CPU and memory overhead

---

# 30. Architecture Decision Records

## ADR-076 — Event-Driven Communication

**Status**

Accepted

**Decision**

Subsystems communicate through the Event Bus rather than direct asynchronous service calls.

**Reason**

Reduces coupling, improves extensibility, and enables background execution.

---

## ADR-077 — Aggregate Ordering

**Status**

Accepted

**Decision**

Ordering is guaranteed only within a single aggregate.

**Reason**

Provides consistency while allowing parallel execution across unrelated domains.

---

## ADR-078 — Persistent Critical Events

**Status**

Accepted

**Decision**

Critical events are persisted before publication.

**Reason**

Prevents event loss during crashes or interruptions.

---

## ADR-079 — Plugin Event Isolation

**Status**

Accepted

**Decision**

Plugins may publish and subscribe to events but cannot alter platform event streams.

**Reason**

Protects platform integrity while enabling extensibility.

---

## ADR-080 — Replayable Messaging

**Status**

Accepted

**Decision**

The Event Bus supports deterministic replay of persisted events.

**Reason**

Enables recovery, diagnostics, index rebuilding, and future event-sourced capabilities.

---

# 31. Future Evolution

Phase 1

Internal Event Bus

↓

Phase 2

Plugin Event Integration

↓

Phase 3

Cross-Workspace Messaging

↓

Phase 4

Cross-Device Event Synchronization

↓

Phase 5

Distributed Event Platform

Future capabilities:

* Event batching optimization
* Event prioritization using AI
* Distributed event routing
* Live event visualization
* Event dependency graphs
* Cross-device event replication
* Event simulation tools
* Event-driven workflow synthesis

The Event Bus & Messaging Architecture establishes the communication backbone of AIRO. By replacing tightly coupled service interactions with structured, observable, and replayable events, the platform gains modularity, resilience, extensibility, and a scalable foundation for plugins, workflows, background processing, and future distributed execution while remaining fully offline and privacy-first.
