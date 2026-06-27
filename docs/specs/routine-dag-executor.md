# Typed Routine DAG Executor

Issue: #383
Owner: Framework Agent
Review agents: Agent Skills Agent, Routine OS Agent, QA Automation Agent, Security and Privacy Agent
Layer: Framework with application consumers

## Contract boundary

The routine DAG executor provides deterministic framework execution for typed routine graphs. It owns graph/node/run state contracts, dependency ordering, confirmation pauses, cancellation, restart-safe run state persistence boundaries, and trace lookup by run ID.

It does not own product routine templates, UI confirmation prompts, long-term encrypted database adapters, cloud sync, or redacted trajectory storage beyond node-level trace records.

## Cross-agent contract

Provider agent: Framework Agent
Consumer agents: Routine OS Agent, Agent Skills Agent, QA Automation Agent, Security and Privacy Agent
Interface/API: `package:core_ai/core_ai.dart` exports `RoutineDagExecutor`, `RoutineDag`, `RoutineNode`, `RoutineEdge`, `RoutineRun`, `RoutineRunStore`, `RoutineRunMemoryStore`, `RoutineNodeHandler`, state enums, and trace/error types.
Input shape: `RoutineDag` nodes and edges plus a handler map keyed by node id.
Output shape: `RoutineRun` with run state, node states, node outputs, pending confirmation node id, optional error code, and redacted node traces.
State changes: handlers are the only side-effect boundary; confirmation-required action nodes pause before their handler runs.
Errors: deterministic `RoutineNodeException.code` values become run/trace error codes; unknown handler failures fail closed.
Permissions: tool nodes may carry `SkillActionRequest`; the executor uses `SkillPermissionEngine` before running side effects.
Privacy/redaction: traces include run id, node id, state, and error code only; node inputs/outputs are not copied into trace records.
Persistence: `RoutineRunStore` is the storage boundary. The initial implementation includes `RoutineRunMemoryStore` for deterministic tests and local framework wiring.
Versioning/migration: app database adapters can implement `RoutineRunStore` without changing the executor contract.

## Deterministic use cases

### UC-001: linear routine executes in dependency order
Actor: Routine OS Agent
Preconditions: DAG has prompt -> skill -> tool -> response style dependencies and handlers for each node.
Trigger: executor runs the DAG.
Happy path: nodes run in topological order, upstream outputs merge into downstream inputs, run succeeds, and traces are queryable by run id.
Failure paths: missing required handler fails the run with a deterministic error code.
Privacy expectations: trace records do not include prompt text or handler output payloads.

### UC-002: optional node failure does not fail the whole routine
Actor: Agent Skills Agent
Preconditions: a node is marked optional.
Trigger: optional handler throws `RoutineNodeException`.
Happy path: optional node records failed state and error code, downstream nodes can continue, and run succeeds if required nodes complete.
Failure paths: required node failure fails the run.
Privacy expectations: trace stores only error code.

### UC-003: confirmation-required side effect pauses before execution and resumes safely
Actor: Security and Privacy Agent / Routine OS Agent
Preconditions: tool node has an action request that resolves to `confirmationRequired`.
Trigger: executor reaches that node.
Happy path: run pauses before handler side effects, persists pending confirmation node id, can be restored from store, and resumes after explicit approval.
Failure paths: blocked/draft-only actions fail closed.
Privacy expectations: pending state and traces do not copy tool payload previews.

### UC-004: cancellation persists terminal state
Actor: Brain user or app lifecycle code
Preconditions: run is pending/running/paused.
Trigger: cancellation request.
Happy path: run state becomes cancelled, terminal flag is true, error code is persisted, and cancellation trace is queryable.
Failure paths: none in this framework slice.
Privacy expectations: cancellation reason should be a stable code, not raw user text.

## Automation flows

### AUTO-001: deterministic executor tests
Command: `flutter test test/skills/routine_dag_executor_test.dart` from `packages/core_ai`.
Assertions: topological order, merged inputs, optional failure continuation, confirmation pause/resume, cancellation, store read, and trace lookup.
Mocks/stubs: in-test handlers only; no network or external storage.
Cleanup: none.

### AUTO-002: package regression tests
Command: `flutter test test/skills/routine_dag_executor_test.dart test/skills/skill_permission_engine_test.dart test/skills/skill_schema_test.dart` from `packages/core_ai`.
Assertions: Sprint 2 executor stays aligned with Sprint 1 schema and permission contracts.
Mocks/stubs: none outside deterministic handlers.
Cleanup: none.
