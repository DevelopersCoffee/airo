# ADR 0166: Platform Logging and Observability Contracts

## Status
Accepted

## Context
As the AIRO monorepo grows, standard `print()` statements and unstructured strings will rapidly become unmanageable. Without a consistent logging strategy, we cannot correlate logs across workflows, parse them efficiently on the backend/crashlytics, or filter them for user privacy.

Furthermore, we need a way for observability metrics (e.g., diagnostics, health checks, performance tracing) to scale without locking us into a specific vendor like Firebase or Sentry on day one.

## Decision
We will establish a strict `platform_logging` package that acts as the sole observability entry point for the entire application.

1. **Structured Logs First:** All logs are passed as discrete fields (Level, Category, Message, Context, Metadata) and assembled into a structured `LogEntry`. Formatters (`HumanReadableFormatter`, `JsonFormatter`) determine the final output format right before hitting the `LogSink`.
2. **Context Propagation:** Workflows and jobs will be injected with a `LogContext` containing Correlation IDs and Session IDs, meaning any log written during that flow will automatically contain trace information.
3. **No Global Singletons:** The logger is obtained through Riverpod (`loggerProvider`). Sinks and filters are also injected, allowing tests to easily mock or read from a `MemorySink` to verify log outputs.
4. **Diagnostics Prep:** We introduce basic contracts for `DiagnosticCollector` and `PerformanceMarker` to lay the groundwork for OpenTelemetry or custom tracing later without breaking the API surface.

## Consequences
**Positive:**
- Complete decoupling of log production from log consumption.
- Traceable and deterministic debugging via Correlation IDs.
- Easily testable log outputs.
- Future-proofed for remote analytics and performance tracing.

**Negative:**
- Slightly more verbose than calling `print()`.
- Developers must properly annotate `LogCategory` and utilize the `Logger` interface correctly.
