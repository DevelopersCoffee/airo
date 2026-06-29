# ADR 0167: Platform Event Architecture

## Status
Accepted

## Context
As AIRO expands to include background jobs, ML model state changes, runtime downloads, and workflow execution, we need an decoupled way for these isolated systems to communicate.

If the Runtime package depends on the Storage package directly to notify it of a model download, we create tight coupling and circular dependencies. We need an internal messaging layer.

## Decision
We introduce `platform_events` as the central nervous system for platform communication.

1. **Typed Subscriptions:** We avoid stringly-typed messaging (e.g., `emit('model_downloaded', data)`). All events implement the `PlatformEvent` interface and contain explicit versions and schemas. Subscriptions are strongly typed: `bus.subscribe<ModelDownloadedEvent>((event) async { ... })`.
2. **Deterministic Dispatch:** Events are dispatched asynchronously using Dart's microtask queue. This guarantees that event handlers do not block the publisher, but the exact order of events published by a single source is strictly maintained.
3. **Pipeline (Filters & Interceptors):** The event bus supports an interceptor pipeline. This is critical for cross-cutting observability, as interceptors can automatically inject a `correlationId` into every event passing through the bus without requiring the publisher to know about the current context.
4. **No Persistence:** For now, the event bus only utilizes an in-memory replay buffer for diagnostic analysis. CQRS and Event Sourcing persistence models are explicitly out of scope for this foundation.

## Consequences
**Positive:**
- Zero tight coupling between distinct feature modules or platform boundaries.
- Consistent tracking of `correlationId` and `sessionId` through all platform interactions.
- Full type safety when extracting data from events.

**Negative:**
- Abstracting direct calls into events can make tracing control flow more difficult for new developers. (Mitigated by our mandatory Correlation ID tracking and logging).
