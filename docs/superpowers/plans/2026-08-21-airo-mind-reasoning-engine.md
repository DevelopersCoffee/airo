# Airo Mind Reasoning Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one cross-platform Reasoning Engine so Airo Mind produces structured, intent-driven answers (with a user-facing progress summary) instead of unconstrained LLM chatter, while leaving inference runtimes swappable per device.

**Architecture:** Reasoning is an Airo Mind *capability*, not an inference-runtime feature and not a Flutter concern. A new Rust crate `airo_mind_reasoning` sits beside `airo_mind_meeting`: it consumes `&dyn GenerationEngine`, never owns llama.cpp/MLX/LiteRT, and exposes `Stream<ReasoningEvent>` through the existing FRB generation seam. Chain-of-thought is one internal last-mile mechanism (prompt strategy + optional internal scratchpad that is discarded), never a stored field and never a public SDK `thoughts` API.

**Tech Stack:** Rust (`airo_mind_core::GenerationEngine`, GBNF, `Supervisor`), flutter_rust_bridge, Dart presentation in `feature_mind`, existing `LlmDeviceTier` / `IntelligenceQuery` for device-aware limits.

**Worktree:** `/Users/udaychauhan/workspace/airo-worktrees/mind-reasoning-engine` on `agent/mind/reasoning-engine` @ `7f53a3f1` (`origin/main`).

**Council:** Framework Agent + Product Manager (`feature_mind`). Reviewers: Chief Architect, Rust Architect, Platform Architect, Chief Performance Officer, Chief Security Officer, Chief QA Officer, Chief UX Officer.

---

## Locked decisions

These are the architecture lock. Do not relitigate them in implementation PRs.

1. **Same Reasoning API on macOS, Windows, Android, iOS, iPadOS.** Only the `GenerationEngine` implementor and the loaded model change.
2. **Rust is the brain. Flutter is the client.** Flutter calls `reason(request)` and renders events. It does not classify intent, pick a reasoning level, build the prompt, parse tool calls, or validate output.
3. **Follow `airo_mind_meeting`, not `airo_mind_core`.** `C5` already forbids capabilities from living inside the runtime core. Meeting intelligence already takes `&dyn GenerationEngine` and owns prompts + GBNF + schema. Reasoning is the same shape for conversation.
4. **Do not add a Dart `lib/core/reasoning/` brain.** A thin Dart facade that mirrors the Rust types for the UI is allowed. Policy, prompt, parser, validator, and tool loop are Rust.
5. **Last mile is the product; CoT is a tick on that last mile.** Last mile = intent → context package → constrained generation → validate → synthesise. CoT/thinking is how the model may work internally on `standard`/`deep`. It is not a separate product.
6. **No raw CoT in the database or public API.** Persist `answer`, `reasoning_summary`, `reasoning_level`, `tool_calls`, metadata. Never `raw_thoughts` / scratchpad tokens.
7. **Do not implement #271 as written.** Gallery-style `partialThinkingResult` (raw model thinking stream as UI) is rejected. Supersede it with Reasoning progress events.
8. **Do not invent a second inference stack.** Reuse `GenerationRequest.grammar`, `LlamaGenerationEngine`, `Supervisor`, `MindGenerationBridge`. Remaining #1628 work (backend registry, Apple FM, LiteRT behind the same trait) stays on those issues.
9. **Keyword `IntentParser` is not the permanent intent engine.** Today's phrase map in `packages/feature_mind/.../intent_parser.dart` is a stopgap. V1 reasoning policy may take a structured `ClassifiedIntent` produced by a small classifier or constrained extract; it must not `query.contains("plan")` as the long-term router.
10. **Architecture freeze still holds.** No eighth runtime primitive. Reasoning is a capability crate + Flutter events. If a frozen contract must change, that is an ADR, not a drive-by.

```text
Flutter UI  ──FRB──►  airo_mind_reasoning
                         │  policy, context, prompt, parse, validate, tools
                         ▼
                   GenerationEngine  (domain-free)
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    llama.cpp         Apple FM       LiteRT / other
    macOS/Win/        iOS/iPad       Android
    Android GGUF
```

---

## What already exists (do not rebuild)

Inventoried 2026-08-21 against `origin/main` (`7f53a3f1`) and GitHub milestone 26 / 27.

### Last-mile inference (the foundation this plan sits on)

| Piece | Where | Status on `origin/main` | Issue |
|---|---|---|---|
| `GenerationEngine` trait + streaming sink | `rust/airo_mind_core/src/engine.rs` | Landed | #1628 (trait extraction; `LlmBackend` rename is comment-only, not merged) |
| GBNF on `GenerationRequest.grammar` | same + `rust/airo_mind_llama/src/llama.rs` | Landed; digits-only + terminating-grammar tests | #1628 AC, #1739 closed |
| `RuntimeStats` (tok/s, prefill, RSS) | `GenerationEngine::stats` | Landed | #1628 AC |
| Meeting IR two-pass + GBNF facts grammar | `rust/airo_mind_meeting` | Landed | #1633 closed |
| Deterministic IR validator | `rust/airo_mind_meeting/src/validate.rs` | Present; issue still open for remaining ACs | #1634 |
| Device-tier local/cloud routing | `packages/core_ai/lib/src/device_tier/` | Present | #1631 |
| Model selection / Intelligence query | `packages/core_ai/lib/src/intelligence/` | Present | related #497 |
| Flutter generation bridge | `packages/feature_mind/lib/src/bridges/mind_generation_bridge.dart` | Present; already accepts optional GBNF | #1638 |
| Assistant tool loop (Dart) | `AgentSkillOrchestrator` | Present; Dart-side, skill-scoped | — |
| Keyword intent map | `intent_parser.dart` | Present; **not** the V1 classifier | — |
| Chat-over-meetings | planned | Open | #1789 |
| Apple Foundation Models backend | planned | Open | #1640 |
| Coins constrained-extraction seam | planned; depends on Mind last mile | Open | #1644 |
| Phase 9 generic extraction/summarisation | later Mind runtime AI | Open, blocked | #1202 |

### Local dirty tree (NOT in this worktree)

The original `/Users/udaychauhan/workspace/airo` checkout has **uncommitted** Dart last-mile helpers that are absent from `origin/main`:

- `packages/core_ai/lib/src/generation/generation_constraint.dart`
- `packages/core_ai/lib/src/generation/gbnf_grammar.dart`
- `packages/core_ai/lib/src/generation/prompt_inertia_guard.dart`
- `packages/core_ai/lib/src/generation/scalar_constraint_kind.dart`

Treat those as a **source to port**, not as landed architecture. Port the portable pieces (forced-prefix GBNF, prompt-inertia masking) into this branch when Slice 2 needs them. Do not merge the rest of that dirty tree.

### Explicitly reject / reframe

| Issue / idea | Action |
|---|---|
| #271 Thinking Mode (raw CoT stream, Gallery `partialThinkingResult`) | **Supersede.** Replace AC with Reasoning progress UI. Keep capability gating (`model supports structured/reasoning`) but never show scratchpad tokens. |
| Dart `lib/core/reasoning/` as the engine | **Reject.** Thin facade only. |
| `result.thoughts` on the SDK | **Reject.** |
| Persisting raw thought traces | **Reject.** |
| Flutter calling Qwen/llama/MLX directly | **Reject.** Already true for generation; keep it true for reasoning. |
| Keyword-only routing as the permanent policy | **Reject as destination.** Allowed only as a temporary fixture in tests. |

---

## The last-mile tick list (this is the CoT acceptance bar)

Airo already planned last mile as: context engineering + intent + deterministic output. CoT is **one checkbox on that bar**, not a parallel track.

For a Reasoning Engine slice to count as done for last mile, all of these must be true:

- [ ] **Intent first.** `reason()` is never called with a raw string alone. Request carries classified intent + complexity.
- [ ] **Level from policy, not from the model.** `none | light | standard | deep`, overridable, device-clamped.
- [ ] **Relevant context only.** Memory / calendar / tasks / docs / tool results packed into `ReasoningContext`. No whole-database dump.
- [ ] **Prompt strategy by level.** Direct vs standard vs deep. No one giant CoT system prompt.
- [ ] **Constrained generation where the output is structured.** GBNF/schema for machine-readable fields (tool calls, confidence, summary). Free text only for the user-facing answer body when the level is `none`/`light`.
- [ ] **Internal reasoning is discarded.** If the model emits a thinking channel or tagged scratchpad, the parser strips it. Only `reasoning_summary` (short, user-facing) survives.
- [ ] **Validate before persist.** Schema-valid or typed failure. No free-text leak into structured fields (same contract as #1644).
- [ ] **Progress events, not tokens-as-thoughts.** UI sees stages (`understanding`, `retrievingContext`, `usingTool`, `analyzing`, `validating`, `composingAnswer`).
- [ ] **Same API on every platform.** A test with a fake `GenerationEngine` must pass on host without Metal/NNAPI/CoreML.

If a PR adds `<thought>` rendering and nothing else, it fails this bar.

---

## File map (new vs reuse)

### Create

```text
rust/airo_mind_reasoning/
  Cargo.toml
  src/lib.rs
  src/level.rs          # ReasoningLevel
  src/policy.rs         # device-aware evaluate()
  src/request.rs        # ReasoningRequest
  src/context.rs        # ReasoningContext
  src/prompt.rs         # ReasoningPromptStrategy
  src/parser.rs         # stream → events; strip internal scratchpad
  src/validator.rs      # structured fields
  src/engine.rs         # AiroReasoningEngine::reason() -> event stream
  src/event.rs          # ReasoningEvent
  src/result.rs         # ReasoningResult (no thoughts field)
  tests/policy.rs
  tests/parser.rs
  tests/engine_fake.rs  # fake GenerationEngine, no GGUF

packages/feature_mind/lib/src/reasoning/   # thin Dart facade + UI only
  reasoning_event.dart
  reasoning_bridge.dart
  presentation/thinking_progress.dart
```

### Modify (do not fork)

- `rust/airo_mind_core/src/engine.rs` — only if the event sink needs a documented extension; prefer composing on top.
- `packages/feature_mind/lib/src/bridges/mind_generation_bridge.dart` — add `reason()` stream beside `generate()`.
- `packages/feature_mind/lib/src/agent_chat/presentation/screens/chat_screen.dart` — render events; collapse Thinking.
- Persistence path used by assistant chat — add summary/level columns, never a thoughts blob.
- `docs/adr/` — ADR for Reasoning-as-capability (required because this is a new crate + Flutter contract).

### Do not touch in V1

- llama.cpp / whisper.cpp build wiring (#1655)
- Apple FM backend (#1640) — Reasoning must run against a fake engine first; Apple is a later `GenerationEngine` impl
- Meeting IR schema
- Vault primitives

---

## Phased slices

Each slice is a mergeable PR. Vertical: contract + tests first, then one real path.

### Slice 0 — ADR + GitHub epic (no product code)

**Files:** `docs/adr/00XX-airo-mind-reasoning-engine.md`, GitHub epic + child issues.

**Acceptance:**
- [ ] ADR records: capability crate (not runtime primitive), Flutter event API, no raw CoT persistence, CoT is last-mile tick, platform matrix.
- [ ] Epic opened under milestone 26 (or a named "Mind Reasoning" milestone), labelled `agent/ai-llm`, `on-device`, `pro` if it ships via overlay.
- [ ] #271 marked superseded / blocked-on this epic with the new AC.
- [ ] #1644 noted as a *consumer* of the same constrained-generation contract, not a second engine.
- [ ] #1202 left later (Phase 9 graph writes). Reasoning V1 does not get silent write access to the vault.

### Slice 1 — Core types + policy (the CoT tick starts here)

**Files:** `rust/airo_mind_reasoning` types + policy tests. No GGUF.

- [ ] **Step 1: Write failing tests** for `ReasoningPolicy::evaluate`

```rust
#[test]
fn direct_lookup_is_none() {
    let level = ReasoningPolicy::default().evaluate(&request_with_intent("calendar_retrieval", 0.1));
    assert_eq!(level, ReasoningLevel::None);
}

#[test]
fn planning_high_complexity_is_deep() {
    let level = ReasoningPolicy::default().evaluate(&request_with_intent("planning", 0.88));
    assert_eq!(level, ReasoningLevel::Deep);
}

#[test]
fn requested_level_wins_unless_device_clamps() {
    let mut req = request_with_intent("planning", 0.88);
    req.requested_level = Some(ReasoningLevel::Deep);
    let profile = DeviceInferenceProfile { thermal_constrained: true, ..small_phone() };
    assert_eq!(
        ReasoningPolicy { device: profile }.evaluate(&req),
        ReasoningLevel::Standard
    );
}
```

- [ ] **Step 2: Implement** `ReasoningLevel`, `ReasoningRequest`, `ReasoningPolicy` with thresholds 0.25 / 0.55 / 0.85 and `_is_direct_lookup`.
- [ ] **Step 3:** `cargo test -p airo_mind_reasoning` green.
- [ ] **Step 4: Commit** `feat(mind): add reasoning policy and levels`

**CoT tick in this slice:** policy exists so we never pay for thinking on "what time is it?".

### Slice 2 — Prompt strategy + constrained result schema

- [ ] Direct / standard / deep prompt builders. No single mega CoT prompt.
- [ ] Result envelope GBNF: `{ answer, reasoning_summary, confidence }` — summary max length enforced in grammar.
- [ ] `none` level: skip the LLM when a tool/direct answer exists; otherwise unconstrained short answer, no summary required.
- [ ] Fake `GenerationEngine` tests: given a scripted JSON body, validator accepts; given extra `thoughts` field, validator strips/rejects (fail closed on unknown structured keys).
- [ ] Port `PromptInertiaGuard` behaviour into this crate or `core_ai` *only if* chat history is in the request (do not block Slice 2 on the dirty-tree files).
- [ ] Commit `feat(mind): constrain reasoning output schema`

**CoT tick in this slice:** the model may think internally; the grammar does not admit a `thoughts` field.

### Slice 3 — Engine loop + events (still fake backend)

- [ ] `AiroReasoningEngine::reason(request) -> impl Iterator/Stream<ReasoningEvent>`
- [ ] Events: `Started`, `StageChanged`, `Progress`, `AnswerDelta`, `Completed`, `Error`. Tool events stubbed until Slice 5.
- [ ] Parser maps token stream → answer deltas; never forwards scratchpad.
- [ ] Max 1 generation call for `light`/`standard`; `deep` may use 2 (draft + validate) but not a free loop yet.
- [ ] Commit `feat(mind): stream reasoning events from rust engine`

### Slice 4 — Wire real `GenerationEngine` (no inference rewrite)

- [ ] Adapter: reasoning crate calls `Supervisor` / `&dyn GenerationEngine` exactly as `airo_mind_meeting` does.
- [ ] Desktop path: existing `LlamaGenerationEngine` + optional grammar.
- [ ] Host test with the checked-in tiny GGUF *only* if `AIRO_LLAMA_MODEL` is present; otherwise skip like `generation_offline.rs`.
- [ ] Dart facade: `MindGenerationBridge.reason(...)` streams the same events.
- [ ] Commit `feat(mind): run reasoning over existing generation engine`

### Slice 5 — Context package

- [ ] `ReasoningContext` assembly from conversation history + injected `ContextItem`s (memory, calendar, tasks, documents, tool results).
- [ ] Reuse existing assistant context builder *as a supplier of items*, not as the engine.
- [ ] Prompt includes only packed context, with a hard token budget from `DeviceInferenceProfile`.
- [ ] Commit `feat(mind): pack reasoning context with a token budget`

### Slice 6 — Tool loop (cap 5)

- [ ] Parse tool-call envelope from constrained output.
- [ ] Execute via existing tool registry (calendar, tasks, memory). Do not duplicate `AgentSkillOrchestrator` tools; share definitions.
- [ ] `ToolStarted` / `ToolCompleted` events.
- [ ] Hard stop at 5 iterations; emit `Error` with a user-safe message.
- [ ] `none` level: at most one tool, then answer, no second LLM call if the tool result is the answer.
- [ ] Commit `feat(mind): add bounded reasoning tool loop`

### Slice 7 — Flutter Thinking UI

- [ ] Collapsible "Thinking · N steps" using `StageChanged` / `Progress` only.
- [ ] Answer streams via `AnswerDelta`.
- [ ] No control that dumps raw tokens. No #271 toggle labelled "show thinking" that reveals scratchpad.
- [ ] Desktop + compact phone layouts (same widget, responsive).
- [ ] Commit `feat(mind): render reasoning progress without raw CoT`

### Slice 8 — Persistence

- [ ] Store answer + summary + level + tool_calls + timestamp.
- [ ] Reload after process restart shows summary, never a thought trace.
- [ ] Golden test: round-trip fixture has no `thought` / `scratchpad` keys.
- [ ] Commit `feat(mind): persist reasoning summary not traces`

### Slice 9 — Device adaptation (policy, not a new runtime)

- [ ] Map `LlmDeviceTier` → max `ReasoningLevel` and model size bias (`IntelligenceSizeBias`).
- [ ] MacBook / Windows workstation: deep allowed.
- [ ] Low-memory Android / thermally limited iPhone: clamp to light/standard.
- [ ] iPad: standard, deep if `large` tier.
- [ ] Tests for every tier. No platform `#ifdef` in the reasoning crate.
- [ ] Commit `feat(mind): clamp reasoning level by device tier`

---

## Platform contract (V1)

| Layer | macOS | Windows | Android | iOS | iPadOS |
|---|---|---|---|---|---|
| Flutter UI | Same | Same | Same | Same | Same |
| Reasoning crate | Same | Same | Same | Same | Same |
| Policy / prompt / parser / validation | Same | Same | Same | Same | Same |
| Persistence API | Same | Same | Same | Same | Same |
| `GenerationEngine` impl | llama.cpp Metal | llama.cpp CPU/CUDA seam | llama.cpp or LiteRT (still #1628 registry) | Apple FM (#1640) and/or GGUF | same as iOS |
| Model | device catalog | device catalog | quantized catalog | on-device / FM | on-device / FM |
| V1 proof | host `cargo test` + macOS GGUF smoke | host tests; CUDA later | fake engine + Android FFI when #1638/#1655 allow | fake engine until #1640 | same as iOS |

V1 is **API-complete on all five**. Hardware acceleration per platform stays on the existing MIND-LLM issues. Reasoning must not wait for Apple FM or Windows CUDA to merge the crate.

---

## GitHub issue plan (create in Slice 0)

Do not silently expand #1627 with a ninth workstream in the description without a child issue.

**New epic:** `[EPIC] [MIND-REASON] Cross-platform Reasoning Engine`  
Depends on: #1628 (GBNF + engine — largely done), #1631 (tiers).  
Related: #1644 (Coins consumes the same constrained contract), #1789 (chat over meetings uses the engine), #497 (model routing), #1638 (Flutter seam).

**Children (suggested numbers after filing):**

| ID | Title | Maps to |
|---|---|---|
| MIND-REASON-1 | ADR + types + policy | Slices 0–1 |
| MIND-REASON-2 | Prompt strategy + result GBNF (CoT last-mile tick) | Slice 2 |
| MIND-REASON-3 | Event stream + parser (discard scratchpad) | Slice 3 |
| MIND-REASON-4 | Wire `GenerationEngine` + Dart facade | Slice 4 |
| MIND-REASON-5 | Context pack | Slice 5 |
| MIND-REASON-6 | Tool loop cap=5 | Slice 6 |
| MIND-REASON-7 | Thinking progress UI | Slice 7 |
| MIND-REASON-8 | Persistence without raw CoT | Slice 8 |
| MIND-REASON-9 | Device-tier clamp | Slice 9 |

**Close/reframe:** #271 → "Superseded by MIND-REASON-7; raw thinking stream will not ship."

---

## Verification (narrow, per WORKFLOW)

Host-only until a slice touches UI:

```bash
cargo test -p airo_mind_reasoning
cargo test -p airo_mind_core
# when Dart facade exists:
cd packages/feature_mind && dart test test/reasoning
```

Do not run the full Melos matrix or GitHub Actions for iterative commits. Name the environment `host-only` on the issue until Slice 7, then macOS desktop for the Thinking UI.

---

## Risks

| Risk | Mitigation |
|---|---|
| Relitigating Dart vs Rust mid-implementation | Locked above; ADR in Slice 0 |
| #271 implemented in parallel as Gallery thinking | Block/supersede immediately |
| Dirty local `core_ai` generation files accidentally mixed in | This worktree is clean `origin/main`; port only named files |
| Reasoning crate grows domain knowledge (medical/legal) | Runtime freeze: capability owns domain; engine stays generic |
| Tool loop runaway | Hard cap 5 + `none` short-circuit |
| Waiting on Apple FM / Android NPU | Fake `GenerationEngine` unblocks all policy/parser/UI tests |

---

## Open questions (do not block Slice 1)

1. Public vs pro overlay: does `airo_mind_reasoning` live in public `rust/` (like `airo_mind_meeting`) or only airo-pro? **Recommendation:** public crate, same as meeting — it is framework intelligence, not a product plugin.
2. Classifier: small on-device intent model vs constrained extract vs keeping the phrase map for `none`-level shortcuts only. **Recommendation:** Slice 1 accepts `ClassifiedIntent` as input so the classifier can land separately.
3. Whether `deep` uses two generation passes in V1 or one pass with a deeper prompt. **Recommendation:** one pass in V1; two-pass is Slice 3+ only if evals fail.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-21-airo-mind-reasoning-engine.md`.

**1. Subagent-Driven (recommended)** — Slice 0 (ADR + issues) then Slice 1 types/policy.

**2. Inline Execution** — same order in this session.

Do not start Slice 2 until Slice 0's ADR is drafted; the crate location (public `rust/` vs overlay) is the one decision that is expensive to move later.
