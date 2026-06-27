# Tool/Action Trust-Tier Permission Engine

Issue: #385
Owner: Security and Privacy Agent
Review agents: Framework Agent, Agent Skills Agent, QA Automation Agent
Layer: Framework

## Contract boundary

This document defines the deterministic trust-tier policy layer for Agent Skill tool/action execution. It does not implement UI confirmation prompts, runtime tool execution, routine DAG execution, or trajectory storage. Callers must resolve a `SkillActionRequest` through `SkillPermissionEngine` before executing an action.

## Cross-agent contract

Provider agent: Security and Privacy Agent
Consumer agents: Framework Agent, Agent Skills Agent, Routine OS Agent, QA Automation Agent
Interface/API: `package:core_ai/core_ai.dart` exports `SkillPermissionEngine`, `SkillActionRequest`, `SkillPermissionDecision`, `SkillPermissionDecisionTrace`, `SkillAutomationScope`, and supporting enums.
Input shape: a typed action request with `toolId`, domain, operation, source, optional automation scope, and optional local-only payload preview.
Output shape: a typed decision carrying `SkillTrustTier` and a redacted trace.
State changes: none; the resolver is pure and deterministic.
Errors: unknown tools and unsupported policies resolve to `blocked` instead of throwing.
Permissions: tiers are `readOnly`, `draftOnly`, `confirmationRequired`, `autoApproved`, and `blocked`.
Privacy/redaction: traces include tool id, domain, operation, tier, reason, and automation scope id only; payload previews are never copied into traces.
Persistence: traces are JSON-safe via `toJson()`.
Versioning/migration: consumes the #382 `SkillTrustTier` contract.
Tests required: unknown default block, read-only allow, write confirmation, scoped automation auto-approval, community draft-only, sensitive destructive/finance block.

## Deterministic use cases

### UC-001: read calendar action runs read-only
Actor: Agent Skills runtime
Preconditions: known `calendar.events.list` read action from a built-in skill.
Trigger: action request is resolved.
Happy path: resolver returns `readOnly`, `canExecute == true`, and `requiresConfirmation == false`.
Failure paths: unknown calendar tools remain blocked.
Privacy expectations: no calendar payload data appears in traces.

### UC-002: create reminder pauses for confirmation unless scoped automation exists
Actor: Routine OS / Agent Skills runtime
Preconditions: known `reminders.create` action.
Trigger: action request is resolved.
Happy path: without automation scope it returns `confirmationRequired`; with a matching scope it returns `autoApproved`.
Failure paths: mismatched automation scope does not auto-approve.
Privacy expectations: trace names scope id only.

### UC-003: sensitive destructive or finance action is blocked
Actor: Security and Privacy Agent
Preconditions: known finance transfer or file delete action.
Trigger: action request is resolved.
Happy path: resolver returns `blocked`, `canExecute == false`.
Failure paths: no scoped automation bypass exists for destructive finance/file-system actions in this slice.
Privacy expectations: no amount, account, file path, or prompt payload is traced.

## Automation flow

### AUTO-001: trust-tier matrix tests
Given action fixtures in `packages/core_ai/test/skills/skill_permission_engine_test.dart`
When `flutter test test/skills/skill_permission_engine_test.dart` runs in `packages/core_ai`
Then every tier is exercised and sensitive defaults are deterministic.
Fixtures: typed in-test action requests.
Mocks/stubs: none.
Assertions: tier, execution eligibility, confirmation requirement, and trace redaction.
Cleanup: none.

### AUTO-002: denied action has user-safe trace and no side effect
Given an unknown tool or blocked sensitive action
When resolved through `SkillPermissionEngine`
Then the decision is blocked and trace reason is safe to show/log without copying payload preview.
Fixtures: unknown tool payload preview containing secret-like text.
Mocks/stubs: none.
Assertions: `redactedPayload == null`.
Cleanup: none.
