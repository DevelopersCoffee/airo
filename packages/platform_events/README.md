# Platform Events

`platform_events` is the internal communication backbone for the AIRO platform.

This package defines the strictly-typed events and synchronous, deterministic publish-subscribe (`Pub/Sub`) mechanisms that allow decouple packages (e.g., Runtime, Storage, Workflows) to communicate safely.

**IMPORTANT: This is not a UI state management event bus or a Flutter event system. It is the platform messaging layer.**

## Responsibilities

* **Decoupled Communication:** Allows packages to broadcast `PlatformEvent` instances without knowing who is listening.
* **Type Safety:** All events are strictly typed and versioned, ensuring backwards compatibility and schema safety.
* **Deterministic Dispatch:** Events are processed via `scheduleMicrotask` preserving synchronous ordering per publisher without blocking.
* **Event Interception & Filtering:** Supports an interceptor pattern for global event enrichment (e.g., Correlation ID injection) and a filter pattern to drop specific events before dispatch.
* **Replay Buffer:** Maintains an in-memory replay buffer useful for diagnostics and debugging.

## Public Interfaces

* `PlatformEvent`: The base interface for all events traversing the bus.
* `EventBus`: The central nervous system implementing both Publisher and Subscriber roles.
* `EventPublisher`: The interface used to broadcast an event.
* `EventSubscriber`: The interface used to bind strongly-typed `EventHandler` callbacks.
* `EventInterceptor`: Interface to modify/enrich events in the pipeline.
* `EventFilter`: Interface to cancel/drop events in the pipeline.

## Rules
* Obtain the bus or publisher strictly via Riverpod (`ref.read(eventBusProvider)`).
* Do not mutate events inside a handler. `PlatformEvent` must remain strictly immutable.
* Do not rely on cross-publisher ordering. Events from the same publisher remain ordered (FIFO).
* Business-level domain events (e.g., "MeetingSummarized") belong in their respective feature packages, but implement `PlatformEvent` and are fired over this bus.
