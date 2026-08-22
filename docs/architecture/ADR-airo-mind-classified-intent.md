# ADR-0003: ClassifiedIntent is Airo Mind's routing contract

Status: Accepted
Date: 2026-08-22

## Status governance

This ADR sits **beside** [ADR-0001](./ADR-airo-runtime-planner.md) and
[ADR-0002](./ADR-airo-mind-reasoning-engine.md). It does not add an eighth
runtime primitive, a second inference stack, or a Flutter-owned brain.
Changes to the intent contract require a new ADR or a reviewed versioned
amendment.

Epic: [#1827](https://github.com/DevelopersCoffee/airo/issues/1827).

## Rationale

Airo Mind still classifies chat with a keyword `IntentParser` and then
sends `{ kind, complexity }` into reasoning. That wire is too thin: diet and
routine both collapse to `planning`, the router never sees documents or
conversation, and an LLM that merely *infers* a plausible intent can start
doing work.

The permanent path is:

```text
User input → normalize / context → analyzer (LLM / SLM / hybrid)
    → ClassifiedIntent → validate + confidence + action-readiness
    → CLASSIFIED | NEEDS_CLARIFICATION | REJECTED
    → IntentRouter → CapabilityRegistry → orchestrator / model profile
```

Keyword `IntentParser` is **legacy compatibility**. It may only emit a
`ClassifiedIntent` against the registry. It cannot define capabilities, skip
the gate, or invoke tools.

## Decision

1. **`ClassifiedIntent` is the stable internal contract** (`schema_version`
   `1.0`), owned by `rust/airo_mind_intent`. Taxonomy is
   `domain + intent + action`, not a flat enum. Confidence is
   multi-dimensional. Action readiness is first-class:
   `Inference ≠ Authorization` and `Intent ≠ Execution`.
2. **Three routing layers**, separate: intent (what), capability/orchestrator
   (who), model profile (which generator). The router inspects the contract
   and the registry — never the user string.
3. **Three-way gate:** `classified` / `needs_clarification` / `rejected`.
   Underspecified action requests ask one focused question. Clear requests
   (explicit calendar create, a selected skill) proceed.
4. **Capability registry is the source of truth.** Analyzers select from it.
   They must not invent ids. **Product plugins are not registry domains.**
   Diet, coins, and similar journeys are skills: they route through
   `skill.execute` and run in `feature_mind` / `AgentSkillOrchestrator`.
5. **Classifier backends are replaceable.** Phase 1 hydrates the contract from
   the legacy kind adapter. Later analyzers (`GenerationEngine` structured
   output, then a local SLM) must emit the same schema. Do not add a
   `ChatService` / `ChatProvider` trait — reuse `GenerationEngine`.
6. **Flutter consumes decisions.** Product skills (`AgentSkillOrchestrator`)
   stay Dart until those journeys are registry capabilities. They must not
   grow new Mind routing rules.

## Hard invariant

The model must never initiate an external action merely because it inferred
a plausible intent. Execute only when confidence and margin pass, required
parameters are present, the action is unambiguous, policy permits it, and
confirmation is not required. Otherwise ask.

## Non-goals

- Copying IntentGuard (topical allow/deny) or Plano (proxy data plane) as
  the domain contract. Adopt uncertainty/margin and domain/action routing
  *patterns* only.
- DeBERTa, finance/health/legal verticals, keyword routing as the primary
  classifier.
- LLM-direct tool execution, raw CoT as a contract, provider lock-in.
- Document ingestion, cost/latency routers, shadow-mode dual-run, FRB
  `classify()` — later phases against this same schema.
- Treating LLM-emitted `0.93` as calibrated probability.
- First-class product domains (`diet.*`, coins, games) in the intent
  registry. Those are skills/plugins.

## Consequences

- `airo_mind_reasoning::ClassifiedIntent` becomes the v1 contract (legacy
  `kind` / `complexity` remain compatibility fields).
- Application plugins (diet meal plans, etc.) map to `skill.execute`, never
  a `diet.*` capability.
- Analyzer coverage replaces the keyword parser; the parser is deleted only
  after evals say so.

## Related

- ADR-0002: reasoning is a capability that *consumes* this contract.
- Crate: `rust/airo_mind_intent`
