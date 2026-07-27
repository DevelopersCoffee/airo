# Airo Mind — Local-First Personal Intelligence Runtime

Status: **Design approved, pre-implementation.**
Date: 2026-07-27
Owner: Chief Architect (Airo Engineering Council)
Supersedes: nothing. Constrained by `docs/PLATFORM_CONSTITUTION.md` (binding).

---

## 1. What this is

Airo Mind is a **runtime**, not an application. It stores a user's personal
knowledge as an immutable, signed, encrypted operation log replicated across
that user's own devices, and it renders that log through projections. Every
domain — notes, health, property, finance, meetings — is expressed as a
**capability**: declarative data that the runtime interprets. The runtime
contains no domain knowledge.

The architectural test the design is held to:

> **If adding a new domain requires changing the runtime, the abstraction is
> too specific.** The runtime evolves for new platform capabilities, never for
> new business domains.

Cloud optional. Never cloud required. The knowledge lives on the user's
devices, not on Airo's servers.

## 2. The seven primitives

The runtime understands exactly seven things. Everything else is derived.

| Primitive | Definition |
|---|---|
| **Identity** | A cryptographic identity and the device keys derived from it. Signs every operation. |
| **Operation** | An immutable, signed record of a change. Plaintext header, encrypted payload behind a `ContentID`. The only synchronized unit. |
| **Content** | An encrypted content object addressed by `ContentID`. Holds all user data. Never inlined into an operation. |
| **Context** | A user-data node that groups content — a hospitalization, a project, a year, a person, a topic. Contexts form a hypergraph; content links to many. |
| **Capability** | Software shipped as data: schema, views, workflows, automations, queries, prompts, policies, migrations, assets, localization. Owns no user data. |
| **Projection** | Anything derived by replaying the log: the knowledge graph, timeline, calendar, search index, embeddings, task lists, analytics. Always rebuildable, never authoritative. |
| **Vault** | Identity, keys, revocations, trust, device certificates. The only mutable, non-append-only store in the system. |

Nothing else is first-class. "Graph", "database", "note", "hospital" do not
appear in runtime contracts.

## 3. The log is the only source of truth

```
Operation Log
   ↓
Capabilities (schema, migrations)
   ↓
Replay
   ↓
Projections  (graph │ timeline │ search │ embeddings │ views)
```

The graph is **not** synchronized. The log is synchronized. The graph is
rebuilt. Any projection may be dropped and regenerated without data loss.

### 3.1 Operation shape

```
Operation
├── Header  (plaintext, immutable, signed)
│     operationId
│     parentOperationId
│     entityId
│     contextIds[]
│     schemaId          (fingerprint — see §5.5)
│     capabilityId
│     deviceId
│     timestamp
│     versionVector
│     payloadHash
│     signature
└── ContentRef → ContentID
```

The header stays plaintext so merge, ordering, and DAG traversal work without
decrypting anything. **Known consequence:** a device that has been
crypto-shredded still proves, from headers alone, that N operations existed
under a given capability and entity type. Header minimization and on-the-wire
header protection are requirements on subsystems 2 and 7, not afterthoughts.

### 3.2 Verbs

There is no `Delete`. Deletion is ambiguous and the ambiguity is dangerous.

```
Entity     CreateEntity     SetProperty      AddRelation      RemoveRelation
Content    CreateContent    LinkContent      UnlinkContent    DestroyContent
Context    CreateContext    LinkContext      UnlinkContext
Capability InstallPack      UpgradePack      RemovePack       EnablePack   DisablePack
Vault      AuthorizeDevice  RevokeDevice     RevokeContentKey
```

Entity mutation is property-granular: `SetProperty` carries one property, so
merge strategy is resolved per property (§5.3) rather than per entity, and two
devices editing different fields of the same entity never conflict.

`UnlinkContent` removes one context link. `DestroyContent` removes every
wrapping and is irreversible. The UI must never conflate them, and the confirm
dialog must state which one is about to happen and what survives.

## 4. Content, keys, and real deletion

### 4.1 Envelope encryption over a context hypergraph

Content does not belong to a hierarchy. It belongs to a **set of contexts**.

```
Content Object
   ↓ encrypted under
Content Key (random, per object)
   ↓ wrapped separately under each granting context
wrap(CK, HospitalizationContextKey)
wrap(CK, FinanceContextKey)
wrap(CK, TaxYear2026ContextKey)
```

Content remains recoverable while **at least one valid wrapping exists**.

This is the property that makes a shared graph possible: a hospital bill is one
object, simultaneously a medical record, an expense, and a deduction. Closing
the hospitalization unlinks it; the tax context keeps it alive. Restructuring a
user's history — merging two journeys, re-filing a decade of documents — moves
no content and rewrites no history. It only adds and removes context links.

### 4.2 Retention classes

Every content object declares one.

| Class | Behavior |
|---|---|
| `permanent` | Destruction requires explicit confirmation. |
| `recoverable` | Unlinked into a recycle context for 30 days, then destroyed. |
| `ephemeral` | Destroyed automatically once its derived artifact exists (e.g. a transcript after summarization). |
| `secret` | Never cached outside encrypted storage. No thumbnails, no previews, no analytics, no model training, no plaintext temp files. |

### 4.3 Crypto-shredding

`DestroyContent` is not a flag. It is:

1. Destroy the content key in the Vault.
2. Append `RevokeContentKey` to the revocation ledger.
3. Delete the local encrypted blob.
4. Delete derived projections referencing the object.
5. Delete embeddings.
6. Delete search index entries.
7. Delete AI caches.
8. Invalidate snapshots referencing the object.

The operation log survives intact — signatures still verify, structure is
preserved. The content is cryptographically unrecoverable on every device that
replays the revocation.

Steps 4–8 are the ones that get skipped and quietly defeat the guarantee. An
embedding of a destroyed note is a lossy copy of that note. Test coverage for
derived-state purge is a release gate, not a nice-to-have.

Derived state also includes several things outside the app's own storage, all
of which must be swept:

- OS share, QuickLook, and thumbnail caches, and system-wide search indexes
  outside the app sandbox
- Notification content, clipboard contents, and undo stacks
- Crash-reporter and analytics payloads that captured content
- The `recoverable` recycle context from §4.2 — a destroy must sweep the
  30-day holding area, not merely stop showing it

Two things are permanently outside a destroy's reach and must be named in the
confirmation dialog rather than silently omitted: **previously exported
Recovery Packages and capsules.** They are files the user already placed
elsewhere; nothing in this design can recall them.

Finally, the runtime does not currently *enforce* steps 4–8 anywhere. Marking
the purge directive `#[must_use]` is a nudge that any caller defeats with
`let _ =`. Making revocation transactional — incomplete until every
derived-state owner acknowledges — is a Phase 2 requirement, and until it lands
the honest statement is that purge is convention, not mechanism.

## 5. Capabilities

### 5.1 A capability is data, not code

The runtime executes the capability. The capability never executes itself.
This is the single most important security property in the system, given that
the device holds medical and financial records.

Three tiers:

| Tier | Author | Contains |
|---|---|---|
| **1 — Declarative** | Community | manifest, schema, views, workflows, automations, queries, prompts, assets, translations. No executable code. |
| **2 — Sandboxed expressions** | Community | Tier 1 plus a pure expression language: no network, no file access, no threads, no native APIs, no reflection, no unbounded loops. |
| **3 — Native** | Airo only, cryptographically signed | Rust / Dart / native SDKs. OCR engines, parsers, specialized models. Not authorable by the community. |

**v1 implements Tier 1 only.** Tiers 2 and 3 are deferred.

### 5.2 Existing plugin code: what survives

`packages/core_domain/lib/src/plugins/` already contains `PluginManifest`,
`ManifestValidator`, `PluginRegistryService`, `PluginLoaderService` (9-state
lifecycle), `PluginDownloaderService`, and `KillSwitch`. Those are reused as
the basis of the capability manifest, validation, install lifecycle, and
kill-switch.

Two fields are **deleted**, not extended:

```dart
final String entryPoint;    // "Entry point Dart file"
final String initFunction;  // "Initialization function name to call on load"
```

They encode exactly the code-delivery model this design rejects.

### 5.3 Type system

```
Primitive Types → Archetypes → Core Ontology → Capability Entities → Property Overrides
```

**Primitives and default merge:**

| Primitive | Default merge |
|---|---|
| `string` | lww |
| `text` | revisions |
| `bool` | monotonic |
| `number` | lww |
| `datetime` | lww |
| `list` | union |
| `set` | union |
| `reference` | union |
| `blob` | hash |

**Archetypes (abstract, 12).** Never appear in user data. Define merge,
timeline behavior, indexing, storage, retention, search, audit, permissions.
No business meaning.

```
Actor  Artifact  Activity  Record  Measurement  Event
Workflow  Collection  Location  Resource  Relationship  Configuration
```

**Core Ontology (concrete, 12).** Built into the runtime, never redefinable.

```
Person  Organization  Conversation  Document  Task  Journey
CalendarEvent  Reminder  Place  Device  Media  Note
```

`Person extends Actor`, `Task extends Workflow`, `Document extends Artifact`,
`Conversation extends Activity`.

**Capability entities extend the Core Ontology only** — never an archetype
directly. This is what guarantees interoperability: a Home Buying capability
and a Finance capability both understand the same `Person`, `Task`,
`Document`, and `Journey` without translation.

**Merge resolution precedence**, most specific first:

```
1. Safety class veto      medical / financial / legal / identity → forced manual or immutable
2. Property override      explicit `merge:` on the property
3. Archetype rule         the archetype's rule for that primitive
4. Primitive default      the table above
```

Safety class sits **above** property override deliberately. An author cannot
declare `merge: lww` on a dosage field in a `medical` capability and have the
runtime honor it. Validation rejects the capability rather than silently
downgrading the rule.

Domain meaning is carried by labels, not by types:

```yaml
entity: Doctor
extends: Person
labels: [Doctor, Clinician]
properties:
  speciality: { type: string }
```

### 5.4 Safety class

Every capability declares one, and it binds runtime behavior.

| Class | Rule |
|---|---|
| `medical` | Never auto-merge. Never AI-resolve. Always user review. |
| `financial` | Amounts require manual review. |
| `legal` | Manual review. Full audit trail. |
| `identity` | Immutable after creation. |
| `system` | Runtime-reserved. |
| `general` | AI-assisted merge permitted. |

**Safety class ratchets.** A capability may declare a stricter class than its
lineage implies, never a looser one. A self-declared `general` on an entity
extending a `medical`-classed ontology node is rejected at validation. Author
self-declaration alone is not a safety control.

### 5.5 Schema fingerprint and compatibility

```
Schema → canonical serialization → SHA-256 → schemaId
```

Every operation stores the `schemaId` it was written under.

| Compatibility class | Meaning |
|---|---|
| `compatible` | Additive. No migration. |
| `compatible+` | Migration required. |
| `breaking` | New lineage. Not a version bump. |

Merge strategy is part of the schema contract and cannot change within a
compatible version. Changing a property from `lww` to `manual` in a minor
release makes two devices merge the same operation differently and diverges
the graph permanently.

### 5.6 Pack version is graph state

Installing or upgrading a capability is an operation in the log:

```
Operation #2041
  InstallPack
    id: notes
    version: 2.1.0
    schemaId: sha256:…
    migration: sha256:…
```

Every device replays it at the same position and derives identical state. There
is no "phone updated, laptop outdated" — only "the laptop has not replayed
operation #2041", which is the thing sync already fixes. Schema divergence
becomes structurally impossible.

Consequence: a marketplace can never silently push an update. Upgrading is an
explicit user action on one device that propagates as history. For a system
holding medical records this is the correct behavior.

### 5.7 Migration transforms interpretation, not data

```
Stored Events → Migration Chain → Canonical Events → Projections
```

The original operation is never rewritten. Migrations must be **pure, total,
and forward-only** functions over operations, because every device derives
state by running them independently and must reach the same result.

Migration is declarative and ships inside the capability:

```yaml
migrations:
  - from: 1.0.0
    to: 2.0.0
    rename: { notes: clinicalNotes }
  - from: 2.0.0
    to: 3.0.0
    split:
      address: [city, state, country]
```

### 5.8 Contexts belong to the user, not the capability

A capability ships **context templates**. Instantiating one produces a context,
which is user data and outlives the capability.

```
Capability
   ├── Context Templates
   ├── Entity Schemas
   ├── Views
   ├── Workflows
   ├── Policies
   └── Automations
        ↓ instantiate
      Context (user data) → Operation Log
```

Removing the Hospital capability does **not** remove the hospitalization
context. The capability is simply no longer available to render specialized
views or create new contexts of that kind. Uninstalling software must never
delete a decade of a user's life.

## 6. Identity, Vault, and recovery

Three things are independently required. Losing any one is fatal in a different
way:

| Lost | Result |
|---|---|
| Identity | Cannot authenticate a new device. |
| Log | History gone. |
| Vault | Content encrypted forever. |

### 6.1 Recovery Package

Contains enough to regain access. Not the log. Not the content.

```
Recovery Package
├── Identity        (derived from a BIP39-style seed shown once at setup)
├── Vault           (keys, wrappings, trust, device certificates)
├── Revocation Ledger
└── Metadata
```

Placed by the user wherever they choose — inside a capsule file, their own
cloud storage, a NAS, a USB stick. Never on Airo servers.

### 6.2 Restore is revocation-aware

A Vault backup made yesterday contains keys for content destroyed today.
Restoring it naively resurrects shredded medical records — the user's own
backup defeating the user's own cryptographic deletion.

Mandatory restore order:

```
Load Recovery Package
   ↓
Load Operation Log
   ↓
Replay revocation ledger to head
   ↓
Destroy every key revoked since the backup
   ↓
Only now decrypt remaining content
```

Nothing is decryptable before the revocation replay completes. A Vault backup
format without a monotonic revocation epoch can never be made safe, so this is
a v1 format requirement.

Type-state enforcement of this ordering closes the "caller forgot" hole but not
the "caller supplied an empty ledger" hole. The revocation source must
therefore carry provenance — replayed from the log, package-only, or
explicitly acknowledged as blind — and a blind restore must warn the user.

### 6.3 The bound on erasure

Erasure durability is bounded by the freshness of the revocation ledger a
restoring device can obtain. A device restoring from a stale backup with no
access to the operation log cannot know about destructions performed elsewhere,
and will decrypt content the user believes is gone.

This is a permanent property of a serverless architecture, not a defect
awaiting a fix. There is no authority to ask. Product copy must not imply
otherwise — see the permitted wording in
`2026-07-27-airo-mind-roadmap.md` §5.

## 7. Trust boundary — v1

There is exactly **one trust domain: the user's own device mesh.**

```
User
 ├── Phone
 ├── Laptop
 ├── Desktop
 └── Tablet
```

Everything outside is outside. Giving data to another person has exactly one
mechanism:

- Capsule export
- Explicit selection of contexts, content, and keys
- One-way
- **No revocation claimed**
- No synchronization
- No collaborative editing

Human-to-human key delegation with revocation is not in v1. Once a key reaches
a device the user does not control, revocation is unenforceable — the holder
already has plaintext. Claiming otherwise would be a false security promise.

Permitted capsule copy: *"You choose what to include. Once exported, it is
theirs — it cannot be recalled."* The words "revocable", "time limited", and
"you stay in control" are prohibited on this surface.

Two further constraints follow from the single trust domain:

- **Device revocation is required, not optional.** A stolen or compromised
  device that cannot be evicted makes this boundary decorative. Revocation must
  cover devices and context keys, not only content, and a restored backup must
  not resurrect a revoked device certificate.
- **Key material never crosses the FFI boundary**, with exactly one
  acknowledged exception: the recovery mnemonic, at onboarding and at restore.
  Those two paths are prohibited from logging, crash-reporter capture, and
  analytics.

## 8. Runtime / Experience separation

```
Airo Runtime            Identity  Vault  Operation  Content  Context  Capability  Projection
────────────────────────────────────────────────────────────────────────────────────────────
Experiences             Notes   Wellbeing   Brain   TV   Media   Health   Developer
```

Mind is the operating system. Brain, TV, Notes, Wellbeing are consumers.

**Repository posture.** The eventual `runtime/` + `capabilities/` + `sdk/`
layout is correct long-term, but physically relocating ~70 packages, melos
globs, every import, CI, and signing config is a whole-repo migration that
would block this milestone entirely — the same scope trap that stalled the
`apps/airo_tv` split. v1 adopts the separation as **naming and `module.yaml`
ownership**; the physical move is a separate milestone after Notes ships.

## 9. Where the code goes

Constrained by `PLATFORM_CONSTITUTION.md` §2 and §4.

| Layer | Home |
|---|---|
| Vault, op log, content store, replay, projections, merge, capability interpreter, sync | `rust/airo_mind` — new workspace crate, **not** inside `airo_core` |
| FRB bindings | `packages/core_native/lib/src/mind/` — §2 puts all FFI in `core_native` |
| Dart contracts for the seven primitives | `packages/core_mind_contracts` (no Flutter imports) |
| Runtime orchestration | `packages/platform_mind_runtime` (vault, log, projection, context) |
| Capability SDK — manifest, DSL parse/validate, migration | `packages/platform_mind_capability` |
| Discovery, transport, session crypto, op exchange | `packages/platform_mind_sync` |
| Mind shell UI, capture, search, timeline | `packages/feature_mind` |
| Notes reference capability | `packages/feature_mind_notes` |
| Shell registration | `core_product_shell` `AppModule` — depends on #1187 |

**Why a separate Rust crate.** `airo_core` is described as "playlist, EPG,
search and dedup" and is on the shipping critical path for Airo TV. Adding
crypto, an embedded database, and sync to it puts binary size, build time, and
regression risk onto a product that needs none of it. Separate crate, separate
FRB codegen target, separate size budget.

**Constitution obligations, non-negotiable:**

- **§4 Rust admission test.** Justification is cross-platform reuse and
  determinism that Dart cannot serve — replay must produce byte-identical
  results on every device and platform. A `packages/benchmarks` entry is still
  required for the merge and replay paths.
- **§6 dependency governance.** Every new Rust crate (crypto, embedded DB,
  CRDT) goes through `platform_dependency_governance` scoring and
  chief-open-source-officer review before it lands.
- **§6 generated-code budget.** Generated files over 200 KB require schema
  splitting. The FRB surface must be partitioned by subsystem from the first
  commit, not consolidated and split later.
- **§3 capability-first.** `module.yaml` for every new package must declare
  capability ID, supported devices, and ship policy. **Airo Mind is
  `Never Ship` on TV** — it is a personal-device runtime.
- **§1.** `app/lib/` gets routing and DI wiring only.

## 10. Build order

Build a thin vertical slice through all seven primitives first. The operation
format and the Vault key hierarchy are the two decisions that cannot be
retrofitted; they must meet real data as early as possible, not be designed in
isolation for months.

| Phase | Subsystem | Proves |
|---|---|---|
| 1 | **Vault** — identity, key hierarchy, envelope wrapping, revocation ledger, seed recovery, Recovery Package export/restore | Erasure and recovery are real |
| 2 | **Operation Log** — signed header/payload operations, `ContentID` indirection, content store, deterministic local replay | The op format survives real data |
| 3 | **Projection Engine** — replay to projections; graph, timeline, full-text | Replay cost is bounded |
| 4 | **Capability SDK** — manifest, four DSLs, type system, safety class, fingerprint, compatibility classes, declarative migration, validator | A capability is data, not code |
| 5 | **Context Runtime** — template instantiation, context hypergraph, link/unlink/destroy, lifecycle independent of capability | Uninstalling a capability keeps user data |
| 6 | **Notes capability + Mind shell** — reference implementation, `AppModule` registration | The whole stack, on one phone |
| 7 | **Sync** — mDNS `_airomind._tcp`, mutual auth, session crypto, version vectors, op exchange, archetype-driven merge, conflict review UI | Two devices converge |
| 8 | **Workflow + Automation** — generic state/transition, trigger/condition/action, cross-device idempotency | Automations do not fire twice |
| 9 | **AI Runtime** — extraction, summarization, merge *proposals* only | AI never silently writes |

Phases 1–6 ship a usable single-device product: **a local-first, encrypted,
capability-driven notes application built entirely on the Airo Mind runtime.**

Notes is the right first capability precisely because it is the smallest domain
that exercises every subsystem — text revision merge, contexts, content
encryption, search projection — and it carries zero regulatory surface.

## 11. Explicitly out of scope for v1

- Marketplace, community capability distribution, moderation, review workflow
- Tier 2 sandboxed expressions; Tier 3 native capabilities
- Domain capabilities: Hospital, Property, Tax, Wedding, Finance
- MCP, agent skills, AI app builder ("describe an app and it appears")
- Human-to-human sharing, key delegation, collaborative editing
- Cloud relay, NAS, Bluetooth, Wi-Fi Direct, USB transports — LAN/mDNS only
- Physical repository restructure to `runtime/` + `capabilities/`

Each is a follow-on milestone. None is a prerequisite.

## 12. Open decisions, assigned to subsystem specs

These are deliberately unresolved here. Resolving them without implementation
evidence would be guessing.

| Question | Decided in |
|---|---|
| Are snapshots authoritative or cache-only? Cache-only preserves the "log is truth" guarantee but makes cold start slow; authoritative reintroduces a second source of truth. Replay cost grows as `log_length × migration_chain_depth`. | Phase 3 |
| Header metadata leak. `entityId` / `schemaId` / `capabilityId` survive crypto-shredding in plaintext and may be observable on the wire. Existing redaction precedent: `platform_network_discovery` (`prohibitedFieldName`, `credentialLikeValue`). | Phases 2 and 7 |
| Automation idempotency. Two devices replaying the same trigger must not produce two reminders. Single-executor election, or deterministic operation IDs derived from trigger state? | Phase 8 |
| Conflict review UX. How a `manual`-merge conflict on a medical field is surfaced without training users to tap Accept. | Phase 7 |

## 13. Relationship to existing milestones

| Milestone | Disposition |
|---|---|
| **13 — Airo Brain & Local AI Superpowers** (52 open) | Brain becomes a **capability** consuming the Mind runtime. Memory Graph is no longer a Brain feature; it is a projection. Issues #297 (Memory Vault), #298 (entity extraction), #299 (Memory Graph) move to Airo Mind — they are phases 1, 9, and 3. Brain keeps model management, chat UX, LiteRT/Gemini Nano runtime. |
| **14 — LifeTrack & Habit Engine** | `TrackStateMachine` and `LifeTrackTemplate` are the seed of phase 8's generic workflow engine. LifeTrack becomes a capability. |
| **16 — Modular Plugin Architecture** | `core_domain/plugins/*` becomes the capability manifest and install lifecycle (§5.2). Issue #1187 (`core_product_shell` composition) **blocks phase 6**. |
| **17 — On-Device Perception** | Feeds phase 9. Vector search (#355) becomes a projection. |

`app/lib/features/mind/` — the current 360-line wellbeing hub (daily quote,
breathing, reflection) — is renamed to `app/lib/features/wellbeing/`. The name
"Mind" is reserved for the runtime.
