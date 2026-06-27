# Skill Trigger and Progressive-Disclosure Evaluation Suite

Issue: #384
Owner: QA Automation Agent
Review agents: Agent Skills Agent, Framework Agent, Security and Privacy Agent
Layer: Framework QA

## Contract boundary

The trigger evaluation suite gives skill authors and QA deterministic fixtures for skill selection behavior. It validates trigger-positive, trigger-negative, and ambiguity prompts while keeping evaluation local-first and privacy-safe.

This slice defines the core fixture schema, evaluator, result report, reason codes, and progressive-disclosure assertions. It does not define hosted CI policy, full imported community package scanning, or model-backed semantic ranking.

## Cross-agent contract

Provider agent: QA Automation Agent
Consumer agents: Agent Skills Agent, Framework Agent, Security and Privacy Agent
Interface/API: `package:core_ai/core_ai.dart` exports `SkillTriggerEvalSuite`, `SkillTriggerMetadata`, `SkillTriggerEvalCase`, `SkillTriggerEvalReport`, `SkillTriggerEvalResult`, trigger decision/status/reason/disclosure enums, and package-level `triggerEvalCases`.
Input shape: L1 `SkillTriggerMetadata` plus eval cases from package manifests or in-test fixtures.
Output shape: `SkillTriggerEvalReport` with per-case decisions, selected skill ids, reason codes, disclosure level, and loaded asset refs.
State changes: none; suite is deterministic and side-effect free.
Errors: private-data fixtures fail the report with `privateFixtureRejected`.
Permissions: ambiguous prompts resolve to clarification without loading skill bodies/assets.
Privacy/redaction: fixture prompts are rejected when they contain password/token/secret markers, childhood address, SSN/credit-card-like values, or similar private data.
Persistence: reports are JSON/reporting-ready through stable enums and fields; CI wiring is out of scope for this slice.
Versioning/migration: `SkillPackage` can round-trip `trigger_eval_cases` alongside existing `eval_cases`.

## Deterministic use cases

### UC-001: direct user request selects intended skill
Actor: Agent Skills Agent
Preconditions: L1 metadata includes skill id, description, and trigger phrases.
Trigger: positive eval prompt matches the intended skill.
Happy path: report passes, selected skill id equals expected skill id, reason code is `selectedExpectedSkill`.
Failure paths: missing or wrong selected skill marks case failed.
Privacy expectations: fixture prompt must not contain real private user data.

### UC-002: unrelated request does not load the skill body
Actor: QA Automation Agent
Preconditions: negative eval prompt is unrelated to the tested skill.
Trigger: suite evaluates the negative case.
Happy path: decision is `none`, selected skill id is null, disclosure remains `l1Metadata`, loaded assets are empty.
Failure paths: selecting the tested skill fails the case.
Privacy expectations: no L2/L3 assets are loaded for negatives.

### UC-003: ambiguous request asks for clarification
Actor: Framework Agent / Agent Skills Agent
Preconditions: ambiguity eval names candidate skill ids.
Trigger: suite evaluates ambiguous prompt.
Happy path: decision is `clarify`, reason code is `needsClarification`, disclosure remains L1.
Failure paths: selecting a concrete skill without clarification fails future stricter evaluators.
Privacy expectations: ambiguity should not cause skill body loading.

### UC-004: private fixture rejected
Actor: Security and Privacy Agent
Preconditions: fixture prompt includes private markers.
Trigger: suite evaluates the case.
Happy path: report fails with `privateFixtureRejected` and no selected skill.
Failure paths: private fixture is never treated as a passing skill-selection fixture.
Privacy expectations: authors must use synthetic prompts.

## Automation flows

### AUTO-001: trigger eval contract tests
Command: `flutter test test/skills/skill_trigger_eval_test.dart` from `packages/core_ai`.
Assertions: positive selection, negative non-selection, ambiguity clarification, private fixture rejection, and progressive-disclosure L1-only behavior.
Mocks/stubs: no mocks; deterministic metadata and fixtures.
Cleanup: none.

### AUTO-002: sprint contract regression tests
Command: `flutter test test/skills/skill_trigger_eval_test.dart test/skills/skill_schema_test.dart test/skills/skill_permission_engine_test.dart test/skills/routine_dag_executor_test.dart test/skills/ai_trajectory_trace_test.dart` from `packages/core_ai`.
Assertions: trigger eval fixtures remain compatible with package schema, permission engine, routine DAG, and trajectory tracing contracts.
Mocks/stubs: deterministic fixtures only.
Cleanup: none.

## CI reporting mode

Initial CI mode should be advisory: run the eval suite, collect failing reason codes, and report selected skill/confidence/reason-code metadata. Once built-in skill fixtures stabilize, CI can make regressions blocking.
