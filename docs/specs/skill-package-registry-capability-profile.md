# Skill Package, Registry, and Capability Profile Schemas

Issue: #382
Owner: Framework Agent
Review agents: Agent Skills Agent, Security and Privacy Agent, QA Automation Agent
Layer: Framework

## Contract boundary

This document defines the stable schema contract for Agent Skills. It does not implement runtime execution, permission prompting, package import, routine DAG execution, or network download behavior. Those follow in #385, #383, #386, #384, and #387.

## Cross-agent contract

Provider agent: Framework Agent
Consumer agents: Agent Skills Agent, Routine OS Agent, Security and Privacy Agent, QA Automation Agent
Interface/API: `package:core_ai/core_ai.dart` exports `SkillPackage`, `SkillRegistryEntry`, `CapabilityProfile`, and supporting enums/value objects.
Input shape: JSON-compatible maps using snake_case keys.
Output shape: deterministic JSON maps preserving schema versions, permissions, provenance, eval cases, registry state, and capability profile runtime settings.
State changes: none in this issue; these are pure schema/value types.
Errors: manifest validation returns deterministic user-facing error strings through `SkillPackage.validateJson`; constructors throw `ArgumentError` only after validation fails or enum values are unknown.
Permissions: every skill package must declare requested permission scopes and trust tiers before activation.
Privacy/redaction: registry entries store package/provenance/eval status only; prompt text remains inside eval fixtures and must not be copied into install/update/disable telemetry.
Persistence: callers can persist `toJson()` output and restore with `fromJson()`.
Versioning/migration: every top-level schema has a version constant (`1.0`) and serialized `schema_version`.
Tests required: schema round-trip, invalid metadata rejection, registry status preservation, capability profile permission/runtime bundling.

## Deterministic use cases

### UC-001: built-in skill resolves capability profile
Actor: Framework Agent / Agent Skills Agent
Preconditions: a built-in package manifest has schema version `1.0`, provenance, permissions, eval cases, and a capability profile id.
Trigger: the package manifest is parsed.
Happy path: the package round-trips through JSON while preserving permissions, provenance, eval metadata, and capability profile ids.
Alternate paths: older compatible readers can inspect `schema_version` before deciding whether to migrate.
Failure paths: missing required metadata returns deterministic validation errors.
Data created/updated/deleted: none; pure value object parse/serialize.
Privacy expectations: eval prompts stay in the manifest/eval context, not registry event payloads.

### UC-002: community skill imports in draft-only mode
Actor: Security and Privacy Agent / community skill author
Preconditions: a registry entry exists for a package with source provenance and draft-only trust tier.
Trigger: the entry is parsed from registry JSON.
Happy path: registry entry preserves version, provenance, trust tier, review status, eval status, capability profile ids, installed timestamp, and enabled flag.
Alternate paths: review status can remain `security_review_required` while the package is disabled.
Failure paths: unsupported enum values throw deterministic `ArgumentError` messages.
Data created/updated/deleted: none in this issue.
Privacy expectations: no secrets or prompt contents are required in registry entries.

### UC-003: capability profile gates allowed skills/tools
Actor: Routine OS Agent / runtime planner
Preconditions: a profile declares runtime params, allowed skill ids, allowed tool scopes, permission defaults, and network policy.
Trigger: the profile is parsed from JSON.
Happy path: profile exposes model runtime config, local-only setting, allowed skill ids, tool scopes, permission defaults, and network policy.
Alternate paths: network policy can be `blocked`, `read_only`, or `allowlisted`.
Failure paths: unsupported permission scopes fail enum parsing.
Data created/updated/deleted: none.
Privacy expectations: local-only profiles should keep model/runtime routing private and avoid silent cloud fallback.

## Automation flow

### AUTO-001: schema fixtures validate success and failure cases
Given valid and invalid skill package maps in `packages/core_ai/test/skills/skill_schema_test.dart`
When `flutter test test/skills/skill_schema_test.dart` runs inside `packages/core_ai`
Then valid fixtures parse and round-trip, while invalid fixtures return deterministic validation errors.
Fixtures: in-test JSON maps only.
Mocks/stubs: none.
Assertions: required metadata, provenance, permission scopes, eval cases, and enum mappings.
Cleanup: none.

### AUTO-002: serialization round-trip preserves contract fields
Given registry and capability profile JSON fixtures
When `fromJson()` and `toJson()` run
Then version, provenance, trust tier, review status, eval status, runtime params, allowed skill ids, tool scopes, permission defaults, and network policy remain stable.
Fixtures: in-test JSON maps only.
Mocks/stubs: none.
Assertions: exact enum/value checks.
Cleanup: none.

## Security posture

- Skill packages must declare provenance before activation.
- Permissions are explicit and tiered before runtime execution exists.
- Community packages can be represented as draft-only or security-review-required without enabling them.
- Registry entries avoid storing eval prompts or sensitive user prompt data.

## QA and release notes

- Host-only Flutter tests cover this schema slice.
- No emulator/device path is required.
- No migration is required because this introduces versioned schemas for future persistence.
