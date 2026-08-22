# Airo Deep Research Engine

Status: **Locked architecture** — interpreter/strategy/stopping IR is in
`airo_mind_core`. Wikipedia/arXiv search is a candidate feed, not the product.
Date: 2026-08-22
Owner: Chief Architect + Product Manager (Airo Mind)
Touches frozen surface: ADR-0021 `MindRuntime` port — research is a **capability
job**, not a new inference engine and not a new cdylib.

---

## 1. What this is

Airo Deep Research is a **Rust-owned orchestration job**. Flutter presents
progress and the report. The model never owns the workflow.

Do **not** implement:

```text
User → huge research prompt → LLM → report
```

Implement:

```text
User → interpret → strategy → DAG → search ≠ evidence
     → acquire → extract → claims → verify → counter-research
     → stop on sufficiency → synthesize with provenance → report
```

**Locked product rule:**

```text
SEARCH ≠ RESEARCH
Search only produces candidate information.
Research = planning + search + acquisition + extraction + evidence
         + verification + iteration + synthesis + provenance.
```

Jan and Local Deep Research (LDR) are behavioral references. Do not fork or
copy their Python, LangGraph, Flask, UI, or provider SDKs. LDR is MIT-licensed;
Airo adopts the *ideas* (iterative questions, pluggable search, parallel
retrieval, citations, local library) behind Airo contracts.

## 2. Where it lives in *this* repo

The sketch crate tree (`airo-research/`, `airo-search/google/`, …) does **not**
match the Airo workspace. Frozen placement:

| Concern | Crate | Why |
|---|---|---|
| Research IR, job state, evidence graph, `SearchEngine` trait | `rust/airo_mind_core` (`research` module) | std-only, backend-free, already the Supervisor/engine boundary |
| llama.cpp / GGUF generation | `rust/airo_mind_llama` via `GenerationEngine` | Inference stays pure (`I2`/`I4`). Research builds prompts + GBNF; the engine does not know it is researching |
| HTTP search providers (Google, Brave, SearXNG, arXiv, …) | **Not in `airo_mind_core`** | Native I/O would re-create the ggml split problem. A future `airo_mind_search` rlib/cdylib, or Dart adapters behind the trait, needs a Chief Architect package decision |
| Chat trigger, progress, report rendering | `packages/feature_mind` | Presentation only. Structured `ResearchEvent`s, never chain-of-thought |
| Durable research library | Operation log + projections (`C1`/`C2`) | `I2`: a capability must not invent its own store. Claims/sources/reports become entities + content, not a sidecar SQLite schema |

Google is **one** `SearchEngine` implementation, not the research engine.

## 3. Frozen contracts this must not break

- **`C5`** — a capability never calls an engine. It emits operations / a
  `ResearchRequest`. Generation is `GenerationRequest { prompt, grammar }`.
- **`C6`** — Supervisor admits the job against memory/CPU/IO budgets and
  cancellation. Research adds a *research* budget (searches, iterations,
  duration) on top of the device memory budget.
- **`I2`** — no durable files outside the runtime.
- Runtime knows **no domains**. There is no `Minutes` type in core; there is
  also no `QwenVsLlamaReport` type. The report is capability output.

`ResearchModel { plan, analyze, verify, synthesize }` is a **policy adapter**
above `GenerationEngine`, not a third engine slot beside speech/generation.

## 4. What is shipped (IR + first slice)

Shipped as **contracts and a thin live slice**, not the full production engine:

1. Typed `ResearchRequest` / `ResearchBudget` / `ResearchMode`.
2. `ResearchIntent` + `InterpretedGoal` (topic, dimensions, decision, freshness).
3. `ResearchStrategy` (comparison / decision / fact-finding / technical / academic / investigation). There is **no universal algorithm**.
4. DAG nodes with `depends_on`.
5. `QuerySet` including a **counterargument** query.
6. `StoppingPolicy` / `EvidenceSufficiencyPolicy` — stop on coverage, not on “N searches”.
7. `SourceContent { trust: Untrusted }` — webpage text never becomes instructions.
8. Evidence graph that refuses dangling citations.
9. `SearchEngine` trait. Google is never implied.
10. Flutter Deep Research toggle + structured events.
11. Wikipedia + arXiv HTTPS adapters (allowlisted hosts, size/timeout caps).
12. Orchestrator: interpret → plan → breadth → gaps → depth → optional counter-research → citation report.
13. Source manager: fetch → HTML extract (nav/script stripped) → freshness/credibility → cache. Hits are not evidence. One fetch failure does not kill the job.
14. Claims from acquired paragraphs; citations are unverified unless the excerpt appears in the acquired source.
15. Semantic Scholar search/acquisition alongside Wikipedia and arXiv.
16. Pause/resume/cancel and operation-log checkpoints. The `v2` record
    preserves mode and policy; ambiguous `v1` records fail closed to
    Quick/LocalOnly (zero remote engines). Chat can reattach a paused job after
    process restart and waits for the user to resume it. The Rust
    `ResearchCheckpoint` public struct now carries `mode` and `policy`; external
    struct-literal callers must supply those fields or migrate to `from_job` /
    `from_record`. The future FRB surface must use its own versioned checkpoint
    DTO rather than exporting this core struct directly.
17. Operation-log research library, incremental URL delta, cited comparison
    matrix, and contested-row decisions.
18. User-facing Private / Balanced / Cloud profiles, observability metrics,
    and abstract cost ceilings. Private routes to Wikipedia by default and can
    use the SearXNG adapter only when the host injects an explicit self-hosted
    HTTPS base URI. Airo has no default/public SearXNG endpoint. The adapter is
    origin-isolated and candidate-only: result URLs do not expand the separate
    source-acquisition allowlist. Shells inject it through
    `MindModule.deepResearchEngineFactory` and
    `createLocalDeepResearchEngine(searxngBaseUri: ...)`; both Chat routes use
    that host-owned engine.
19. PubMed, GitHub, Crossref, and local-memory `SearchEngine` adapters.
20. `ResearchService` FFI in `airo_mind_llama`: `start` / `status` / `pause` /
    `resume` / `cancel` / `report` / `run` with Dart-injected search/fetch. Web
    and pre-init builds keep the Dart orchestrator.

Not shipped (locked below, do not pretend they exist):

- Google / Bing / Brave / DuckDuckGo / Tavily / news APIs
- SearXNG endpoint settings UI and persisted endpoint configuration
- HTML/PDF tables-from-scanned-pages, PDF binary extraction
- Claim-level citation validation, contradiction explanations, confidence scores
- HTTP cache, automatic checkpoint restore through FRB, automatic continuation
  without user reattachment, richer event stream parity with the Dart orchestrator
- Weighted decision scoring beyond contested-row flags

## 5. Locked production scope (do not drop)

Complete pipeline (Flutter is presentation only; Rust owns execution):

```text
USER GOAL
  → RESEARCH INTERPRETER (intent / scope / time / output)
  → RESEARCH PLANNER (strategy / DAG / budget / stopping)
  → WEB | ACADEMIC | LOCAL MEMORY   (SearchEngine adapters)
  → RESULT AGGREGATOR
  → SOURCE MANAGER (fetch / parse / canonicalize / cache)
  → DOCUMENT INTELLIGENCE (HTML / PDF / tables / code — never dump whole pages)
  → EVIDENCE ENGINE (claims / evidence / provenance)
  → VERIFICATION (support / conflict / freshness / gaps)
  → more evidence? → iterate including COUNTER-RESEARCH
  → SYNTHESIS → REPORT VALIDATOR → FINAL REPORT → RESEARCH LIBRARY
```

### Must remain in the IR

| Area | Contract |
|---|---|
| Interpreter | Goal → topic, dimensions, freshness, geography, output, decision-required |
| Intent | `FACT_FINDING`, `COMPARISON`, `DECISION_SUPPORT`, `TECHNICAL_RESEARCH`, `ACADEMIC_RESEARCH`, `MARKET_RESEARCH`, `PRODUCT_RESEARCH`, `NEWS_RESEARCH`, `INVESTIGATION`, `DEEP_EXPLORATION` |
| Strategy trait | `QuickFact` / `Comparison` / `Technical` / `Academic` / `Investigation` / `Decision` / `Exhaustive` — selected from intent |
| DAG | Dependencies (`A → B`). Rust schedules. User “change direction” rewrites remaining nodes, does not wipe completed evidence |
| Queries | Primary, alternative, technical, **counterargument**, source-specific, freshness |
| Counter-research | Dedicated stage: “what would make this conclusion wrong?” |
| Acquisition | Hit ≠ evidence. Fetch, redirects, extract HTML/PDF/MD/JSON/XML/CSV |
| Freshness | `published_at` / `modified_at` / `retrieved_at`. Dominates changing topics; not historical research |
| Credibility | PRIMARY/SECONDARY/TERTIARY + OFFICIAL/ACADEMIC/GOVERNMENT/STANDARD/NEWS/TECHNICAL/COMMUNITY/SOCIAL/SEO |
| Provenance | source → evidence → claim → sentence → citation. Never cite after writing |
| Citation validation | Missing/unsupported → `REJECT` or `UNVERIFIED` |
| Contradictions | Explain method/date/hardware/population, do not silently pick a winner |
| Uncertainty | confidence, evidence_count, source_quality, agreement, freshness |
| Stopping | Coverage + supported claims + resolved contradictions + budget. **Not** search count |
| Budget | searches, sources, tokens, LLM calls, network, runtime, workers, estimated cost |
| Failure | One source failure never kills the job. Retry / failover / skip |
| Parallelism | Bounded (`Semaphore`). Never unbounded spawn |
| Cache | search, HTTP, parse, embeddings, structured LLM outputs |
| Resumability | Survive app close / sleep / network / process restart via operation log |
| Control | Pause, resume, cancel, restart, redirect remaining DAG |
| Observability | duration, searches, sources used/rejected, claims, contradictions, tokens, cost |
| Security | SSRF, allow/deny, redirect/size/MIME/PDF limits, sanitization, **prompt injection**: `TrustLevel::Untrusted` |
| Privacy | PRIVATE (local + SearXNG) / BALANCED / CLOUD |
| Memory | Research project persists; incremental = previous evidence + freshness + delta |
| Decision / compare | Weighted criteria + evidence-linked matrix |
| Flutter API | `ResearchService { start, status, pause, resume, cancel, report }` + `ResearchEvent` stream only |

### Search adapters (behind `SearchEngine`, later I/O crate)

General: Google, Bing, Brave, DuckDuckGo, SearXNG, Tavily.
Academic: arXiv, Semantic Scholar, Crossref, PubMed.
Technical: GitHub, Stack Overflow, official docs, package registries.
News: Google/Bing News, news APIs.
Local: Airo Memory, Research Library, user files.

### Phased build order (do not boil the ocean)

| Phase | Work |
|---|---|
| A | Interpreter + strategy + stopping + untrusted sources |
| B | Source manager + HTML main-content extraction + freshness/credibility (**this slice**) |
| C | Evidence graph claims from retrieved text + citation validation (**this slice**) |
| D | Counter-research as a first-class wave + contradiction explanations (**this slice**) |
| E | Job manager pause/resume/cancel + operation-log checkpoints |
| F | Additional `SearchEngine` adapters one provider at a time (never Google-implied) |
| G | PDF/tables/code document intelligence off the main isolate |
| H | FFI `ResearchService` + richer events; Dart orchestrator becomes a shim |
| I | Research library, incremental delta, comparison matrix, decision engine |
| J | Privacy profiles, observability metrics, cost accounting |

## 6. Adopt vs reject

**Adopt from Jan / LDR:** planning → search → analysis → synthesis; iterative
question waves; pluggable search; parallel retrieval; citation abstraction;
local + cloud models; progress events; research → library compounding.

**Reject:** Python/LangGraph/Flask; LDR DB schema; LDR UI; hard-coded Google;
a "Deep Research system prompt" as the product; exposing model CoT in Flutter.

## 7. Security

Retrieved pages are **content**, never tool endpoints and never instructions.

```text
SYSTEM INSTRUCTIONS
RESEARCH POLICY
TOOL INSTRUCTIONS
SOURCE CONTENT   ← TrustLevel::Untrusted. Never promoted.
```

A page that says “Ignore previous instructions” stays untrusted evidence.
Provider registry, HTTPS, SSRF protection, redirect/size/MIME/PDF limits,
and sandboxed extraction are required before any live `web_fetch`.
Credentials stay in the Vault, not in capability code.

## 8. UI contract

Flutter shows:

```text
✓ Understanding question
✓ Creating research plan
● Searching sources
○ Finding missing evidence
○ Writing report
```

Flutter does not show "I think…", "Maybe…", or raw tool scratchpads.
