# Mind chat turn inspector

**Date:** 2026-08-21
**Status:** Draft design, awaiting human review. No implementation until this file is approved.
**Parents:** #386 redacted trajectory, #523 assistant runtime tracing
**Related:** #15 (external crash/telemetry, still blocked on consent — out of scope), #73 AI metrics epic (closed; Health Center covers model lifecycle, not chat turns)
**Proving thread:** User “Make me a 7 day diet plan” → bubble stuck at “Here” → User “i cant see the full response” → full 7-day plan

## Critical Agent gate

**Problem:** A developer cannot reconstruct one Mind chat turn: which runtime ran, which plugin/skill fired, what prompt the model actually received, whether GBNF was attached, and why generation stopped. The diet thread looked like a model failure. It was a stream abort plus a second completion.

**User / actor:** Developers hardening prompts and runtimes on-device (Mind macOS, Android, iOS). Not end-user analytics.

**Framework or application layer:** Mixed. Framework owns the turn-trace contract. Application owns the bubble sheet and persistence next to chat history.

**Owning agent:** Framework Agent (`core_ai` trace contract). Application / Brain agent (`feature_mind` inspector UI).

**Reviewing agents:** Chief Security Officer, Chief QA Officer, Chief Architect, Product Manager (`feature_mind`).

**Impacted modules:** `packages/core_ai` (extend #386), `packages/feature_mind` chat screen / history store / runtime service. `core_native` `ExecutionTrace` is consumed, not redesigned.

**Open questions resolved in planning:**
- Extend #386 + #523, do not invent a parallel stack.
- Per-bubble inspector, not a global last-N console.
- No Sentry / #15 until consent and credentials exist.

**Decision:** Ready for spec review. Not ready for code.

## Goal

Every user send that reaches generation or skill orchestration gets a stable `run_id`. The assistant bubble can open one inspector that shows, in order: routing, plugin/skill, prompt refs, constraint, stream lifecycle, and stop reason. The diet abort and the follow-up completion are two runs, not one confused bubble.

## What already exists (do not duplicate)

| Piece | Where | Gap |
|---|---|---|
| `AiTrajectoryTrace` / builder / redactor | `core_ai`, spec `docs/specs/redacted-trajectory-tracing.md` | Chat never records a run. Schema is skill/tool shaped. |
| `AssistantRuntimeDebugTrace` | `assistant_runtime_service.dart` | `debugPrint` + optional emitter. Not on the bubble. Previews only. |
| `ChatResponseMetadata` + “Response details” sheet | `chat_screen.dart` `_showMetadataSheet` | Attached **after** a completed generate. Abort leaves no chip. History restore drops it. `finishReason` defaults to `stop`. No plugin, grammar, inertia, or node timeline. |
| `AgentActionTrace` chip | `SkillActionTraceCard` | Device/tool actions only. Diet generate has none. |
| `ExecutionTrace` | `core_native` | Health Center model lifecycle. Not keyed to a chat `run_id`. |
| `ChatHistoryStore` v1 | SharedPreferences, text + isUser + timestamp | No `run_id`. Traces die with the process. |

The inspector **is** the existing Response details sheet, expanded and attached for incomplete turns. Do not ship a second debug surface.

## Out of scope

- Sentry, Crashlytics, cloud dashboards (#15).
- Changing diet prompt / GBNF policy (already a separate framework slice).
- Auto-retry of aborted streams (follow-up UX). Recording the abort is in scope; rewriting the bubble copy to “generation interrupted” is a small application follow-up after the inspector can prove abort.
- Encrypted vault storage of full prompts for production users.
- Cross-device sync of traces.

## Cross-agent contract

**Provider:** Framework Agent.
**Consumers:** Mind chat (`feature_mind`), later any Brain surface that calls local generation.

**Interface (new, `core_ai`):** `ChatTurnTrace` wrapping, not replacing, `AiTrajectoryTrace`.

```
ChatTurnTrace
  schema_version: 1
  run_id: string                    // uuid, one per user send that enters orchestration or generate
  parent_run_id: string?            // if this turn is a retry / continuation of an aborted run
  started_at / ended_at: iso8601
  lifecycle: started | first_token | streaming | finished | aborted | failed
  stop_reason: eos | max_tokens | user_cancel | process_killed | engine_error | empty_output | unknown
  runtime_id: string                // e.g. offline-gemma-2b-it-q4
  routing: local | cloud | unavailable
  plugin_id: string?                // e.g. draft-diet-plan
  skill_id: string?                 // null when plugin generate, not a device skill
  constraint: { gbnf_attached: bool, prefix_hash: string? }
  inertia: { kinds: [{ id, previous, current }] }
  stats: { prefill_ms?, generated_tokens?, max_output_tokens?, time_to_first_token_ms? }
  trajectory: AiTrajectoryTrace     // #386 nodes, redacted summaries + refs
  prompt_ref / system_ref / answer_ref: local://turn/{run_id}/...
```

**Input shape:** chat orchestration starts a builder at send; runtime and plugin layers append nodes; stream end / dispose / cancel finalizes lifecycle.

**Output shape:** JSON-safe `ChatTurnTrace.toJson()`. Raw prompts live behind refs, never in node summaries.

**State changes:** local trace store keyed by `run_id`. Chat history v2 stores `run_id` on assistant entries. Trace emission must not block or fail generation.

**Errors:** builder records `failed` + stable `errorCode`. Inspector still opens.

**Permissions:** none. Local only.

**Privacy / redaction:** default store is redacted (#386 `AiTraceRedactor`). Full prompt/system/answer payloads are written only when `kDebugMode` **or** an explicit developer toggle “Store full prompts on device” is on. Diet text is health-adjacent; redactor already strips named health terms from summaries. Full payloads stay on device and are wiped with chat clear.

**Persistence:**
- `ChatHistoryStore` schemaVersion 2: assistant entries may include `runId`. v1 loads ignore unknown fields / missing runId.
- Separate `ChatTurnTraceStore` (`airo_mind.chat_turn_traces.v1`), max 200 traces, same cap as history. Clear chat clears traces.
- Do not put full prompts into SharedPreferences history text.

**Versioning:** `ChatTurnTrace.schema_version` starts at 1. Additive fields only.

## Architecture

```
User send
  → ChatTurnTraceBuilder.start(run_id)
  → intent / plugin / skill router records nodes
  → PromptInertiaGuard records inertia deltas
  → generateTextStream / skill run
       runtime emits ExecutionTrace-equivalent events into the same run
       first token → lifecycle first_token
  → onDone / onError / widget dispose / Flutter isolate death
       finalize stop_reason
  → attach ChatTurnTrace to AgentChatMessage + persist store
  → bubble chip always visible for assistant turns that have a run_id
       (including aborted, even if text is “Here”)
  → sheet = today’s Response details + timeline + constraint + refs
```

Framework (`core_ai`) does not import Flutter. `feature_mind` maps builder events onto the bubble and sheet.

`AssistantRuntimeDebugTrace` stays as a debugPrint sink. The builder is the source of truth; debugPrint can serialize the same run_id so Flutter logs join the sheet.

## UX (application)

- Keep the existing metadata chip on the assistant bubble. If generate aborts, still attach a trace so the chip reads `Aborted · {duration}` instead of disappearing.
- Sheet title: “Turn inspector”. First block: lifecycle pill + stop reason + run_id (copyable).
- Timeline: ordered #386 nodes plus generation events (started, first token, aborted/finished).
- “What the model saw”: redacted system + user prompt summaries; in debug, expand to full text from payload refs.
- “Decisions”: plugin_id / skill_id / routing / gbnf_attached / inertia kinds. Empty skill is an explicit “none (plugin generate)”, not a missing row.
- No extra chrome on user bubbles.

Desktop and phone share one sheet. Web: same Dart store; no FFI traces, runtime_id still recorded.

## Deterministic use cases (diet thread is the eval)

### UC-001 — abort mid-stream (the “Here” bubble)

Preconditions: GGUF generate started for “Make me a 7 day diet plan”. Flutter run is killed or the engine unload fires before EOS.
Happy path: one `run_id`. `lifecycle=aborted`, `stop_reason=process_killed` or `engine_error`. Trajectory has prompt_ref, plugin `draft-diet-plan`, no selected device skill. Chip visible. Inspector shows generated text prefix without claiming `finishReason=stop`.
Failure: if the process dies before any persist, the next launch cannot recover that run. Accept for v1; in-session abort (hot restart, cancel, isolate kill while UI lives) must persist.

### UC-002 — follow-up “i cant see the full response”

Preconditions: UC-001 stored. User sends the follow-up.
Happy path: **new** `run_id`, optional `parent_run_id` of UC-001. Plugin still diet. Completion `lifecycle=finished`, `stop_reason=eos`. Inspector does not merge the two turns into one.

### UC-003 — constraint change “for 3 days”

Preconditions: prior 7-day user turn in history.
Happy path: inertia node `day_count` previous=7 current=3. `constraint.gbnf_attached=true` when a prefix grammar was passed to llama.cpp; `false` on Android/LiteRT with prompt-prefix fallback only. Prompt_ref summaries must not still contain an unredacted competing “7 day” as the active duration.

### UC-004 — trace never blocks chat

If the store write throws, generation still streams. Inspector may be missing for that turn. Logged once.

### UC-005 — privacy

A prompt containing `sk-live-…` and “heart rate” serializes with `#386` redaction markers in summaries. Full payload file is absent unless debug store is on.

### UC-006 — history restore

Kill and relaunch Mind. Assistant rows with `runId` reopen the inspector. v1 histories without `runId` open chat with no chip (today’s behavior).

## Automation flows

- AUTO-001: `flutter test` in `core_ai` — ChatTurnTrace JSON schema, lifecycle transitions, redaction, parent_run_id.
- AUTO-002: `feature_mind` widget test — abort path attaches chip “Aborted”; sheet shows stop_reason ≠ stop.
- AUTO-003: diet eval fixture of the two-turn transcript asserts two run_ids and plugin_id on both.
- AUTO-004: ChatHistoryStore v2 round-trip with and without runId.

No GitHub Actions matrix expansion. Local package tests only.

## Security / privacy posture

Local-first. No network. Redacted by default. Debug full-prompt store is a developer toggle, off in release profiles unless explicitly enabled. Chat clear wipes traces. Chief Security Officer must review payload-ref storage before any non-debug full prompt lands on disk.

## Rollback

Feature flag `mindChatTurnInspector` (default on in debug, off in release until QA signs the diet eval). Flag off: keep today’s metadata sheet for completed turns; do not persist traces. Schema v2 history still loads as v1 text if `runId` is ignored.

## Implementation sketch (not this PR)

Order after spec approval:

1. `core_ai`: `ChatTurnTrace` + builder + tests (framework).
2. Runtime service: start/finalize run around `generateTextStream`; map cancel/dispose to aborted.
3. Chat screen: attach trace on first token **and** on abort; extend `_showMetadataSheet`.
4. History v2 + trace store.
5. Diet eval AUTO-003.

Streaming copy (“generation interrupted”) is a separate one-file follow-up after AUTO-002 is green.

## Approval

Review this spec. Requested changes go in this file. Implementation plan (`docs/superpowers/plans/…`) and code start only after you approve.
