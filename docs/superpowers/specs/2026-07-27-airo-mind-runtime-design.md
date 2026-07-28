# Airo Mind — Local-First Personal Intelligence Runtime

Status: **FROZEN at v1** — see `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`.
Changes to primitives, invariants, contracts, the package format, the public
API, the sync model, or the security model require an ADR in `docs/adr/` with
all seven required architecture sections.
Date: 2026-07-27
Owner: Chief Architect (Airo Engineering Council)
Supersedes: nothing. Constrained by `docs/PLATFORM_CONSTITUTION.md` (binding).
Contracts: `2026-07-28-airo-mind-runtime-contracts.md` (C1–C7, versioned ABI).

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
| **Vault** | Identity, key hierarchy, context keys, revocation ledger, device certificates, policies. The only mutable, non-append-only store in the system. **Sized by contexts and devices, never by content.** |

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
│     payloadHash      (over CIPHERTEXT, never plaintext — see below)
│     signature
└── ContentRef → ContentID
```

**Header disclosure rule.** Headers may reveal the structural metadata replay
requires — ordering, parentage, entity and context identity, schema. They must
never reveal anything that lets an observer **distinguish identical user
content after crypto-shredding**.

`payloadHash` is the first application of that rule, not the whole of it. Any
future header field is checked against it.

`payloadHash` covers the **ciphertext**, or is a MAC keyed under the content
key. Hashing the plaintext would make the header an **equality oracle** —
confirmation-of-file against a crypto-shredded device, using exactly the
headers this section admits survive shredding. Free to fix here, expensive
once the format is frozen.

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
Content Object                     ← lives in the CONTENT STORE
   ↓ encrypted under
Content Key (random, per object)
   ↓ wrapped separately under each granting context
wrap(CK, HospitalizationContextKey)   ← stored WITH the content object
wrap(CK, FinanceContextKey)
wrap(CK, TaxYear2026ContextKey)
```

Content remains recoverable while **at least one valid wrapping exists**.

**The wrapping set lives with the content object, not in the Vault.** This is
load-bearing and was got wrong in the first draft.

The Vault holds the **context keys** — O(contexts) — plus identity, device
certificates, the revocation ledger, and policies. It never holds a per-content
record. The content store already owns content; the Vault owns only keys.

Stated as a rule, because two sentences in the first draft described different
systems:

> *"The Recovery Package grants access; carries no data"* cannot coexist with
> *"one envelope per content object."* **The Vault is sized by contexts and
> devices, never by user content.**

Put positively: **the Vault is responsible for authority, not inventory.**

```
Vault
 ├── Identity
 ├── Trust
 ├── Keys
 ├── Revocations
 └── Policies
```

It must never be able to answer:

- How many documents exist?
- Which content exists?
- What contexts contain this object?

Those are content-store and projection questions. A Vault that can answer them
is a Vault that has to be backed up, synced, and shredded like content — which
is how it became O(all user content) in the first place.

Measured consequence of getting this wrong: a 100k-content vault serialized to
a 225 MiB Recovery Package with a ~600 MiB export peak — an out-of-memory
failure on mid-range Android, on the one artifact whose absence is
unrecoverable. See #1305.

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

1. Destroy every wrapping of the content key, in the content store.
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

## 11a. Runtime invariants

Non-negotiable. These are not guidelines and not subject to a capability's
judgement. A change that violates one of these is a defect regardless of what
it enables.

### I1 — Only the operation log and the encrypted content store are durable

Everything else is a **projection** and must be disposable.

```
Durable          Operation Log · encrypted Content Store
Disposable       knowledge graph · memory graph · search index · FTS
                 embeddings · AI cache · timeline · calendar · analytics
```

Two consequences, both testable:

- **Destroying a projection must never lose data.** Any projection can be
  deleted at any time and rebuilt from the log. If a value exists only in a
  projection, it is a defect, not a feature.
- **Destroying content must invalidate every projection derived from it.**
  Otherwise crypto-shredding is incomplete by construction — an embedding of a
  destroyed note is a lossy copy of that note.

### I2 — No capability may create durable storage outside the runtime

A capability that wants persistence has exactly one path:

```
Capability → Operation → Content → Operation Log
```

Never a private SQLite database, a JSON file, a preferences entry, a cache
directory, or any other store it owns.

This is not tidiness. The moment a capability writes durable state the runtime
cannot see, `DestroyContent`, backup, recovery, sync, projection rebuild, and
crypto-shredding all become **incomplete by construction** — each one silently
missing whatever that capability kept to itself. The user is then told their
data was destroyed while a copy survives in a file nobody enumerated.

Enforcement is a Phase 4 requirement on the capability runtime, not a review
convention: a Tier 1 capability has no filesystem access to violate this with,
and Tier 2's sandbox prohibits file access outright (§5.1).

### I3 — Every claimed security property has an automated tamper test

If this document, a store listing, or a UI string claims a security property,
a test must demonstrate it by attempting the violation and observing failure.

```
Claim:  the header AAD authenticates revocation_epoch
Test:   modify revocation_epoch → decrypt fails
```

Required at minimum for: `revocation_epoch`, `identity_public_key`, package
format version, schema fingerprint, capability manifest hash, content wrapping
`content_id` and `context_id` binding, and device certificate fields.

The reason this is an invariant rather than good practice: revision 2 of the
Phase 1 plan **stated** that the recovery package header was authenticated as
AAD, in the section recording that the review finding had been applied. It was
not. Prose asserting a security property is not evidence that the property
holds, and reviewer memory is not a control.

### I4 — Runtime exclusivity

**All durable user state originates from the runtime.** There is no alternate
persistence path.

```
Capability
    │
    ▼
Operation
    │
    ▼
Runtime
    ├── Operation Log
    ├── Content Store
    └── Vault
```

I2 says a capability must not create durable storage. I4 is the stronger
statement it implies: durable state does not merely *avoid* other paths, it has
exactly one origin.

The distinction matters for classification. Under I4, a feature-owned SQLite
database, JSON file, or object store is not technical debt to be scheduled — it
is an **architectural violation**, and it is named as one. Debt is a trade
someone chose; a violation is a defect that makes `DestroyContent`, backup,
recovery, sync, projection rebuild, and crypto-shredding incomplete for that
feature's data.

Known violations at the time of writing: `DriftMeetingRepository`,
`features/coins/`, `features/money/`, and the settings AI-storage dashboard.
Migration is tracked on #1293.

### I5 — An invariant is not complete until it can fail

**An architectural invariant is not complete until there is a compile-time
constraint or an automated test that fails when it is violated.**

Documentation alone is not evidence. This is not a style preference — it is the
conclusion of three consecutive review cycles on the Phase 1 Vault plan, each
of which found a property *recorded as applied* that was absent from the code:
the header AAD, the revocation subject rewrite, and the `ContentNotFound`
variants that were declared and never constructed.

| Invariant | What makes it complete |
|---|---|
| Header authenticated | Tamper test — modify the field, assert failure |
| Canonical mnemonic | Normalization test — messy input derives the same seed |
| Revocation | Replay test — a stale backup does not resurrect |
| No feature persistence | Architecture CI (§11b) |
| Runtime-only storage | Static analysis |

The failing form comes **first**. An invariant added to a document without its
test is an invariant that will be recorded as applied and will not be.

### I6 — Canonicalize exactly once, at the boundary

Every externally-supplied value passes through a canonicalizer before anything
else sees it. Nothing below that layer ever receives raw input.

```
User / external input
        ↓
   Canonicalizer
        ↓
Canonical representation
        ↓
   Everything else
```

The mnemonic bug is the worked example: `seed_from_mnemonic` validated the
words but handed the *raw string* to PBKDF2, so a pasted phrase with a trailing
newline derived a different seed and surfaced as "wrong seed" while the user's
mnemonic was correct.

Applies to every identifier and every derivation input, not just mnemonics:

| Value | Canonical form |
|---|---|
| Recovery mnemonic | NFKD, single-space-joined, trimmed |
| Entity / context IDs | Slug-validated, case-fixed, no traversal sequences |
| Capability / package IDs | Same, plus filesystem-safe on every OS |
| Paths | Resolved, symlinks followed, confined to a granted root |
| URLs | Scheme and host lowercased, normalized, percent-encoding settled |

A function that accepts a raw value **and** a canonical one at the same type is
a defect: the type must distinguish them, or the raw form must be unreachable
past the boundary.

### I7 — Streaming first

**The runtime processes operations as streams wherever possible.** Never
"load everything, then process".

```
Load everything → Process          ✗
Read → Validate → Replay → Discard  ✓
```

Applies to replay, sync, export, restore, migration, projections, and search
indexing.

**Status: adopted as an invariant, NOT yet satisfiable.** Per I5 this
distinction is recorded rather than glossed — the Phase 1 Recovery Package
format violates I7 by construction, and recording I7 as applied against it
would be the fourth consecutive instance of the failure I5 exists to prevent.

Measured violations, chief-performance-officer:

| Site | Why |
|---|---|
| `RecoveryPackage::export` | Whole-vault materialization; **8.6× blow-up, ~450–600 MiB peak at 100k contents** |
| `RecoveryPackage::to_bytes` | `serde_json::to_vec` over full ciphertext; 3.57× expansion, 444 ms/64 MiB |
| `RecoveryPackage::from_bytes` | Whole file plus parsed copy resident before one byte is verified |
| Single-blob AEAD | One tag over the whole payload — **this is why the three above cannot be fixed without a format change** |
| `Vault` | Entire content-envelope index resident, no paging |
| `#![forbid(unsafe_code)]` | Forecloses `mmap`, the primary zero-copy streaming mechanism |

I7's **failing form**: export a synthetic 100k-content vault, assert peak RSS
is within a constant of a 10k-content vault. It lands with the framed-package
format (#1305) and the storage-layer split (#1307), in one change — never as
prose against a format that cannot satisfy it.

### I8 — Cost is part of correctness

**A runtime feature is not complete until it has an asymptotic complexity, an
allocation budget, a benchmark, and a regression test.**

```
Replay
  O(n) in operations
  peak RSS < X, independent of n
  benchmark in packages/benchmarks
  regression threshold enforced in CI
```

Performance becomes part of the API, not a follow-up. I5 says an invariant is
not complete until it can fail; I8 says the same about a cost.

The evidence this is not theoretical: three of the four council reviews
returned REJECT on findings that were measurable and unmeasured — an 8.6×
format expansion, a 33 s per million operations verification floor, and a 45–58%
throughput loss from a compiler flag nobody had benchmarked. Each was cheap to
measure and expensive to discover.

A performance claim with no number is treated exactly as a security property
recorded as applied and never written.

### Domain types over raw primitives

`KeyBytes` is the pattern, not the exception: an invariant held by a type is an
invariant the compiler enforces on every future call site, including the ones
nobody has written yet.

Prefer domain types over `String`, `Vec<u8>`, `bool`, and `u64`:

`CanonicalMnemonic` · `ContentId` · `ContextId` · `CapabilityId` ·
`OperationId` · `WrappedKey` · `ContentHash` · `RootPublicKey` ·
`RevocationEpoch`

Two defects already found by review would have been impossible with these:
`RevocationSubject` existed while the API still took `&str`, so the tag never
became enforceable; and `Vault::new` accepted any 32 bytes, so a vault could be
built against a root corresponding to no seed in existence.

**The compiler becomes another reviewer** — and unlike the human ones, it reads
every line every time.

This is not a new invariant. It is how I5 is satisfied in Rust.

### The `unsafe` policy

A blanket `#![forbid(unsafe_code)]` on the runtime crate reads as prudence and
is actually a foreclosure: `forbid` cannot be locally overridden, `memmap2`
needs `unsafe` at the call site, and memory-mapped sealed log segments are the
primary tool for replaying a million operations without unbounded memory
growth. The rule would have permanently prevented the technique that makes the
memory budget achievable.

The policy that replaces it:

> **`unsafe` is prohibited unless it is isolated, documented, benchmarked,
> fuzzed, audited, and justified.** All six, recorded, per call site.

Concretely: crypto, vault, merge, replay, and capability logic live in crates
that keep `forbid(unsafe_code)`. Low-level primitives — memory mapping, segment
I/O, group commit — live in one small crate with an audited `unsafe` surface of
two or three call sites, each carrying its six justifications.

`airo_core` already does exactly this, deliberately and reviewed, at
`api/playlist_engine.rs:222` and `:924`.

The general lesson, worth keeping: **a blanket rule adopted for a good reason
ages badly when the reason is narrower than the rule.** The property wanted was
auditability, not absence.

## 11b. Architecture compliance

Invariants that only a reviewer can check are invariants that erode. Every
module declares how it persists, and CI validates the declaration against what
the code actually does.

```yaml
module:
  persistence: runtime | projection | ephemeral
```

| Value | Meaning | Allowed to write |
|---|---|---|
| `runtime` | Durable user state, via operations | Nothing directly — the runtime writes |
| `projection` | Derived, rebuildable, disposable | Its own index or cache, droppable at any time without data loss |
| `ephemeral` | Process- or session-scoped | Temp files, in-memory caches, nothing that outlives a reinstall |

Worked examples:

| Module | Declared | Actual | Result |
|---|---|---|---|
| Meeting | `runtime` | Drift database | **fail** |
| Memory projection | `projection` | rebuildable index | pass |
| Image cache | `ephemeral` | temp files | pass |
| Vault | `runtime` | encrypted keystore | pass |

A module declaring `runtime` that opens a database fails. A module declaring
`projection` whose data cannot be regenerated from the log fails — that one is
only catchable by a rebuild test, so `projection` modules must have one.

## 11c. The runtime API

**A capability never knows where data lives.** It receives a small, fixed
surface:

```rust
emit_operation()
attach_content()
query_projection()
instantiate_context()
replay()
sync()
```

Nothing else. No SQL. No filesystem. No encryption primitives. No key material.

`replay()` and `sync()` are on the list deliberately: they are the same
operation stream at different scope, not two mechanisms. See §11d.

When a capability needs something outside this surface, the **default
assumption is that the runtime is missing a generic primitive** — not that the
capability should reach around it. Adding it to the runtime serves every
capability; adding it to the capability serves one and creates an exception
that outlives whoever approved it.

This is what makes I2 and I4 enforceable rather than aspirational: a Tier 1
capability is declarative data and has no way to reach a filesystem, and a
Tier 2 capability's sandbox prohibits file and network access outright (§5.1).
The API is the only door, so the invariant holds by construction instead of by
review.

It is also the compatibility boundary. Storage can move from SQLite to
something else in 2035 without touching a single capability, because no
capability ever named a storage engine.

### The test every capability is judged by

> **Can it be implemented entirely by emitting operations and consuming
> projections?**

If no, exactly one of two things is true:

1. **The runtime is missing a generic capability** that should be added once,
   for everyone — in which case add it to the runtime, not to the feature.
2. **The feature is attempting to bypass the runtime** — in which case the
   answer is no.

There is no third branch, and in particular there is no "this feature is
special". Meeting intelligence is the current test of this: it is a capability
that captures audio, transcribes, extracts entities, emits operations, and
builds notes, tasks, and calendar events. It is **not** a runtime feature, and
it gets no privileged storage path.

## 11c-2. The snapshot contract

```
Operation Log
     │
     ▼
Verified Snapshot        ← carries the watermark it was built at
     │
     ▼
Replay after watermark   ← below it, no re-verification
```

**Snapshots are cache-only.** They may be deleted at any time and rebuilt from
the log, so I1 holds.

**The verified-prefix watermark is part of the runtime contract.** An operation
is verified exactly once, when it enters the log — locally or from sync. The
log persists *"operations up to (device, seq) N have been verified by this
device"*. Replay below the watermark skips verification; replay above it
verifies. Snapshots carry the watermark they were built at.

This is what makes cache-only affordable. Measured: ed25519 verification is
32.9–36.3 µs per operation and 50–80× everything else in replay combined, so
without the watermark, cold start costs 33 s per million operations **forever**
— and the pressure to make snapshots authoritative, reintroducing a second
source of truth and voiding I1, becomes irresistible.

**The watermark is what protects the invariant.**

## 11c-2b. Control plane / data plane

The runtime carries two responsibilities that must not be entangled.

```
Runtime
│
├── Control Plane          — manages EXECUTION
│     Supervisor · Scheduler · Resource Manager · Lifecycle
│
└── Data Plane             — manages DATA
      Operation Log · Content Store · Vault · Replay · Sync · Projections
```

This matters most when the AI engines arrive. Speech recognition, OCR,
embeddings, and local LLM inference are long-running workloads that request
CPU, memory, and I/O budgets from the control plane rather than reaching into
storage directly.

**No user data crosses into the control plane.** That constraint is what keeps
the split honest — see §11c-3.

### Capabilities are passive

```
        ✗  Capability → runs itself

        ✓  Supervisor → loads Capability
                      → Capability emits Operations
                      → Runtime updates Projections
```

A capability never drives its own execution. Scheduling, cancellation, retries,
and resource accounting stay centralized, which is the only place they can be
enforced. A capability that runs itself is one whose CPU nobody can cap and
whose work nobody can cancel when the user navigates away.

## 11c-3. The Supervisor is a resource authority

The Supervisor is **not** "the thing that starts engines". It is the component
that owns **resources**, and lifecycle is one of them.

```
Supervisor
├── Engine lifecycle
├── Cancellation
├── Scheduling
├── Memory budget
├── CPU budget
├── IO budget
├── Health
├── Metrics
└── Backpressure
```

**Every engine requests resources. The Supervisor grants them.**

That framing is what makes future additions compose instead of compete. Speech
recognition, OCR, LLM inference, and synchronization all want CPU and memory at
the same moment on a 6–8 core phone. If each constructs its own runtime and
takes what it needs, they contend; if each requests a budget, the Supervisor
arbitrates and the UI does not stall behind a background rebuild.

**Hard constraint: the Supervisor is a control plane, never a data plane.** It
owns handles, budgets, and cancellation tokens. Subsystems own their own state.
No operation payload, no projection data, and no key material passes through
its lock — otherwise it becomes the single global contention point in the
runtime and every benefit is paid for twice.

Tracked on #1302.

## 11d. One sync model

**Decided: one model. Everything is an operation.**

```
Capture
   ↓
Operation
   ↓
Operation Log
   ↓
Local Replay
   ↓
Remote Replay
```

Single-device mode replays only local operations. Multi-device mode replays
local plus remote operations. That is the entire difference — there is no
second storage model, no second merge engine, and no second code path.

The alternative was live: `rust/airo_core` already ships a state-based CRDT
store — `compare_vector_clocks()` in `api/native_engine.rs` and
`api/relational_store.rs` (rusqlite, entity + field model, per-field
last-write-wins, tombstones, SQL migrations). Keeping both was a real option
and is rejected.

**Every additional sync model doubles the testing matrix**, and the two would
drift. `relational_store` is also durable user state that does not originate
from the runtime, which makes it an I4 case on its own terms.

Consequence for existing code: `relational_store` migrates onto the operation
log via the shared adapter in #1293, alongside the feature-owned stores. It is
not a parallel substrate to build on. Tracked on #1297.

## 12. Open decisions, assigned to subsystem specs

These are deliberately unresolved here. Resolving them without implementation
evidence would be guessing.

| Question | Decided in |
|---|---|
| ~~Are snapshots authoritative or cache-only?~~ **DECIDED: cache-only, with a persisted verified-prefix watermark.** Settled on measured grounds, not philosophical ones — ed25519 verification is 32.9–36.3 µs/op and 50–80× everything else combined, so cache-only cold start is 33 s per million operations *unless* verification is an ingest-time obligation. Without the watermark the pressure to make snapshots authoritative — voiding I1 — becomes irresistible. **The watermark is what protects the invariant.** | Resolved |
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
