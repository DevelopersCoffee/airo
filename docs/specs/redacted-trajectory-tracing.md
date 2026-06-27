# Redacted Trajectory Tracing

Issue: #386
Owner: QA Automation Agent
Review agents: Security and Privacy Agent, Framework Agent, Agent Skills Agent
Layer: Framework observability

## Contract boundary

The redacted trajectory tracing contract provides deterministic, local-first AI action trace nodes for QA and debugging without storing raw prompts, parameters, tool results, health details, finance data, memory content, or secrets in trace logs.

This slice defines the base trace model and deterministic redaction hooks. It does not define long-term retention limits, encrypted database storage, debug export UI, or cloud synchronization.

## Cross-agent contract

Provider agent: QA Automation Agent
Consumer agents: Security and Privacy Agent, Framework Agent, Agent Skills Agent, Routine OS Agent
Interface/API: `package:core_ai/core_ai.dart` exports `AiTrajectoryTrace`, `AiTrajectoryNode`, `AiTrajectoryTraceBuilder`, `AiTraceRedactor`, `AiTrajectoryNodeKind`, and `AiTrajectoryNodeStatus`.
Input shape: a run id plus builder calls for prompt references, selected skill, tool call, parameter/result/final-answer references, confirmation, error, and routine nodes.
Output shape: JSON-safe `AiTrajectoryTrace.toJson()` with schema version, run id, and ordered redacted nodes.
State changes: none; builder/redactor are deterministic and side-effect free.
Errors: failed tool nodes use stable `errorCode`; raw exception text is redacted before storage.
Permissions: confirmation nodes record pending decisions but do not approve or execute side effects.
Privacy/redaction: node summaries are redacted for secrets, finance identifiers, health/medicine terms, and memory content. Raw payloads must be stored behind local secure references, not directly in trace nodes.
Persistence: callers store trace JSON locally behind the feature flag/retention policy chosen by the app layer.
Versioning/migration: `schema_version` starts at `1`.

## Deterministic use cases

### UC-001: successful read-only tool run emits full redacted trajectory
Actor: QA Automation Agent
Preconditions: skill orchestration selected a read-only tool.
Trigger: trace builder records prompt ref, selected skill, tool call, parameters ref, result ref, and final answer ref.
Happy path: node order is deterministic and sequence numbers are contiguous.
Failure paths: none in builder; callers validate required nodes per use case.
Privacy expectations: prompt text, tokens, finance identifiers, health details, and memory content are replaced with redaction markers.

### UC-002: confirmation-required tool pauses and records pending decision
Actor: Security and Privacy Agent
Preconditions: tool permission engine returns confirmation required.
Trigger: builder records `confirmationRequired`.
Happy path: final node has kind `confirmation`, status `pending`, and sanitized reason.
Failure paths: no side effect is implied by trace creation.
Privacy expectations: parameter summaries are redacted and raw tool payloads remain behind local refs.

### UC-003: failed tool records sanitized error
Actor: QA Automation Agent
Preconditions: tool fails with a stable error code.
Trigger: builder records `error(code, summary)`.
Happy path: error node has failed status and stable error code.
Failure paths: raw exception secrets are redacted.
Privacy expectations: no password/token or private memory text appears in serialized trace JSON.

### UC-004: routine traces are represented in the base schema
Actor: Routine OS Agent
Preconditions: routine DAG executor has a routine id/run id.
Trigger: builder records `routine(routineId)`.
Happy path: routine node is ordered with other trajectory nodes and JSON-safe.
Failure paths: none in this slice.
Privacy expectations: routine labels should be stable identifiers, not raw user prompts.

## Automation flows

### AUTO-001: base trace schema tests
Command: `flutter test test/skills/ai_trajectory_trace_test.dart` from `packages/core_ai`.
Assertions: node order, sequence numbers, schema version, refs, confirmation status, error code, routine node support, and redaction.
Mocks/stubs: none.
Cleanup: none.

### AUTO-002: sprint contract regression tests
Command: `flutter test test/skills/ai_trajectory_trace_test.dart test/skills/routine_dag_executor_test.dart test/skills/skill_permission_engine_test.dart test/skills/skill_schema_test.dart` from `packages/core_ai`.
Assertions: Sprint 2 tracing remains aligned with routine DAG executor and Sprint 1 skill/permission contracts.
Mocks/stubs: deterministic in-test data only.
Cleanup: none.

## Retention/export behavior

Trace JSON is local-first and redacted by default. App/database adapters should store trace JSON behind the debug/observability feature flag until retention controls land. Export must include schema version and local references only; exporting raw referenced payloads requires a separate explicit user-mediated policy and is out of scope for this ticket.
