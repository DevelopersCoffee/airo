# ADR 0022 — Meeting IR → Mind operation mapping

## Status

Accepted (Chief Architect, Edge Architect — both "approve with changes", incorporated below)

## Date

2026-08-14

Deciders: Chief Architect (primary decider, module boundaries), Edge Architect (offline/caching/
sync design consult, per #1657's own instruction to use the closest sync-design authority for
"operations → projections"). Chief Architect's review flags that COUNCIL.md's Decision Matrix
would ordinarily route the Rust/FFI boundary question to Platform Architect rather than Edge
Architect — noted here rather than re-routed, since #1657 explicitly named Edge Architect and the
review it gave (embedding-cache gap, transcript-store confirmation) was squarely in scope. Whoever
signs off Stage 2's G0 should confirm Platform Architect input isn't separately required there.
Issue: [#1657](https://github.com/DevelopersCoffee/airo/issues/1657) · Epic [#1627](https://github.com/DevelopersCoffee/airo/issues/1627)
Gap tracked separately: [#1719](https://github.com/DevelopersCoffee/airo/issues/1719) (crypto-shred, blocks AC4)

## Context

`rust/airo_mind_meeting` (#1633/#1634/#1635, merged on `main`) produces
`MeetingIr` — one versioned, evidence-grounded structure
(`rust/airo_mind_meeting/src/ir.rs`) with `Meeting` metadata and `Facts`
(topics, observations, decisions, action items, metrics, risks, questions,
next steps), every fact carrying `evidence: Vec<String>` segment ids. It has
no persistence integration. #1657's own acceptance criteria require that
mapping be designed and reviewed before code, because `MindRuntime`'s Dart
port is frozen (ADR-0021) and `feature_mind` must not grow a second store.

**Two systems already exist, not one**, and the design has to reconcile them
rather than invent a third:

- **System A — the `MindRuntime` port**
  (`packages/feature_mind/lib/src/runtime/mind_runtime.dart`). Eight
  sub-ports, frozen by ADR-0021 and `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`.
  `OperationLogPort.append(kind, title, contextId, detail)` is the only write
  primitive (`packages/feature_mind/lib/src/runtime/ports/operation_log_port.dart`);
  `ProjectionPort.{search,rebuild}` are read/derive-only, over exactly three
  projections (`graph`, `timeline`, `search` —
  `packages/feature_mind/lib/src/runtime/models/projection_models.dart`).
  `RustMindRuntime`'s log and projection methods are still `_pending(...)`
  stubs (`rust_mind_runtime.dart:104-118`) — the real Rust-backed operation
  log and projections (#1194/#1195, tracked to the Dart port by #1213-#1220)
  are not wired to this port yet. `FixtureMindRuntime` is the only working
  implementation today.
- **System B — the scribe meeting store** (`rust/airo_mind_core`). Predates
  the operation log (#1399/#1400, Milestone 2). `store.rs`'s `MeetingStore`
  is an append-only file of `Meeting { id, title, recorded_at, transcript,
  minutes, model }`; `search.rs`'s `SearchIndex` is a lexical AND-term index
  over `title + transcript + minutes`, exposed to Dart as `searchMeetings`
  (`packages/feature_mind/lib/src/whisper/api/meetings.dart:91`, Rust
  `rust/airo_mind_whisper/src/api/meetings.rs:473`). This is functional
  today. `store.rs`'s own module doc states the intent plainly: *"When the
  [operation] log lands, this module's contents become operations and the
  file becomes the log — the call sites do not change."* It is the sanctioned
  pre-op-log realization of the Content primitive for meetings, not a rogue
  parallel store — `#1338`'s Notes vertical slice (`rust/airo_mind_core/src/notes.rs`)
  is the other, later capability that *does* run through the real Operation
  Log, and is this ADR's model for what System B becomes once the log lands
  under it.

Separately, `packages/feature_mind/lib/src/search/semantic_search_ranker.dart`
(#508) already re-ranks `searchMeetings`' keyword hits with embedding
similarity from `MeetingEmbeddingStore`, union-not-replace, falling back to
keyword-only when no embedding model is installed. This is the one embedding
path that exists; nothing here may duplicate it.

One pattern is already established and working: consent capture
(`packages/feature_mind/lib/src/assistant/consent/audio_scribe_consent_gate.dart:92-145`)
appends a real `OperationLogPort.append(kind: MindOpKind.consent | .consentRevoked, …)`
entry around scribe recording, and `quick_capture_controller.dart` shows the
required degrade-gracefully shape: a `try`/`on MindPortUnavailable catch`
around the `log.append` call, because `RustMindRuntime`'s log is a stub today.
"Meeting-adjacent event → real op-log append; meeting content → scribe store"
is not proposed here — it is copied from code that already ships this way.

## Decision

**IR is not a new store.** It extends System B — the existing, sanctioned
Content stand-in for meetings — and it emits into System A's operation log
using the same degrade-gracefully pattern consent capture already uses, so
the write path is forward-compatible with zero rework once #1213-#1220 land.

### 1. What a `MeetingIr` write produces

Two things happen per meeting-IR write, mirroring the consent-capture split
of "content" vs. "log-visible event":

1. **Content: `Meeting` gains IR fields.** `rust/airo_mind_core/src/store.rs`'s
   `Meeting` struct is extended with `decisions: Vec<Decision>`,
   `action_items: Vec<MeetingActionItem>`, `metrics: Vec<Metric>` (Rust types
   mirroring `airo_mind_meeting::ir::{Decision, ActionItem, Metric}`, each
   carrying `evidence_segment_ids: Vec<String>`), written by the same
   append-only `MeetingStore::save` / "latest wins" read semantics that
   already exist. `saveMeeting` (`meetings.dart:74`, Rust
   `crateApiMeetingsSaveMeeting`) gains these as new parameters. **No new
   Rust store, no new Dart port method** — this is the mechanical, delegable
   half of the write path.

   **Crate-dependency decision (resolved here, per Chief Architect review,
   rather than left implicit)**: `airo_mind_core` does **not** gain a crate
   dependency on `airo_mind_meeting`. The new types are hand-mirrored in
   `rust/airo_mind_core/src/store.rs` alongside `Meeting`, not re-exports —
   `airo_mind_meeting::ir::{Decision, ActionItem, Metric}` stay the canonical
   extraction-side shapes (evidence grounding, dedup, validation live there);
   `airo_mind_core`'s mirrors are the narrower persistence-side shapes. This
   keeps `airo_mind_core`'s existing dependency graph unchanged, matching the
   "local mirror, not a re-export" pattern
   `airo_mind_transcript::segment::Segment`'s own module doc already states
   for the same reason (`rust/airo_mind_transcript/src/segment.rs:1-9`).
   Stage 2 defines the field-for-field mapping; this ADR fixes only that no
   new crate edge is added.

   New type, not reuse of `core_domain`'s `ActionItem`
   (`packages/core_domain/lib/src/entities/action_item.dart`): that type is
   LifeTrack-scoped (`milestoneId` FK, document-checklist `requirements`) and
   has no slot for `ownerName: String?` (nullable — MIND-LLM-9 forbids
   inferring an owner the transcript never named) or
   `evidenceSegmentIds`. Reusing the name `ActionItem` for two unrelated
   shapes in one codebase is the footgun this avoids. Name:
   `MeetingActionItem`.

2. **Log-visible event: one `OperationLogPort.append` call.**
   `kind: MindOpKind.meetingIrExtracted` (§1.2 decides this over reusing
   `inference`), `title: "<meeting title> minutes extracted"`,
   `contextId: <meeting's context id>`, `detail: "<meeting id>;<IR summary>"` —
   same shape and same call site pattern as
   `audio_scribe_consent_gate.dart`'s `MindOpKind.consent` append. Wrapped in
   the same `try`/`on MindPortUnavailable catch` degrade-gracefully pattern
   `quick_capture_controller.dart` already uses: this call is a no-op today
   (`RustMindRuntime`'s log is a stub) and must fail soft, not hard. This is
   what makes IR visible to the *timeline* projection once it exists — an op
   that never happened cannot appear on a replay-built timeline, so this call
   has to be made now even though it degrades to nothing today.

   **`MindOpKind` vocabulary — decided, per Chief Architect review**: add a
   new value (`meetingIrExtracted`), do not reuse `MindOpKind.inference`.
   Reusing `inference` would render meeting-IR extraction identically to
   every other future inference-shaped op on the Windows runtime console —
   the stated reason the enum is closed and typed per-kind
   (`log_models.dart:5-6`) — and would force any future timeline/graph
   consumer to string-match `detail` to tell them apart, the stringly-typed
   coupling this enum exists to avoid. Meeting-IR extraction is a
   product-visible event (it is what makes decisions/action-items exist),
   not an incidental inference side-effect — it earns its own vocabulary
   entry the same way `consent`/`consentRevoked` earned theirs. Cost is low:
   this is additive to a closed enum (the enum's own doc comment anticipates
   exactly this kind of deliberate addition), not a port-shape change, so it
   does not widen the ADR-0021 freeze.

### 2. Projections

Two, matching the two writes above, and matching the frozen `ProjectionKind`
set (`graph`, `timeline`, `search` — no fourth projection is proposed):

- **Timeline**: nothing new. The `MindOpKind.inference` entry above is
  already timeline-eligible content once #1213-#1220 wire `RustMindRuntime`'s
  log/replay to the real Operation Log/Projection engine
  (`rust/airo_mind_core/src/runtime.rs`, `projection.rs`) — this ADR's write
  path emits the operation now so no history has to be backfilled later.
- **Search (FTS feed into `searchMeetings`)**: `search.rs::insert()` is
  extended to also tokenize decision statements, action-item task text, and
  owner names into the same lexical index, alongside the existing
  `title + transcript + minutes` blob (`search.rs:79-96`). Same AND-term
  match semantics, same `SearchIndex::remove` crypto-shred contract
  (`search.rs:24-28`, tested by
  `removing_a_meeting_makes_it_unfindable`). **No new index engine, no
  duplicate embedding path** — this is the FTS `searchMeetings` the issue
  names, fed, not replaced.
- **Action items as entities (owner, status)**: not a new store or
  projection type. `MeetingActionItem`'s `owner: Option<String>` and
  `status: ActionStatus` (mirroring `airo_mind_meeting::ir::ActionStatus`)
  ride on the `Meeting` record from §1. "What's pending" / "which items are
  assigned to me" are client-side filters over already-fetched
  `MeetingRecord.actionItems` (Dart, or a thin Rust query fn over
  `MeetingStore::all()`) — **no new query surface on the `MindRuntime` port**,
  because the data is already addressable through `getMeeting(id)` /
  `listMeetings()`.

  This is the one place `EntityGraphProjection`
  (`rust/airo_mind_core/src/projection.rs`, #1195) was considered and
  rejected for v1: promoting action items to real `CreateEntity`/`SetProperty`
  verb operations in the shared entity graph would make them queryable
  through the generic graph projection instead of a client-side filter, at
  the cost of a second copy of the same data (verb operations *and* `Meeting`
  fields) until IR-as-fields-on-`Meeting` is later migrated onto real
  operations wholesale. Deferred to the read/query-path stage below rather
  than decided now — flagged for review, not ruled out permanently.

### 3. Composing with #508 semantic search — no duplicate embedding path

`SemanticSearchRanker.rank()` already embeds `'${meeting.transcript}
${meeting.minutes}'` (`semantic_search_ranker.dart:79`) lazily, per meeting,
cached in `MeetingEmbeddingStore`. Extending the embedded text to also
include decision/action-item/owner strings (the same text §2's FTS index
gets) is a data-shape change to what gets embedded — one extra string
concatenated into the same call — not a second embedding path. No new
`EmbeddingService` call site, no new vector store.

`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md` already
scoped #508 to `MeetingRecord`/`searchMeetings` — the same record this ADR
extends — and explicitly ruled out building on `ProjectionPort.search`
because it was a stub. Once the real `ProjectionPort.search` lands (#1220),
its own doc comment already promises "ranked locally by embedding plus
keyword" — the same shape #508 built by hand. Folding scribe's FTS + #508's
embeddings into that projection is a distinct future migration, out of scope
here, and this design does not pull it forward or duplicate it in the
meantime.

### 4. Evidence-resolution chain

Mechanically possible today. **Confirmed, not merely assumed** (per Edge
Architect review, which read `rust/airo_mind_whisper/src/transcript_store.rs`
in full — see the dependency note below, tightened from "unverified" to
"verified" as a result):

```
airo_mind_transcript::Segment { id, start_ms, end_ms, text }
  (rust/airo_mind_transcript/src/segment.rs)
        |
        v  (feeds chunking, #1632)
airo_mind_transcript::chunk::Chunk { id, segment_ids: Vec<String>, .. }
        |
        v  (Pass 1 extraction, per-chunk)
airo_mind_meeting::ir::ChunkIr { chunk_id, segment_ids, facts: Facts }
        |
        v  (Pass 2 consolidation, meeting-scoped)
airo_mind_meeting::ir::MeetingIr { meeting: Meeting, facts: Facts }
  — every Decision / ActionItem / Metric / Risk / Question / NextStep /
    Observation / Topic carries `evidence: Vec<String>` = segment ids
    (rust/airo_mind_meeting/src/ir.rs:82-160)
        |
        v  (this ADR §1: evidence ids ride unchanged as
            evidence_segment_ids on the Mind-persisted fact types)
Mind-persisted MeetingActionItem.evidenceSegmentIds : List<String>
```

Resolving one evidence id to an audio timestamp at read time is: take a
`segmentId` from an `evidenceSegmentIds` entry, look it up in the meeting's
persisted transcript (`#1629`'s `transcript.json`,
`rust/airo_mind_whisper/src/transcript_store.rs`,
`TranscriptSegmentRecord { id, start_ms, end_ms, text }`) by `id`, and read
`start_ms`/`end_ms` from that record. No re-running ASR.

**Dependency — verified, not open.** `transcript_store.rs`'s `document_path`
(`rust/airo_mind_whisper/src/transcript_store.rs:61-67`) keys each transcript
document as `transcripts/{meeting_id}.transcript.json` — **one file per
meeting id** — and `StoredSegment { id, start_ms, end_ms, text }` is exactly
the shape §4 needs. Because resolution is always "look up this meeting's own
file, then find `id` within its `segments` array," there is no cross-meeting
ambiguity to guard against: segment ids only need to be unique *within* one
meeting's document, which the per-meeting file guarantees regardless of
global uniqueness. Stage 2 does not need to "confirm" this before relying on
it — it already holds.

### 5. Crypto-shred gap — blocking, not invented here

**Finding, confirmed independently against code**: no crypto-shred
implementation exists. `grep` across `rust/` for `DestroyContent` /
`crypto_shred` / `ContentKey` handling returns only the *design* reference in
`search.rs`'s module doc (*"Crypto-shredding reaches here"*, lines 23-28) and
one tested behavioral contract (`SearchIndex::remove` makes a destroyed
meeting unfindable — `removing_a_meeting_makes_it_unfindable`,
`search.rs:270-284`). `rust/airo_mind_core/src/content.rs` names
`DestroyContent`'s "mechanical half" (deleting the local blob) but the
content-key/shred half is Vault's, and no Vault code implements it yet
(`rust/airo_mind/src/vault/{aggregate,revocation,identifier}.rs` were
searched and hold ledger/identifier logic, not a shred call). On the Dart
side, `ContextPort` has only `survivorsIfDestroyed` (a preview) —
`ContextPort.destroy()` does not exist in the frozen P0 port
(`memory_surface.dart:36-39`). This is tracked as
[#1719](https://github.com/DevelopersCoffee/airo/issues/1719) and is a
**pre-existing gap this issue inherits, not one this design creates**.

**Why the design in §1 still satisfies AC4's intent despite the gap —
corrected per Edge Architect review**: keeping IR as *fields on the existing
`Meeting` record* rather than a sibling record with its own id means there is
never a **second** shred call site to build for IR specifically — whatever
meeting-level deletion mechanism eventually exists only has to reach one
record. That is the limit of the "for free" argument, and it is narrower than
the original draft stated:

- **`SearchIndex::remove`** (`search.rs`) is real, tested, and self-healing —
  `SearchIndex` is fully rebuilt from `MeetingStore::all()` on open, so a
  meeting missing from the store drops out of the index on next boot even
  without an explicit call. IR-as-fields rides this for free, today.
- **`MeetingStore` itself has no delete method.** Its public surface is
  `save`/`all`/`get` only (`store.rs`, read in full) — there is no
  "store-level deletion" today for IR-as-fields to ride on for free. The
  previous draft's phrase implying one exists was wrong; corrected here.
  Store-level deletion is part of the gap #1719 (or a preceding issue) has to
  build, not something already in place.
- **`MeetingEmbeddingStore` (§3's re-ranker cache,
  `packages/feature_mind/lib/src/search/meeting_embedding_store.dart`) has no
  `remove`/clear method either** — its public surface is `put`/`get`/`all`,
  read in full. Unlike `SearchIndex`, it is not rebuilt from the store at
  boot; it is a plain read/write-through cache. Once §3 extends the embedded
  text to include IR (decision text, action-item owners — arguably the most
  sensitive part of a meeting), that vector persists in
  `meeting_embeddings.json` **indefinitely**, surviving any future meeting
  deletion unless something explicitly clears it. This is a second,
  currently-unaddressed shred call site, distinct from and in addition to
  #1719, and this ADR names it explicitly rather than folding it silently
  into "whatever deletion eventually ships."

**This ADR does not implement crypto-shred, store-level meeting deletion, or
an embedding-cache clear path.** All three are gaps, not built here. #1719
tracks the crypto-shred/content-key half. **Tracked as a new, explicit
requirement of this ADR**: whatever issue builds meeting deletion (crypto-shred
or an interim store-level delete) must also add and call
`MeetingEmbeddingStore.remove(meetingId)` — file this as a companion to
#1719 or fold it into #1719's scope directly, but it must not be discovered
only when someone notices a deleted meeting's decisions are still
semantically searchable. AC4 itself cannot be marked done until that lands or
#1657's AC4 is explicitly downgraded to reflect that no real deletion
mechanism — content-key or otherwise — exists for meetings today.

### 6. Split plan — write path / read-query path as separate follow-ups

**Stage 2 — write path** (mechanical once this ADR is accepted; delegable per
#1657's own delegation note):
- Add `MeetingActionItem` / `MeetingDecision` / `MeetingMetric` Rust types
  (`rust/airo_mind_core` or a new module) mirroring
  `airo_mind_meeting::ir::{ActionItem, Decision, Metric}`, plus their Dart
  mirrors.
- Extend `Meeting`/`MeetingStore`/`MeetingRecord` and the `saveMeeting` bridge
  signature with the three new fields (§1.1).
- Extend `SearchIndex::insert`'s tokenized text (§2, FTS feed).
- Extend `SemanticSearchRanker`'s embedded text (§3).
- Wrap the `OperationLogPort.append(kind: MindOpKind.meetingIrExtracted, …)`
  call (§1.2) in the `MindPortUnavailable` degrade-gracefully pattern.
- Add `MindOpKind.meetingIrExtracted` to the Dart enum (§1.2) and whatever
  the Windows runtime console's per-kind rendering switch requires for it.
- Wire evidence resolution against `transcript.json` per §4 (already
  confirmed, not a pending confirmation).
- Add `MeetingEmbeddingStore.remove(meetingId)` (§5/§6) even though nothing
  calls it yet in Stage 2 — having the method exist and be unit-tested means
  #1719 (or its companion) only has to call it, not build it, when meeting
  deletion ships.

**Stage 3 — read/query path** (after Stage 2 lands):
- Client-side (or thin Rust query fn) filters for "what's pending" / "which
  items assigned to me" over `MeetingRecord.actionItems` (§2).
- Evidence resolution: `evidenceSegmentIds` → `transcript.json` lookup →
  `start_ms`/`end_ms` (§4), surfaced wherever "why did we choose X" is asked.
- Any UI surface consuming the above (out of this ADR's scope — product/UX
  concern, not a Mind-runtime contract change).
- Explicitly **not** in this stage: folding scribe's FTS + #508's embeddings
  into the real `ProjectionPort.search` (§3) — that rides #1220 and is its
  own future ADR when #1220 lands.

**Blocked, tracked separately, not a Stage 2/3 dependency for landing IR
persistence itself:**
- [#1719](https://github.com/DevelopersCoffee/airo/issues/1719) — real
  crypto-shred (content-key destruction) and store-level meeting deletion
  (§5: neither exists today). AC4 stays open against #1657 until this ships
  or AC4 is reworded. Its scope should explicitly include calling
  `MeetingEmbeddingStore.remove(meetingId)` (§5/§6) — file a companion issue
  if #1719 does not want to absorb the Dart-side change.

## Contract Impact

**Required. Fill every row — "none" is an answer, blank is not.**

| Question | Answer |
|---|---|
| Which runtime contracts change? | None. `OperationLogPort.append` and `ProjectionPort.search` are used exactly as specified by ADR-0021; no new port method. `MindOpKind`'s closed set gains one value, `meetingIrExtracted` (§1.2, decided) — a vocabulary addition the enum's own doc comment anticipates as a reviewable, non-mechanical change, not a contract-shape change. |
| Which conformance tests become invalid? | None identified. `SearchIndex`'s crypto-shred test (`removing_a_meeting_makes_it_unfindable`) continues to hold and gains coverage (IR fields must also be gone after `remove`) rather than being invalidated. |
| Which benchmarks must be re-run? | None — no benchmark exists yet for `SearchIndex::insert`/`search` at IR-extended scale; Stage 2 should add one before the FTS text grows per-meeting (topics/decisions/action items concatenated in), since AND-term lexical search over a larger blob is the one measurable cost this ADR introduces. |
| Which review roles must re-review? | Chief Architect, Edge Architect (this ADR — both reviewed, "approve with changes," incorporated). Stage 2 G0: Rust Architect (schema change inside an owned crate — `airo_mind_core::store`/`search`, plus the flat-line-format extension for nested `Vec<Decision>`/`Vec<ActionItem>`/`Vec<Metric>` fields, per Edge Architect review), Chief Performance Officer (FTS-blob growth and unbounded append-only-file growth per re-save, both flagged in Consequences below, per Chief Architect review), Chief Security Officer (pulled forward to Stage 2, not deferred to #1719 — the `MeetingEmbeddingStore` gap in §5/§6 is a privacy-relevant persistence gap the moment IR text starts flowing into it, per Edge Architect review). Chief Security Officer again whenever #1719's crypto-shred implementation lands (content-key handling). |
| Is G0 required again? | No — no crate's public surface changes in this ADR; Stage 2's actual code changes will need their own G0 pass since they do touch `airo_mind_core`'s public types. |

## Consequences

### Positive

- Zero new storage engine, zero Drift/sqflite in `feature_mind` — the
  constraint #1657 states holds by construction, not by discipline.
- The write path is forward-compatible with #1213-#1220 landing the real
  operation log: the `OperationLogPort.append` call is made now, degrading
  gracefully, so no history has to be reconstructed once the log is real.
- Evidence-resolution and crypto-shred both ride existing mechanisms
  (`transcript.json` segment ids; `Meeting`-scoped deletion) rather than
  inventing new ones, keeping the "IR is not a new subsystem" framing
  honest.

### Negative

- IR's lifecycle is fully coupled to the meeting's (§5): no independent
  edit/shred of IR without touching the whole meeting record. Flagged, not
  resolved — acceptable for v1, a real constraint if a future need to
  shred/correct IR independently of the transcript arises.
- The FTS index (`SearchIndex`) grows per-meeting as IR text is added to the
  tokenized blob; no benchmark exists yet to say this is fine at scale. The
  same growth also hits `MeetingStore`'s append-only file directly — it is
  compaction-free (`re_saving_appends_and_the_latest_wins`'s own test asserts
  two lines on disk for one logical edit), so adding three IR fields widens
  every re-saved line further, a disk-growth risk distinct from the
  search-cost one (per Edge Architect review).
- **`MeetingEmbeddingStore` has no staleness invalidation at all**, IR or not
  — `SemanticSearchRanker._vectorFor` returns a cached vector unconditionally
  once one exists, with no comparison against current
  `transcript+minutes(+IR)` text (`semantic_search_ranker.dart:75-87`, per
  Edge Architect review). This predates this ADR, but extending the embedded
  text to include IR (§3) makes the bug more visible: a meeting embedded
  before its IR was extracted keeps serving a stale vector indefinitely,
  unlike `SearchIndex`, which always re-tokenizes fresh on `insert()`
  (`search.rs:78`). Not a blocker for this ADR — flagged so Stage 2/3 doesn't
  mistake the two caches as having matching freshness guarantees.

### Risks

- **#1719 is a hard external dependency for AC4.** If it does not land, #1657
  cannot be closed as originally worded no matter how correct Stage 2/3 are.
- **`MeetingEmbeddingStore` has no clear/remove path** (§5/§6) — a second,
  currently-untracked deletion gap alongside #1719, and the one most likely
  to be missed because it sits in `feature_mind`, not `rust/`, and is easy to
  assume "covered by whatever #1719 builds" when it is not automatically.

## Alternatives Considered

### Alternative 1: IR as a sibling record, keyed by meeting id, in a new Rust store

Rejected. Reintroduces a second shred call site (§5) — exactly the failure
mode "no parallel store" and AC4 both warn against — for no benefit over
fields-on-`Meeting`, since nothing in the current design needs IR to have an
independent lifecycle from its meeting.

### Alternative 2: Promote action items to real entity-graph verb operations now

Considered in §2. Rejected for v1: would give action items generic-graph
queryability today, but at the cost of maintaining two copies of the same
fact (verb operations in the log, and fields on `Meeting`) until a future
migration collapses IR-on-`Meeting` onto real operations wholesale — that
migration is exactly what #1213-#1220 landing the real operation log makes
possible cleanly, later, once, rather than twice now.

### Alternative 3: Build crypto-shred as part of this contract's write-path stage

Rejected. #1657's own instruction is explicit: don't invent a crypto-shred
implementation in the contract pass. #1719 exists precisely so shred is
scoped and built once, correctly, rather than as a rushed dependency of IR
persistence.

## Questions posed to review, and their resolution

Posed to Chief Architect and Edge Architect; all three resolved by their
reviews rather than left open:

1. **`MindOpKind` vocabulary** (§1.2). Resolved: add a new value
   (`meetingIrExtracted`), do not reuse `inference`. Chief Architect
   recommendation, adopted verbatim — see §1.2 for the reasoning.
2. **Entity-graph promotion timing** (§2, Alternative 2): whether deferring
   action items out of `EntityGraphProjection` for v1 is acceptable, or
   whether cross-meeting "which items assigned to me" queries need
   graph-level reach sooner. Resolved: Chief Architect confirmed the
   deferral is "architecturally sound for v1" — `EntityGraphProjection`
   exists and is a real capability, so Alternative 2 is a genuine deferral,
   not a strawman. No change needed; revisit only if a concrete cross-meeting
   graph query need arises before #1213-#1220 lands.
3. **IR-on-`Meeting` coupling** (§5): whether the crypto-shred-for-free
   argument justifies the lifecycle coupling, given #1719 means the benefit
   isn't exercised yet. Resolved: Chief Architect accepted the coupling
   tradeoff, conditional on §5's framing being corrected to avoid implying
   present-day shred coverage — done above, and further tightened by Edge
   Architect's finding that `MeetingStore` has no delete method either and
   `MeetingEmbeddingStore` has no clear path at all (§5/§6, now an explicit
   tracked gap rather than an assumed "for free" win).

## Related Decisions

- [ADR-0021](0021-mind-runtime-port.md) — the frozen `MindRuntime` port this
  design writes through and does not widen.
- [ADR-0017](0017-airo-mind-revocation-ledger-growth-and-package-framing.md) —
  revocation ledger shape; `RevocationSubject{kind: content}` is the frozen
  shape any future shred call (#1719) must use.
- [ADR-0018](0018-airo-mind-model-acquisition-and-trust.md) — provenance
  discipline (`model_id`, `prompt_version`) `MeetingIr`'s `Meeting.model_id`
  already follows.

## References

- Issue [#1657](https://github.com/DevelopersCoffee/airo/issues/1657) — full
  acceptance criteria and the Wave-0 rust-architect audit comment and design
  proposal comment this ADR formalizes.
- Issue [#1719](https://github.com/DevelopersCoffee/airo/issues/1719) —
  crypto-shred gap, blocks AC4.
- `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md` — port freeze and
  `RevocationSubject` shape.
- `docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md` — #508's
  scope, cited in §3.
