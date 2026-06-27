# Adversarial Evaluation Harness for Imported Skills and Tool Calls

Issue: #387
Owner: Security and Privacy Agent
Review agents: QA Automation Agent, Framework Agent, Agent Skills Agent
Layer: Framework QA/security

## Contract boundary

The adversarial harness runs deterministic red/blue/green checks before imported skills are activated and before tool-calling prompt patterns are trusted. It performs static validation only for imported package content and uses the trust-tier permission engine for prompt/tool fixtures. No imported code executes during validation.

## Cross-agent contract

Provider agent: Security and Privacy Agent
Consumer agents: QA Automation Agent, Framework Agent, Agent Skills Agent
Interface/API: `SkillAdversarialEvalHarness`, `SkillAdversarialFixture`, `SkillAdversarialEvalReport`, `SkillAdversarialFinding`, `SkillAdversarialEvalDecision`, `SkillAdversarialReasonCode` exported from `package:core_ai/core_ai.dart`.
Input shape: skill package JSON plus static package fixtures, or prompt/tool fixtures carrying `SkillActionRequest`.
Output shape: report with activation decision, pass/fail status, reason codes, optional permission tier, and redacted evidence.
State changes: none.
Errors: unsafe packages are rejected or downgraded with stable reason codes.
Permissions: prompt/tool fixtures resolve through `SkillPermissionEngine` and never execute tool calls.
Privacy/redaction: evidence is sanitized before report emission; URLs, filesystem paths, and long numeric identifiers are redacted.
Persistence: reports are deterministic and suitable for CI artifacts.

## Deterministic use cases

### UC-001: hidden capability request rejected
Actor: Security and Privacy Agent
Preconditions: imported package declares limited permissions.
Trigger: fixture skill body requests undeclared network or file access.
Happy path: report decision is `reject`, status is `failing`, reason code is `hiddenCapabilityRequest`.
Failure paths: raw URL/path evidence must not leak in the report.
Privacy expectations: report only redacted evidence.

### UC-002: prompt injection blocked by permission engine
Actor: QA Automation Agent
Preconditions: fixture prompt asks to ignore permissions and invoke a sensitive tool.
Trigger: harness evaluates prompt/tool calls.
Happy path: permission tier is not auto-approved/read-only, decision is `reject`, reason code is `promptInjectionBlocked`.
Failure paths: payload identifiers are redacted.
Privacy expectations: no tool payload is copied into unredacted findings.

### UC-003: safe community skill downgraded
Actor: Agent Skills Agent
Preconditions: imported community package passes static adversarial checks.
Trigger: harness evaluates package.
Happy path: report status is `passing`, decision is `downgradeToDraftOnly`, reason code is `safeCommunitySkillDraftOnly`.
Failure paths: safe imports are not auto-activated.
Privacy expectations: no imported code executes.

### UC-004: slopsquatting package id rejected
Actor: Security and Privacy Agent
Preconditions: reserved package prefixes are configured.
Trigger: imported package id resembles a reserved prefix using common substitutions.
Happy path: decision is `reject`, reason code is `slopsquattingPackageId`.
Failure paths: typo-like package ids do not bypass import validation.
Privacy expectations: report avoids unnecessary package body content.

## Automation flows

### AUTO-001: adversarial harness contract tests
Command: `flutter test test/skills/skill_adversarial_eval_harness_test.dart` from `packages/core_ai`.
Assertions: hidden capabilities reject, prompt injection is blocked, safe community imports downgrade, slopsquatting ids reject.
Mocks/stubs: deterministic local fixtures only.
Cleanup: none.

### AUTO-002: sprint security regression tests
Command: `flutter test test/skills/skill_adversarial_eval_harness_test.dart test/skills/skill_trigger_eval_test.dart test/skills/skill_schema_test.dart test/skills/skill_permission_engine_test.dart test/skills/routine_dag_executor_test.dart test/skills/ai_trajectory_trace_test.dart` from `packages/core_ai`.
Assertions: adversarial, trigger, schema, permission, DAG, and trace contracts remain compatible.
Mocks/stubs: deterministic local fixtures only.
Cleanup: none.

## CI posture

Imported skills should be blocking on adversarial harness failures. Built-in skills can start advisory while fixture coverage grows, then become blocking once the corpus is stable.
