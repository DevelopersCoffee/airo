# Airo Mind — Reasoning Engine architecture report

Date: 2026-08-21  
Worktree: `agent/mind/reasoning-engine` @ `origin/main` (`7f53a3f1`)  
Status: analysis complete. Implementation starts at the capability crate `airo_mind_reasoning`. No inference rewrite.

This report is the Phase 1 gate from the Cursor master goal. It does **not** assume APIs such as `airoEngine.generateStream()`.

---

## 1. Existing architecture

```text
app/lib/main_mind.dart          Flutter Mind shell (Scribe / Assistant / Intelligence)
        │
packages/feature_mind           Chat UI, prompt wrap, skill/tool loop, history
        │
AssistantRuntimeService         Picks GGUF / Gemini Nano / LiteRT / cloud
        │
   ┌────┼────────────────────────────┐
   ▼    ▼                            ▼
DesktopGgufBackend          llama_flutter_android         LiteRT MethodChannel
   │    (Android JNI)                 (Android)
   ▼
FRB airo_mind_llama cdylib
   │
Supervisor (airo_mind_core)
   │
GenerationEngine
   │
LlamaGenerationEngine (llama.cpp)
```

Chat send path today (`ChatScreen._sendMessage`):

1. Safety guardrails (Dart)
2. Grounded reply interceptor
3. `AgentToolInterceptor` (arithmetic / device)
4. Keyword `IntentParser`
5. `AgentSkillOrchestrator` (Dart tool/skill loop)
6. Else `AssistantRuntimeService.generateTextStream` → token `Stream<String>` → `setState`

**Flutter already owns too much of the intelligence path.** Prompt construction, intent, skills, and context packing run on Dart. Token generation is native. That is the gap this work closes for reasoning — not a missing llama.cpp.

---

## 2. Existing inference path

**Reuse this. Do not invent `InferenceEngine`.**

Rust trait (canonical):

```text
rust/airo_mind_core/src/engine.rs
  GenerationEngine::generate(&GenerationRequest, &CancelToken, sink)
  GenerationRequest { prompt, max_output_tokens, grammar: Option<GBNF> }
  GenerationChunk { text }
  RuntimeStats { prefill_ms, tok/s, peak_rss, ... }
```

Concrete engine: `LlamaGenerationEngine` in `rust/airo_mind_llama/src/llama.rs`.

Meeting capability already shows the correct layering: `airo_mind_meeting` takes `&dyn GenerationEngine`, owns prompts + GBNF, never constructs llama.cpp.

Dart product routing (`LLMClient` in `core_ai`) is a **parallel** abstraction for LiteRT / Gemini Nano / cloud. Reasoning V1 attaches to `GenerationEngine` (Mind local path). LiteRT remains a later `GenerationEngine` implementor (#1628 registry), not a second reasoning stack.

---

## 3. Existing streaming path

```text
LlamaGenerationEngine::generate
  → sink(GenerationChunk)
    → Supervisor::run_generation
      → FRB generate_completion(prompt, max_output_tokens, StreamSink<GenerationEvent>)
        → Dart Stream via flutter_rust_bridge 2.11.1
          → MindGenerationBridge.complete
            → AssistantRuntimeService / LlamaGgufService
              → ChatScreen._replaceStreamingMessage
```

Cancellation already exists: `CancelToken` (Rust) ← `MindGenerationBridge.cancel()` ← `cancel_generation()`.

There is **no** `ReasoningEvent` stream today. Chat streams undifferentiated answer tokens.

---

## 4. Existing persistence path

| Store | Mechanism | Reasoning fields |
|---|---|---|
| Assistant chat | `ChatHistoryStore` — SharedPreferences `airo_mind.chat_history.v1` | text, isUser, timestamp only. **No** thoughts, tools, summary |
| Meetings | Rust `MeetingStore` + Dart `MeetingRecord` | transcript / minutes / IR flatten |
| Embeddings | `MeetingEmbeddingStore` JSON | chunk vectors |
| Vault | `VaultPort` / `RustMindRuntime` | keys, not chat |

V1 persistence change is additive on chat history (summary + level). Never add a thought-trace column.

---

## 5. Existing Rust / native components

| Crate | Role | Use for reasoning |
|---|---|---|
| `airo_mind_core` | Supervisor, `GenerationEngine`, cancel, budget | **Depend on it** |
| `airo_mind_llama` | llama.cpp + FRB cdylib | **Call later** via existing `generate` / `complete` |
| `airo_mind_meeting` | Capability pattern (prompt + GBNF + validate) | **Copy the layering** |
| `airo_mind_whisper` | ASR FRB | Unrelated |
| `airo_core` | TV/media FRB | Unrelated |

Bridge: **flutter_rust_bridge** + dart:ffi, two cdylibs (`airo_mind_llama`, `airo_mind_whisper`). Android assistant GGUF also uses `llama_flutter_android` (JNI). LiteRT uses MethodChannel. iOS ffiPlugin is **not** enabled today (ggml ODR). Web has stubs only.

---

## 6. Flutter vs Rust boundary (target)

### Remain in Flutter

- Screens, navigation, animations, Riverpod UI state
- Rendering `ReasoningEvent` (Thinking accordion, answer deltas)
- Lightweight adapters: map Dart `Intent` → wire `ClassifiedIntent` **after** a classifier exists
- Model download / catalog UI (`IntelligentModelManager` stays Dart; ADR-0018: Rust never downloads)

### Move to Rust (incrementally; this crate starts the list)

| Now in Dart | Target |
|---|---|
| Reasoning policy / CoT prompting | `airo_mind_reasoning` |
| Structured parse of model output | Rust parser + GBNF |
| Context packing for reasoning | Rust `ContextLimits` |
| Tool loop for reasoning | Rust, reusing tool *definitions* from Dart later |
| Keyword `IntentParser` as the brain | Replace with classified intent input; classifier can land separately |

### Do **not** move in this increment

- Entire `AgentSkillOrchestrator` (product skills still work)
- Meeting IR pipeline (already Rust)
- llama.cpp / Metal / Android JNI
- ChatScreen rewrite

---

## 7. Reuse vs introduce

**Reuse**

- `GenerationEngine` / `GenerationRequest.grammar` / `CancelToken` / `RuntimeStats`
- `MindGenerationBridge.complete` + `cancel` (FRB later)
- `LlmDeviceTier` (Dart) as the source that fills `DeviceInferenceProfile`
- Meeting GBNF string/ws rules as the grammar style
- Fake-engine test pattern from `airo_mind_meeting/tests/golden.rs`

**Do not create**

- A second `InferenceEngine` trait
- A Dart `lib/core/reasoning/` brain
- A new llama.cpp / MLX stack
- Public `thoughts` / `THINKING_TRACE` protocol
- Platform `cfg` inside the reasoning crate

**Introduce**

- `rust/airo_mind_reasoning` (rlib, same as `airo_mind_meeting`)
- Types: level, policy, request, context, events, result, errors
- Result-envelope GBNF (answer + summary + confidence — **no thoughts key**)
- Incremental JSON field parser
- Later: one FRB `reason()` stream beside `generate_completion`

---

## 8. Risks and compatibility

| Risk | Mitigation |
|---|---|
| Dual GGUF stacks (FRB llama vs Android JNI vs LiteRT) | Reasoning depends only on `GenerationEngine`. Android JNI stays an adapter below that line. |
| iOS engines not in `ffiPlugin` | Crate compiles on host; Apple FM is #1640. Same API, missing backend. |
| `IntentParser` is keyword-only | Policy takes `ClassifiedIntent { kind, complexity }`. No `query.contains("plan")` in the crate. |
| Chat history has no summary field | Additive schema bump later; V1 crate does not persist. |
| Dirty local `core_ai` generation helpers | **Not** on this worktree. Do not merge that tree. |
| FRB codegen churn | Land the rlib first; add `reason()` to `airo_mind_llama` only after engine tests pass on a fake backend. |
| Architecture freeze (`C5`) | Reasoning is a **capability crate**, not an eighth runtime primitive. |

---

## 9. Implementation sequence (this branch)

1. `airo_mind_reasoning` types + policy + device clamp (no GGUF) — **this increment**
2. Prompt strategy + result GBNF + validator
3. Engine loop + events + incremental parser on a fake `GenerationEngine`
4. (later) FRB `reason()` + Flutter facade + Thinking UI + persistence + tool executor

Existing chat, scribe, and llama.cpp paths stay untouched until step 4.
