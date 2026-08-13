# Implementation Plan: Airo Coins On-Device Intelligence (Milestone 27)

Epic: [#1643](https://github.com/DevelopersCoffee/airo/issues/1643). All feature code ships in the **airo-pro** overlay (pro label); public repo gets seam widening + stubs only.

## Overview

On-device LLM finance features for Airo Coins built on the Mind LLM runtime (milestone 26). Non-negotiable pattern: **LLM extracts intent; deterministic code computes** — no model arithmetic, no free SQL, no unvalidated numbers, every output grammar/schema-constrained and code-validated.

## Architecture decisions (settled — do not re-litigate)

- Runtime is Mind's (#1628 LlmBackend, #1630 model manager, #1631 tiering, #1638 Flutter seam, #1640 Apple FM). Coins consumes via one seam (#1644); zero duplicate inference infra.
- Single-turn constrained extraction only. No multi-step agentic tool calling (supersedes #941's tool loop — sub-7B tool-call reliability).
- NL search = closed filter DSL, never text-to-SQL.
- Categorization = embeddings/kNN primary; LLM cold-start fallback only; per-merchant verdict cache.
- Subscription/anomaly detection deterministic; LLM fills narration template slots only.
- Insights descriptive, never prescriptive. Vault items unreachable from any LLM path.
- Models: Qwen3 4B / Gemma 3 4B class with grammar constraints; Apple Foundation Models on iOS 26+. Gemma 1B marginal — bench, don't assume.
- Non-goals: coaching chatbot, forecasting, agentic tools, free text-to-SQL.

## Cross-milestone dependency

#1644 is **blocked on Mind #1628 + #1638** (both open, milestone 26). Phase 0 is deliberately LLM-free so milestone 27 progresses in parallel.

## Task list

### Phase 0 — unblocked now (parallel)
- [ ] #257 Receipt OCR production hardening (build cleanup, fixtures, CI) — **delegate: cheap model**; spec already precise
- [ ] #1649a Deterministic recurrence/anomaly detector + synthetic-ledger tests — **delegate: cheap model**; pure logic, TDD
- [ ] #1648a Embeddings + kNN categorization, correction loop, merchant cache — **delegate: cheap model**; measurable vs regex baseline
- [ ] #1650a Golden datasets (50 split utterances, receipt corpus, 40 search Qs, labeled merchants) + harness scaffold on mock backend — **delegate: cheap model**, dataset review by Claude
- [ ] #1653a UX design doc (NL entry, draft-confirm, digest, trust cues) — **Claude + chief-ux-officer review**; then UI shells vs mock service — delegate

### Checkpoint: Phase 0
- [ ] Harness green on mocks; detector + embeddings ≥ baselines; design doc approved; #257 closed

### Phase 1 — foundation (gated on Mind #1628/#1638)
- [ ] #1644 Extraction contract ADR + `CoinsExtractionService` seam — **Claude** (contract, security boundary, failure taxonomy); implementation delegable after ADR freeze
- [ ] #1652 Coins flavor wiring: pubspec_coins overlay, registerProModules, entitlement gate, feature flags, web/low-tier stubs — **delegate: cheap model** against frozen seam

### Checkpoint: Phase 1
- [ ] Extraction round-trip on Pixel 9; coins flavor builds with AND without pro overlay; `flutter build web --release` green

### Phase 2 — features (after #1644; strict value order, one at a time per iterative-dogfood policy)
- [ ] #1645 NL bill-split entry — dogfood on rig before next
- [ ] #1646 Receipt LLM structuring layer (deterministic parser stays first-pass)
- [ ] #1647 NL search filter DSL + executor
- [ ] #1648b LLM cold-start fallback (completes categorization)
- [ ] #1649b Narration layer (completes digest)

All Phase-2 issues: **delegate implementation** against #1644 contract + #1650 golden sets; Claude reviews schema/validation edges; per-feature gate = its golden set passes in airplane mode.

### Phase 3 — exit gate (all required before milestone close)
- [ ] #1650b Full model-tier eval runs on device rig (Qwen3 4B / Gemma 3 4B / Apple FM)
- [ ] #1651 Egress tests, disclosure screens, store-claim doc — **Claude + chief-security-officer** (claim wording legal-sensitive)
- [ ] #1654 Rig dogfood + perf/thermal/battery budgets signed — physical rig only (Pixel 9 + iPad; FLAG_SECURE → uiautomator evidence)

## Delegation model

Per standing workflow: Claude owns contracts/ADRs/security-sensitive scope (#1644 ADR, #1651, #1653 design doc, dataset review); cheaper models (Codex / Sonnet subagents) implement well-specified issues (#257, #1648a, #1649a, #1650a, #1652, all Phase-2 features post-ADR). Every issue body is delegation-ready (context, scope, acceptance, council owners).

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Mind #1628/#1638 slip | High — Phase 1+ blocked | Phase 0 is LLM-free; escalate to milestone 26 if idle |
| 4B model too slow on mid-tier Android | High | #1654 budgets early; #1631 tier gates; Apple FM on iOS |
| Extraction F1 below bar on Hinglish/multilingual | Med | #1650 datasets include from day one; re-prompt + manual fallback ladder |
| Grammar-constrained decoding unsupported in chosen runtime path | Med | Verify in #1644 spike before ADR freeze (GGUF grammar / Apple guided gen) |
| Pro overlay drift vs public stubs | Med | #1652 dual-build CI check (with/without overlay) |

## Open questions

- Does #1649 detector live public (non-pro) with only narration pro? Decide at package review.
- Coins standalone app id vs phone-flavor Coins tab — which surface ships AI first? (affects #1653 nav)
