# Platform Logging & Observability

`platform_logging` is the centralized observability package for AIRO.

This package defines the logging contracts, structured events, log routing, diagnostics, and context propagation required to safely trace, monitor, and debug the AIRO platform.

**IMPORTANT: No package may perform logging outside this platform. Never use `print()` or `dart:developer` directly.**

## Responsibilities

* **Log Routing:** Decouples log statements from sinks (e.g., Console, Memory, File, Crashlytics).
* **Structured Logs:** Every log entry is strongly typed (`LogEntry`) with explicit metadata, preventing stringly-typed logs that are hard to parse.
* **Context Propagation:** Automatically propagates Session ID, Workspace ID, and Correlation IDs via `LogContextProvider` so workflows are traceable across the stack.
* **Filtering:** Implements level and category-based filtering before logs reach sinks.
* **Diagnostics:** Exposes foundational contracts (`DiagnosticCollector`, `HealthStatus`, `PerformanceMarker`) to monitor component health and execution duration.

## Public Interfaces

* `Logger`: The primary interface for producing logs (`trace`, `debug`, `info`, `warn`, `error`, `fatal`).
* `LogSink`: Where logs go (`ConsoleSink`, `MemorySink`).
* `LogFormatter`: How logs look (`HumanReadableFormatter`, `JsonFormatter`).
* `LogFilter`: Which logs are dropped (`LevelFilter`, `CategoryFilter`).
* `LogContextProvider`: Injects dynamic context into logs.
* `PerformanceMarker`: Start/stop tracing for performance bounds.

## Rules
* Obtain a logger strictly via Riverpod (`ref.read(loggerProvider)`). **Never** use a global static instance.
* Do not log maps or dynamic objects directly; wrap them in `LogMetadata`.
* All operations must declare a `LogCategory`.

## Bootstrap

The `LoggingBootstrapTask` runs immediately after `Environment` in the `platform_core` bootstrap sequence. This ensures logging is available before storage or settings try to initialize.
