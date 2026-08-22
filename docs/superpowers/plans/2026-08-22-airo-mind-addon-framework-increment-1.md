# Airo Mind Add-on Framework — Increment 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce neutral add-on and graph contracts in `core_domain`/`core_ai`, freeze current Diet/insurance/hospital/property behavior as characterization fixtures, and prove synthetic generative and graph-workflow add-ons run through the registry without host ID switches.

**Architecture:** `core_domain` owns data contracts (`AddonManifest`, graph DTOs, workflow projections, ports). `core_ai` owns validation, registry, adapter interfaces, and dispatch with zero business vocabulary. `feature_mind` keeps existing linker/projector/pending for now but adds JSON characterization fixtures and a bridge mapping `ChatEntityGraph` ↔ neutral `EntityGraph`. Production chat is not rerouted in this increment.

**Tech Stack:** Dart 3.12, Flutter test, melos workspace packages `core_domain`, `core_ai`, `feature_mind`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-22-airo-mind-addon-framework-design.md`
- `core_domain` has `allowed_dependencies: []` — no new third-party deps.
- `core_ai` may depend only on `core_domain`, `core_native`, `core_workers`, `platform_downloads`.
- Framework production code and framework tests use neutral identifiers (`sample-addon`, `subject`, `related_to`). Domain vocabulary lives in `feature_mind` characterization fixtures only.
- Serialized graph JSON shape is unchanged: `nodes`, `edges`, `recent_node_ids`; node `type` remains a string key (`person`, `organization`, …).
- Parsing above 50 KB uses worker boundary in later increments; fixtures stay small.
- Verify: `cd packages/core_domain && flutter test`, `cd packages/core_ai && flutter test`, `cd packages/feature_mind && flutter test test/agent_chat/fixtures/ test/agent_chat/domain/services/chat_entity_* test/addons/`

---

### Task 1: Neutral graph DTOs in `core_domain`

**Files:**
- Create: `packages/core_domain/lib/src/graph/entity_graph_node.dart`
- Create: `packages/core_domain/lib/src/graph/entity_graph_edge.dart`
- Create: `packages/core_domain/lib/src/graph/entity_graph.dart`
- Create: `packages/core_domain/lib/src/graph/entity_graph_patch.dart`
- Create: `packages/core_domain/lib/src/graph/graph_provenance.dart`
- Modify: `packages/core_domain/lib/core_domain.dart`
- Test: `packages/core_domain/test/graph/entity_graph_test.dart`

**Interfaces:**
- Produces: `EntityGraphNode`, `EntityGraphEdge`, `EntityGraph`, `EntityGraphPatch`, `GraphProvenanceRef` with `fromJson`/`toJson` matching existing chat graph JSON.

- [ ] **Step 1:** Write failing round-trip JSON test for a sample node/edge/graph.
- [ ] **Step 2:** Implement DTOs with string `typeKey` (not `EntityType` enum).
- [ ] **Step 3:** Export from `core_domain.dart` and run `flutter test test/graph/`.

---

### Task 2: Add-on manifest and workflow contracts in `core_domain`

**Files:**
- Create: `packages/core_domain/lib/src/addons/addon_id.dart`
- Create: `packages/core_domain/lib/src/addons/addon_identity.dart`
- Create: `packages/core_domain/lib/src/addons/addon_behavior_kind.dart`
- Create: `packages/core_domain/lib/src/addons/addon_manifest.dart`
- Create: `packages/core_domain/lib/src/workflow/offer_decision.dart`
- Create: `packages/core_domain/lib/src/workflow/workflow_projection.dart`
- Create: `packages/core_domain/lib/src/workflow/pending_assessment.dart`
- Create: `packages/core_domain/lib/src/addons/addon_registry_port.dart`
- Test: `packages/core_domain/test/addons/addon_manifest_test.dart`

- [ ] **Step 1:** Failing test parsing a minimal `addon.json` shape from the spec.
- [ ] **Step 2:** Implement manifest + workflow types.
- [ ] **Step 3:** Run `flutter test test/addons/`.

---

### Task 3: Manifest validation and registry in `core_ai`

**Files:**
- Create: `packages/core_ai/lib/src/addons/addon_manifest_validator.dart`
- Create: `packages/core_ai/lib/src/addons/addon_registry.dart`
- Create: `packages/core_ai/lib/src/addons/generative_addon_adapter.dart`
- Create: `packages/core_ai/lib/src/addons/graph_workflow_addon_adapter.dart`
- Create: `packages/core_ai/lib/src/addons/addon_conversation.dart`
- Create: `packages/core_ai/lib/src/addons/addon_prompt.dart`
- Create: `packages/core_ai/lib/src/addons/addon_evaluation.dart`
- Create: `packages/core_ai/lib/src/addons/graph_ingest_context.dart`
- Create: `packages/core_ai/lib/src/addons/addon_eligibility.dart`
- Modify: `packages/core_ai/lib/core_ai.dart`
- Test: `packages/core_ai/test/addons/addon_manifest_validator_test.dart`
- Test: `packages/core_ai/test/addons/addon_registry_test.dart`

- [ ] **Step 1:** Failing validator tests (unknown schema, duplicate ID, undeclared tool).
- [ ] **Step 2:** Implement validator + registry with enabled/pinned/granted flags.
- [ ] **Step 3:** Failing registry tests for ordering and zero calls when disabled.
- [ ] **Step 4:** Run `flutter test test/addons/`.

---

### Task 4: Synthetic adapters proving no host switch

**Files:**
- Create: `packages/core_ai/test/addons/synthetic_generative_adapter.dart`
- Create: `packages/core_ai/test/addons/synthetic_graph_workflow_adapter.dart`
- Test: `packages/core_ai/test/addons/synthetic_addon_dispatch_test.dart`

- [ ] **Step 1:** Synthetic generative adapter returns prompt when message contains `sample-trigger`.
- [ ] **Step 2:** Synthetic graph adapter patches a `subject` node when message contains `sample-extract`.
- [ ] **Step 3:** Registry dispatch test proves both behaviors without referencing real add-on IDs in `core_ai` production code.
- [ ] **Step 4:** Spy test: disabled add-on receives zero adapter calls.

---

### Task 5: Characterization fixtures in `feature_mind`

**Files:**
- Create: `packages/feature_mind/test/agent_chat/fixtures/characterization/*.json`
- Create: `packages/feature_mind/test/agent_chat/fixtures/characterization_test.dart`
- Create: `packages/feature_mind/lib/src/agent_chat/domain/models/entity_graph_bridge.dart`

- [ ] **Step 1:** Capture JSON for insurance-only, claim+hospital, property-only linker graphs.
- [ ] **Step 2:** Capture diet constraint lines and model prompt substrings as JSON.
- [ ] **Step 3:** Characterization test compares live linker/projector/pending/diet output to fixtures.
- [ ] **Step 4:** Bridge test: `ChatEntityGraph` ↔ `EntityGraph` round-trip preserves JSON.

---

### Task 6: Host dispatch smoke test

**Files:**
- Create: `packages/feature_mind/test/addons/addon_host_dispatch_test.dart`
- Create: `packages/feature_mind/lib/src/addons/addon_host_dispatch.dart`

- [ ] **Step 1:** Thin host wrapper calls `AddonRegistry` with synthetic adapters only.
- [ ] **Step 2:** Test proves generative and graph paths return typed results without `if (addonId == …)` in host code.

---
