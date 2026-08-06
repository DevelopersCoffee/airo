# Airo Mind — single source of truth

Gate file for `agent-skills:build auto`. Content lives where this repo's specs
and plans already live — this file only points at it, per `docs/agents/CONTEXT_ENGINEERING.md`'s
rule against a second rules file.

## Objective

Unify "Airo Mind" into one product: one package (`feature_mind`), one route
namespace (`/mind`), one model-acquisition pipeline (download, not bundled, in
both the super app and the standalone app), behind swappable abstractions
(`ModelProvider`, `MindSpeechBridge`, `MindGenerationBridge`).

## Specs

- `docs/superpowers/specs/2026-08-06-airo-mind-journey-coverage.md` — the
  engine-bridge seam (`MindSpeechBridge`/`MindGenerationBridge`) and the T3–T8
  test list it unblocks, restoring coverage `#1549` removed.
- `docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md` —
  `ModelProvider` (model acquisition) and the same engine bridges, landed
  together because both replace a concrete dependency in the same window.

## Plan

- `docs/superpowers/plans/2026-08-07-airo-mind-ssot-plan.md` — phases 0–4,
  dependency graph, decisions taken, risks. **Approved.**
- `docs/superpowers/plans/2026-08-07-airo-mind-ssot-todo.md` — the task
  checklist `/build auto` executes, in order. Phase 0 is done and verified on
  device; not yet committed.

## Boundaries

- `ADR-0018 §1` (runtime never acquires models) and `ADR-0021` (frozen
  `MindRuntime` port) are not renegotiable by this work — see the plan's
  "Hard constraints" section.
- Merging `feature_assistant` into `feature_mind` (plan Phase 2) puts the
  assistant hub under R05 (private-devices only), removing it from web and TV.
  Accepted per the plan's Checkpoint 2 — do not silently proceed past it
  without the stated council sign-off.
