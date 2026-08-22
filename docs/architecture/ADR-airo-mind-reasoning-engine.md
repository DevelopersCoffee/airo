# ADR-0002: Airo Mind Reasoning Engine is a capability, not a runtime

Status: Accepted
Date: 2026-08-22

## Status governance

This ADR sits **beside** [ADR-0001](./ADR-airo-runtime-planner.md). It does
not add an eighth runtime primitive, a second inference stack, or a
Flutter-owned brain. Architectural changes to the reasoning contract require a
new ADR or a reviewed versioned amendment, same freeze rule as ADR-0001.

Supersedes GitHub [#271](https://github.com/DevelopersCoffee/airo/issues/271)
(Gallery-style raw thinking stream / `partialThinkingResult`) for product
behaviour. Epic: [#1827](https://github.com/DevelopersCoffee/airo/issues/1827).
#271's capability-gating intent survives as `DeviceInferenceProfile` +
model-ready checks; its scratchpad UI does not.

## Rationale

Airo Mind chat was streaming unconstrained tokens from whichever local runtime
was loaded. Users need structured, intent-driven answers with a short
user-facing progress summary — not a dump of the model's private chain of
thought.

The last-mile product is: classified intent → packed context → constrained
generation → validate → synthesise. Chain-of-thought is one **internal** tick
on that last mile (`standard` / `deep` prompts). It is not a stored field, not
a public SDK `thoughts` API, and not a Gallery-style thinking toggle.

## Alternatives considered

### Dart `lib/core/reasoning/` as the engine
- Pros: Faster to ship on Flutter-only paths; no FRB churn.
- Cons: Duplicates policy per client; blocks CLI/desktop/Android FFI from
  sharing one brain; violates "Rust is the source of truth" from ADR-0001.
- Rejected.

### New `InferenceEngine` trait next to `GenerationEngine`
- Pros: Could name reasoning-specific generate knobs.
- Cons: Meeting intelligence already drives `&dyn GenerationEngine`. A second
  trait is a second stack.
- Rejected. Reuse `GenerationRequest.grammar`, `LlamaGenerationEngine`,
  `Supervisor`.

### Implement #271 as written (`partialThinkingResult`)
- Pros: Matches Google AI Edge Gallery UX; Gemma 4 thinking channel.
- Cons: Persists or displays a private scratchpad; trains users to inspect
  raw CoT; conflicts with constrained last-mile output.
- Rejected. Progress events (`StageChanged` / `Progress` / `ToolStarted`)
  replace the thinking stream. Answer tokens travel only as `AnswerDelta`.

### Platform `cfg` inside `airo_mind_reasoning`
- Pros: Could clamp Android/iPhone without a Dart probe.
- Cons: Capability crates must stay OS-blind (`C5`). Device limits arrive as
  `DeviceInferenceProfile`.
- Rejected.

## Non-goals

- Apple Foundation Models (`#1640`) and LiteRT-as-`GenerationEngine` (`#1628`
  registry). Same `reason()` API; those are later backends.
- Rewriting `AgentSkillOrchestrator`. Product skills stay Dart; reasoning
  tools are a bounded loop (cap 5) over lookup connectors.
- iOS `ffiPlugin` enablement (`#1546` ggml ODR).
- Silent vault writes (`#1202`).
- Keyword `query.contains("plan")` as the permanent router. Policy takes
  `ClassifiedIntent` from [ADR-0003](./ADR-airo-mind-classified-intent.md).

## Decision

Reasoning is an **Airo Mind capability crate** (`rust/airo_mind_reasoning`),
the same layer as `airo_mind_meeting`:

```text
Flutter UI  ──FRB──►  airo_mind_reasoning
                         │  policy, context, prompt, parse, validate, tools
                         ▼
                   GenerationEngine  (domain-free)
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    llama.cpp         Apple FM       LiteRT / other
    macOS/Win/        iOS/iPad       Android (later)
    Android GGUF
```

The boundary rule:

> Flutter calls `reason(request)` and renders `ReasoningEvent`. Rust owns
> policy, prompt, GBNF, parse, validate, and the tool loop. Only the
> `GenerationEngine` implementor and the loaded model change per platform.

Persist `answer` + `reasoning_summary` + `level` + `tool_calls`. Never
`thoughts`, `scratchpad`, `raw_thoughts`, or `partialThinkingResult`.

## Platform contract (V1)

| Layer | macOS | Windows | Android | iOS | iPadOS |
|---|---|---|---|---|---|
| Flutter UI / `reason()` API | Same | Same | Same | Same | Same |
| `airo_mind_reasoning` | Same | Same | Same | Same | Same |
| `GenerationEngine` impl | llama.cpp Metal | llama.cpp CPU/CUDA seam | llama.cpp FRB (`airo_mind_llama`); JNI is fallback only | Apple FM / GGUF later | same as iOS |

V1 is API-complete on all five. Hardware backends stay on existing MIND-LLM
issues. Fake `GenerationEngine` tests prove the capability without GGUF.

## Consequences

- `feature_mind` stays presentation + host probes + lookup-tool execution.
  Calendar verbs live in Dart; the engine parses `tool_calls` and either
  executes a `ToolExecutor` or hands the envelope back for the host loop.
- Chat history schema v1 stays additive. Do not bump the version or old
  transcripts are wiped.
- #271 is closed as superseded by this ADR and
  [#1827](https://github.com/DevelopersCoffee/airo/issues/1827).
  #1644 (Coins constrained extraction) is a **consumer** of the same
  last-mile contract, not a second engine.
- #1202 (Phase 9 graph writes) stays later.

## Related

- Architecture report: `docs/features/airo-mind/REASONING_ENGINE_ARCHITECTURE_REPORT.md`
- Implementation plan: `docs/superpowers/plans/2026-08-21-airo-mind-reasoning-engine.md`
- GitHub epic: [#1827](https://github.com/DevelopersCoffee/airo/issues/1827)
- Remaining iOS backend: [#1828](https://github.com/DevelopersCoffee/airo/issues/1828)
- Intent contract: [ADR-0003](./ADR-airo-mind-classified-intent.md)
