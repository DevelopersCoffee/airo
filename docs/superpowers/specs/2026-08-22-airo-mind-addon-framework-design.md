# Airo Mind Add-on Framework

**Date:** 2026-08-22  
**Status:** Approved; Increment 1 contracts landed; Increment 2 secure LifeTrack
destination landed on `cursor/mind-addon-increment-2-secure-lifetrack-45dd`  
**Owners:** Framework Agent + Product Manager (Airo Mind)  
**Required reviewers:** Product Manager, Framework Agent, AI/Brain Agent,
Memory Agent, Chief Architect, Platform Architect, Flutter Architect, Edge
Architect, Chief Security Officer, Chief Cloud Officer, Chief Performance
Officer, Chief Open Source Officer, Chief QA Officer, Chief Documentation
Officer

## 1. Decision

Airo Mind must not gain a new framework branch every time a business add-on is
introduced. Framework packages own reusable contracts and execution mechanics.
Add-ons own vocabulary, prompts, workflow fields, extraction policy,
offerability, pending assessment, safety copy, and LifeTrack templates.

The framework supports two optional typed behaviors behind one validated
add-on manifest:

1. **Generative behavior** — builds constrained model input and evaluates model
   output. Diet Plan is the first proof.
2. **Graph-workflow behavior** — extracts explicit facts, projects graph
   subjects into workflow previews, and assesses pending information.
   Insurance, Hospital Recovery, Property Purchase, Car Purchase, and
   University Admission are the first proofs.

An add-on may implement either behavior or both. The host selects behavior from
the validated registry; it never switches on an add-on ID or LifeTrack template
ID.

This is a hybrid authoring model:

- Declarative bundle data defines identity, capabilities, tools, schemas,
  assets, prompts, templates, and policy.
- Optional typed Dart adapters contain trusted first-party behavior already
  compiled and signed as part of the Airo application.
- Remote and community bundles remain declarative. This migration does not
  download or execute Dart code.

Under the runtime design, compiled Dart is Tier 3. This migration does **not**
implement Tier 3 loading or distribution. The adapter is a built-in host
compatibility module shipped through the normal reviewed and signed app build.
It is not delivered by, selected by, or executable from an installed bundle.
Downloaded capabilities remain Tier 1 data. A future capability-delivered Tier
3 system requires a separate ADR, signing pipeline, sandbox decision, and
council approval.

## 2. Problem

The current add-on manifests are not sufficient to execute domain behavior.
`SKILL.md` describes tools and persona instructions, but business behavior is
hard-coded in shared services:

- Diet recognition, thread context, prompt shaping, retry, and output
  evaluation live in `DietPlanPluginPrompt` and Diet-specific branches in
  `chat_screen.dart`.
- Insurance, hospital, and property extraction live in
  `LifeTrackFactExtractor` and `ChatEntityLinker`.
- Their offerability and field mapping live in
  `ChatEntityGraphProjector`.
- Their pending vocabulary and missing-field policy live in
  `ChatEntityGraphPending`.
- Domain templates and keyword routing are enumerated in `core_data`.
- Connector and UI fallback copy still assumes claims.

Adding Car Purchase and University Admission by copying those switches would
make every future business add-on a framework change. Disabled add-ons can also
be interpreted because chat ingestion currently runs before add-on routing.

## 3. Goals

1. A first-party add-on can add generative or graph-workflow behavior without
   changing shared orchestration, chat UI, graph services, or template
   switches.
2. Diet Plan migrates through the generic registry without changing its
   visible behavior or safety evaluations.
3. Insurance, Hospital Recovery, and Property Purchase migrate without
   changing persisted graph IDs, edges, previews, or pending answers.
4. Car Purchase and University Admission are added only through the new
   add-on contract.
5. Only activated add-ons with an unrevoked, purpose- and resource-scoped grant
   may inspect a message; a pinned add-on receives deterministic priority.
6. Workflow paths operate locally and without an inference model.
7. Storage and tool writes remain permission-bound, previewed, and explicitly
   confirmed.
8. Business definitions can be revised and versioned independently of
   framework implementation.

## 4. Non-goals

- Remote or community executable code
- A public scripting or expression language
- Marketplace, billing, paid packs, or entitlement work
- LLM-assisted entity extraction or silent cloud fallback
- Gmail, email, OCR, attachment, transcript, document, or web ingestion
- Dealer, lender, insurer, university, visa, or admission recommendations
- Loan processing, vehicle registration, application submission, or visa
  submission
- Automatic reminders or calendar writes
- Cross-device graph synchronization
- New durable graph storage before the encrypted operation-log projection
- A graph editor or workflow builder
- Additional domains beyond the six migration proofs
- Replacing the encrypted operation-log projection planned by issue #1195
- Implementing the generic automation engine planned by issue #1201

## 5. Ownership and package boundaries

### `core_domain`: stable data contracts

`core_domain` owns domain-neutral value types:

- `AddonManifest`, `AddonId`, semantic version, declared behavior kinds
- capability and tool declarations
- graph node, edge, patch, snapshot, and provenance contracts
- workflow projection, offer decision, pending assessment, and identity key
- immutable confirmation request and confirmation token descriptors
- template-provider and add-on-registry ports

`AddonManifest` supersedes the legacy plugin manifest's executable
`entryPoint`/`initFunction` model; it does not extend those fields. Existing
plugin lifecycle code may supply discovery/version/kill-switch primitives only
after its manifest contract is corrected.

LifeTrack requirements gain a stable `field_id` separate from the display
label. Existing templates derive a deterministic compatibility ID from
`template_id + normalized label`; migrated add-on templates declare IDs
explicitly. Adapters exchange facts by `field_id`, while UI and pending output
render add-on-owned labels.

Graph relation names and attributes are opaque strings to the framework. Core
contracts do not define `claim`, `hospital_stay`, `RERA`, `vehicle`, or
`university`.

The current graph imports `feature_mind`'s `EntityType`, which cannot move into
`core_domain`. The neutral contract therefore stores a validated type key
string (`person`, `date`, `term`, and so on) while preserving the existing JSON
value. An application adapter maps extractor enums to type keys.

The old SharedPreferences graph is not the target store. It is a read-only
compatibility source during migration. Existing payloads must load without
schema loss, but new sensitive facts are never written back to plaintext
SharedPreferences. Because this program has no durable graph destination, the
old key remains untouched for rollback until the encrypted operation-log
projection migrates it or the user explicitly deletes it.

### `core_ai`: validation, registry, and execution

`core_ai` owns:

- manifest/schema validation
- deterministic add-on registration and lookup
- enabled/pinned candidate selection
- adapter dispatch and exception isolation
- capability and tool-policy enforcement
- deterministic conflict ordering
- exact-payload confirmation token issuance and redemption
- generic execution traces and failure results

It does not import first-party add-on implementations and contains no business
vocabulary or template IDs.

The registry, not an add-on-controlled field, mints bundle provenance. Built-in
adapter registration is an embedded allowlist over:

```text
(add-on ID, add-on version, manifest SHA-256, adapter contract version,
 application build identity)
```

An installed bundle cannot shadow a built-in ID, request a compiled adapter, or
change this binding.

### `core_data`: generic persistence and providers

`core_data` owns:

- graph and template storage implementations
- generic JSON template parsing and validation
- provider composition and lookup by template identity/version
- compatibility loading for existing persisted tracks and graphs
- encrypted LifeTrack persistence through the existing
  `EncryptedDatabase`/`EncryptionKeyManager` contracts

It does not enumerate domain template asset paths in the final state and does
not contain domain keyword maps. During migration, a compatibility provider may
read old bundled paths, but it is removed once every bundled template is owned
by an add-on bundle.

LifeTrack titles, fields, requirements, and values are sensitive destination
data and must be encrypted at rest. The migration copies the current plaintext
database into an encrypted database in one verifiable transaction, then checks
row counts and canonical record hashes before retiring the plaintext file. If
key management or encrypted storage is unavailable, existing plaintext tracks
remain read-only and new writes fail with `secure_destination_unavailable`.
Graph preview and pending status remain available without claiming a save.

### `feature_mind`: host and first-party add-ons

The Mind host owns:

- loading built-in and installed declarative bundles
- registering embedded compiled first-party adapters from app-owned code
- connecting chat, graph, LifeTrack, calendar, and notification ports
- rendering generic preview, confirmation, pending, and error results

It contains no ID-based branches such as `draft-diet-plan`,
`insurance_claim_v1`, or `medical_surgery_v1`.

Business add-ons live under a clear add-on boundary:

```text
packages/feature_mind/
├── addons/
│   └── <addon-id>/
│       ├── SKILL.md
│       ├── addon.json
│       ├── lifetrack_template.json      # optional
│       └── fixtures/
└── lib/src/addons/
    └── <addon-id>/
        └── <addon-id>_adapter.dart       # optional, compiled first-party only
```

The declarative bundle is the source of business metadata. App-owned registry
code binds a compiled adapter to the exact built-in bundle digest. A missing,
mismatched, or undeclared adapter fails closed. Installed bundle data is never
allowed to select an adapter class or entry point.

## 6. Add-on manifest

`addon.json` is versioned and validated before registration. Its conceptual
shape is:

```json
{
  "schema_version": "1.0",
  "id": "car-purchase-planner",
  "version": "2.0.0",
  "behaviors": ["graph_workflow"],
  "capabilities": ["conversation.process", "lifetrack.read", "lifetrack.write"],
  "tools": ["query_entity_graph", "record_lifetrack_facts"],
  "adapter": {
    "kind": "required_built_in",
    "contract": "graph_workflow_v1"
  },
  "safety_class": "financial",
  "workflow": {
    "template_asset": "lifetrack_template.json",
    "subject_kind": "car_purchase"
  }
}
```

The validator rejects:

- unknown schema or behavior contract versions
- duplicate add-on IDs or incompatible versions
- undeclared tools or capabilities
- unknown, missing, or downgraded safety classification
- template paths outside the bundle
- template IDs that disagree with the manifest
- compiled adapter IDs or versions that disagree with the bundle
- a non-built-in bundle declaring `required_built_in`
- unsupported safety classes or write policies
- malformed workflow and prompt/evaluation schemas

This migration accepts unpacked app assets and the existing bounded single-file
HTTPS manifest/SKILL flow only. Archive import is out of scope and rejected;
there is no ZIP/TAR extraction surface, symlink/hardlink handling, or
filesystem write from a downloaded bundle.

`SKILL.md` remains the human-readable persona/instruction surface. The runtime
does not derive executable permissions or workflow schemas from prose.

## 7. Typed behavior contracts

The interfaces remain small and behavior-specific:

```dart
abstract interface class GenerativeAddonAdapter {
  AddonIdentity get identity;

  bool accepts(AddonConversation input);

  AddonPrompt buildPrompt(AddonConversation input);

  AddonEvaluation evaluate(AddonOutput output);
}

abstract interface class GraphWorkflowAddonAdapter {
  AddonIdentity get identity;

  bool accepts(GraphIngestContext input);

  Future<EntityGraphPatch> extract(GraphIngestContext input);

  Iterable<WorkflowProjection> project(EntityGraphSnapshot graph);

  PendingAssessment assessPending(
    EntityGraphSnapshot graph,
    WorkflowProjection projection,
  );
}
```

The framework supplies immutable inputs. Adapters return values; they do not
receive repositories, connectors, platform channels, or arbitrary tool
execution handles.

The framework mints invocation and provenance handles. Adapters can reference
those handles in results but cannot construct source identities, grants, or
confirmation authority.

`WorkflowProjection` carries:

- add-on identity and version
- subject node ID
- destination kind and template identity/version
- title and display metadata
- facts keyed by stable field IDs
- deduplication identity keys
- explicit offer decision and reason
- provenance references for every fact

Each fact's lineage contains the framework-minted source-message revision,
manifest digest, adapter digest, extraction contract version, and merge
history. Editing or destroying a source message invalidates or revokes derived
ephemeral facts. Confirmed LifeTrack copies retain a revocation reference so
the deletion workflow can locate derived values without invoking the add-on.

Display metadata is separate from template facts. For example, a hospital name
may make a surgery journey offerable without being silently dropped into a
template that has no hospital requirement.

## 8. Runtime flow

```text
message
  → activated and granted enabled/pinned candidates
  → adapter accepts()
  → adapter returns prompt instructions or graph patch
  → framework validates result
  → session graph or generation pipeline
  → projection and exact preview
  → explicit confirmation token
  → framework-owned tool connector
  → local LifeTrack/calendar repository
```

### Candidate selection

1. Activation displays the add-on purpose, safety class, requested resources,
   effects, local/model behavior, retention, and deletion path.
2. The user grants exact scopes such as `conversation.current_turn`,
   `conversation.thread_history`, `graph.addon_scope.read`, or
   `lifetrack.write`. Enabling alone grants no data access.
3. A grant records actor, add-on and manifest digest, resource, purpose,
   scope, timestamp, and permission epoch. A material version or scope change
   requires re-consent; revocation is immediate.
4. A pinned, enabled, activated, and granted add-on is considered first.
5. Other eligible add-ons are ordered by explicit built-in priority, then
   add-on ID for stable ties.
6. Disabled, quarantined, incompatible, uninstalled, ungranted, and revoked
   add-ons receive zero calls, including `accepts()`.
7. Multiple graph add-ons may accept the same message. Unprotected edges and
   identities merge deterministically, so a hospital can relate to both a
   claim and surgery.
8. Safety classes are assigned or ratcheted by framework policy, never lowered
   by an add-on. An app-embedded, signed safety registry binds minimum classes
   to each built-in add-on, field ID, and output kind; bundle declarations can
   only ratchet stricter. Unknown fields default to the strictest applicable
   add-on class and remote unknowns cannot write. Strictest class wins across
   links. Medical, identity, minor, visa, claim, treatment, allergy, loan, and
   financial-amount conflicts require manual review; they never auto-merge
   values.
9. Generative output selection remains single-owner for one response. An
   ambiguous tie results in deterministic clarification rather than choosing
   silently.

### Graph workflow

Adapters extract only explicit facts. Every node, edge, and fact references a
framework-minted provenance handle. The framework rejects dangling edges,
unknown subject IDs, empty facts, safety downgrades, protected-field
auto-merges, and provenance-free values.

Pre-confirmation graph state is ephemeral, held in memory, partitioned by
conversation and add-on, unavailable to other add-ons, and cleared on
conversation close, add-on disable/revocation, process exit, or after 24 hours,
whichever occurs first. It is never written to disk, operation log, shared
projection, backup, analytics, or crash reporting.

Projection runs only through the same centralized eligibility gate used before
`accepts()`: enabled, activated, granted, compatible, unrevoked, and not
quarantined. `firstUnoffered` becomes a generic registry operation using each
projection's explicit offer decision.
The framework tracks offer state by add-on identity plus subject identity, not
by template-specific attributes.

### Pending query

The host calls `query_entity_graph` first. The registry asks only eligible
matching workflow add-ons for `PendingAssessment`, which separates:

- stored graph facts
- saved LifeTrack facts
- missing required fields
- missing optional fields
- cross-links

If a matching LifeTrack exists, `query_lifetrack_status` is called next and
merged generically. The framework never invents a task or field that the add-on
did not declare.

### Generative query

Diet Plan's adapter:

- recognizes initial and follow-up diet requests
- derives user constraints from user-authored turns
- builds a constrained prompt
- evaluates day count, repetition, dietary exclusions, allergies, and safety
- requests a bounded retry through a generic evaluation result

The chat host handles this through generic add-on hooks. It no longer imports
Diet helpers or checks the Diet add-on ID.

Diet is generative and therefore needs a model. With no local model, it returns
typed error `addon_model_unavailable` and explains that a local model is
required. It does not silently use a cloud provider. Sending Diet constraints
to any remote provider requires separate per-use egress consent naming the
provider, data categories, purpose, and retention.

## 9. Memory, permissions, and confirmation

Session extraction may occur only after activation and a current-turn or
thread-history processing grant. It remains ephemeral as defined in §8.
`memory.read` does not imply `memory.write`.

This migration does not introduce durable graph writes. Existing plaintext
SharedPreferences graph data is a read-only compatibility source and cannot
receive new hospital, insurance, financial, education, Diet, or identity facts.
Durable graph memory remains blocked on the encrypted operation-log projection.
The user may instead confirm a specific LifeTrack write, whose preview and
destination are explicit.
An add-on manifest declaring durable `memory.write` is rejected with
`addon_capability_unsupported` until the encrypted operation-log projection
supplies that capability.

LifeTrack, calendar, and notification writes are separate effects with separate
capabilities. One permission never grants another.

Before a write, the framework creates a preview and a confirmation request
containing:

- add-on ID and version
- destination tool and resource
- canonical payload hash
- human-readable preview
- expiry and one-use nonce

The framework builds one confirmation record containing actor/session, add-on
ID and manifest digest, adapter digest, action, destination resource, exact
payload, graph revision, permission epoch, expiry, and idempotency key. It
canonicalizes that record exactly per RFC 8785 and hashes:

```text
SHA-256(UTF8("airo-confirmation-v1\n") || canonical_record_bytes)
```

The user-facing token is an opaque 256-bit CSPRNG nonce encoded as unpadded
base64url. Its authoritative record stays in the framework's secure token
store; possession alone is insufficient because actor/session and permission
epoch are revalidated. Domain separation prevents a token for one tool from
authorizing another.

Only a direct user confirmation can issue the one-use token. An add-on, model,
or tool argument cannot self-confirm with `confirmed: true` or a confirmation
phrase. Changing nested payload data, map keys, destination, add-on version,
relevant graph facts, permission epoch, or source revision invalidates the
token. Equivalent map-key ordering yields the same canonical bytes. Rejection
and unrelated replies clear it.

The connector independently canonicalizes and revalidates the record and
payload before executing. A writable destination implements
`IdempotentEffectPort`: it stores a unique idempotency key, confirmation hash,
effect state, and destination receipt in the same transaction as a local
effect. External connectors must persist an intent before invocation and
reconcile a destination receipt; connectors that cannot reconcile are not
eligible for add-on writes.

Redemption atomically marks the token consumed and commits or reconciles the
idempotent effect. A definitely failed write may produce a new preview. An
uncertain write first reconciles by idempotency key; it never blindly reuses
the consumed token or reports success.

Denied permission is non-destructive. Calendar denial does not block graph
queries or LifeTrack status and does not repeatedly prompt.

Generic traces contain IDs, timings, sizes, and typed results only. Prompts,
facts, previews, graph attributes, and tool payloads are excluded from logs,
analytics, crash reports, and lock-screen notification copy. Export and
deletion operate through generic data contracts without executing an add-on.

Disable, uninstall, and delete are distinct:

- disable/revoke stops all access and calls but preserves user-confirmed data
  under generic ownership
- uninstall removes add-on software/assets but preserves encrypted or
  destination-owned user data
- explicit deletion destroys source facts and derived projections according to
  their revocation references

## 10. Failure handling

- `addon.json` and `SKILL.md` are each capped at 64 KB, a LifeTrack template at
  256 KB, any other declarative asset at 1 MB, and an unpacked bundle at 5 MB
  and 128 files. Templates are capped at 64 milestones, 256 tasks, and 512
  fields. Parsing above 50 KB runs off the main isolate. Validation is atomic
  before registration: manifest, digest, assets, template, capabilities,
  adapter binding, and limits either all register or none do.
- Invalid bundles enter persisted quarantine keyed by digest and expose typed
  error `addon_bundle_invalid`. Restart does not clear quarantine. Recovery
  requires a different validated digest or explicit removal.
- Quarantine, disable, revocation, or incompatible upgrade cancels in-flight
  work, invalidates outstanding tokens, and removes registry/tool/template
  access. Generic export/deletion of existing user data remains available
  without executing the add-on.
- An adapter exception produces a scoped add-on failure; other enabled add-ons
  may continue. Stage-specific codes are `addon_accept_failed`,
  `addon_prompt_failed`, `addon_evaluation_failed`, `addon_extract_failed`,
  `addon_projection_failed`, and `addon_pending_failed`.
- Unsupported text or a workflow-adapter confidence below its manifest's
  validated threshold produces `addon_clarification_required`, not fabricated
  entities. Threshold changes are versioned business policy.
- Invalid patches return `addon_patch_invalid` with zero graph mutation.
- Storage failure returns `addon_write_failed` or
  `addon_write_outcome_unknown`; it never reports success. Retry follows the
  reconciliation rules in §9.
- Tool permission failure returns `addon_permission_denied`. Confirmation
  failures return `confirmation_required`, `confirmation_invalid`,
  `confirmation_expired`, `confirmation_consumed`, or
  `confirmation_permission_changed`. Every failure has zero new destination
  mutation and cannot fall through to model-generated success copy.
- Lifecycle cancellation returns `addon_invocation_cancelled`; late adapter or
  connector results are discarded after eligibility epoch revalidation.
- Deterministic graph workflows do not require a loaded model or network.
- No network/model fallback occurs silently.
- Parsing or serialization above 50 KB runs through the repository's worker
  boundary; presentation code does not spawn an isolate.

## 11. Migration

The migration is one architectural program with independently reviewable
increments:

### Increment 1: characterize and introduce contracts

- Freeze current Diet, insurance, hospital, and property behavior with
  exact golden characterization fixtures.
- Move graph DTO contracts to `core_domain` while preserving serialized JSON.
- Add add-on manifest, registry, behavior inputs/results, validation, and
  synthetic adapters.
- Prove a synthetic generative add-on and a synthetic graph-workflow add-on
  require no host switch.

### Increment 2: secure and idempotent LifeTrack destination

- Implement encrypted LifeTrack storage behind the existing
  `EncryptedDatabase`/`EncryptionKeyManager` ports.
- Add transactional plaintext migration, verification, rollback, key rotation,
  and `secure_destination_unavailable` read-only fallback.
- Add destination-level unique idempotency records required by confirmation
  redemption.
- Do not enable add-on LifeTrack writes until this increment passes security,
  migration, restart, and rollback tests.

### Increment 3: migrate Diet Plan

- Build its bundle and compiled generative adapter.
- Route prompt construction and output evaluation through the registry.
- Remove Diet-specific imports, ID checks, and branches from chat.
- Preserve current health safety and deterministic evaluation fixtures.
- Permit at most one corrective model retry. A second invalid output returns
  `addon_output_invalid` with deterministic safe copy.

### Increment 4: migrate existing workflows

- Build Insurance Planner, Hospital Recovery, and Property Purchase bundles and
  compiled graph adapters.
- Preserve existing node IDs, edge predicates, graph JSON, offer ordering,
  previews, pending output, and confirm-gated LifeTrack writes.
- Replace hard-coded linker, projector, and pending switches with registry
  dispatch.
- Stop new SharedPreferences graph writes; use isolated ephemeral graph state
  and the read-only legacy importer defined above.

### Increment 5: move templates and genericize storage

- Move domain template JSON into the owning add-on bundles.
- Replace `TemplateRegistry.bundledAssetPaths` with registered template
  providers.
- Remove framework domain keyword maps and compatibility paths after migration
  tests pass.
- Make record deduplication and success copy projection/add-on metadata rather
  than claim/study switches.

### Increment 6: add Car Purchase and University Admission

- Add both exclusively as bundles and graph-workflow adapters.
- No framework or chat-host source changes are allowed for these two add-ons;
  only registration and bundle-owned tests/assets may change.

## 12. Add-on behavior requirements

Identity normalization uses Unicode NFKC, locale-independent lowercase,
trimmed/collapsed whitespace, and removal of non-semantic punctuation while
preserving letters, digits, and meaningful model/term separators. Add-on-owned
alias tables are versioned fixtures; the framework does not guess aliases.

### Diet Plan

- Generative only; no tools or graph/LifeTrack write.
- Preserve thread refinements, latest day-count precedence, vegetarian/vegan
  exclusions, allergy checks, non-repetition checks, and health safety refusal.
- Do not diagnose or prescribe.

### Insurance Planner

- Preserve claim, policy, insurer, intermediary, and document behavior.
- Preserve claim/hospital graph cross-links.
- Do not select coverage, file claims, or promise settlement.

### Hospital Recovery

- Preserve hospital/surgery/test/authorization graph behavior.
- A hospital can link to a surgery and an insurance claim simultaneously.
- Do not diagnose, prescribe, or alter a care plan.

### Property Purchase

- Preserve RERA, builder, project, floor, and amenity behavior.
- Do not provide legal advice or recommend a builder or loan.

### Car Purchase

- One purchase decision may contain multiple vehicle candidate nodes.
- With no explicit purchase identifier, there is one active ephemeral purchase
  subject per add-on and conversation. “A separate purchase” creates another
  subject.
- A vehicle node identity is normalized make + model + explicitly provided
  model year. Repeated mentions update that node; distinct vehicles remain
  candidates under the same purchase subject.
- Initial fields use the existing template labels: `Shortlisted Cars`,
  `Test Drive Notes`, `Budget Range`, `Loan Offers`, and `Parking Plan`.
- Offer only after a named vehicle plus a decision fact such as budget,
  test-drive information, parking, or financing.
- “I need a car” does not create or offer a journey.
- Do not recommend a dealer, loan, insurer, or vehicle as the correct choice.

### University Admission

- One admission cycle may contain multiple university and program nodes.
- A cycle identity is normalized intake term and year. With no term, one active
  ephemeral cycle exists per add-on and conversation. An explicit different
  term creates a new cycle.
- Institution identity is normalized institution name plus explicitly supplied
  location. Program identity is institution identity plus normalized program
  name, so identical program names at different institutions do not merge.
- Initial fields use the existing template labels: `University Shortlist`,
  `Document Checklist`, `Submitted Programs`, and
  `Visa or Enrollment Notes`.
- Offer only when the message includes explicit application/tracking intent
  (`apply`, `application`, `admission`, or `track`) plus either a named
  institution/program or an intake term/year.
- A general university information question does not create or offer a journey.
  “What programs does MIT offer?” is a required negative fixture; “I am
  applying to MIT for Fall 2027” is a required positive fixture.
- Do not choose a school, promise admission, or give immigration/legal advice.

## 13. Verification strategy

### Framework contract tests

- Manifest and adapter version matching
- Duplicate registration and deterministic ordering
- Enabled, disabled, pinned, quarantined, and uninstalled selection
- Synthetic generative and graph-workflow add-ons
- Spy adapters proving zero method and tool calls when disabled, pinned but
  disabled, quarantined, incompatible, uninstalled, ungranted, or revoked
- Adapter exception isolation
- Graph patch validation and provenance enforcement
- Multi-add-on graph merge plus protected-field conflict review
- Confirmation token immutability, expiry, one-use behavior, and invalidation
- Permission denial and storage failure
- Offline and no-model deterministic execution for every graph add-on, with
  network/model spies proving zero calls
- Diet no-model `addon_model_unavailable` and no cloud fallback
- Pre-migration graph fixtures containing complete nodes, attributes, edges,
  ordering, recent IDs, and offer state
- Old payload → new reader → neutral writer structural equality, including
  SharedPreferences key and payload shape
- Neutral writer output readable by the previous-release reader
- Existing template ID/version resolution after assets move
- Plaintext LifeTrack → encrypted database transactional migration, row-count
  and canonical-hash verification, restart, rollback, key-unavailable
  read-only behavior, rotation, and old/new model compatibility
- Stage-specific failure codes and zero partial state
- Worker-executor instrumentation for parsing/serialization above 50 KB
- Architecture checks banning business IDs, template IDs, domain vocabulary,
  and add-on imports from generic framework/host paths
- Sink spies proving prompts, facts, previews, graph values, and payloads never
  reach logs, analytics, crash reports, or lock-screen notifications

Framework fixtures use neutral identifiers such as `sample-addon`,
`sample-template`, `subject`, and `related_to`. Framework production code and
tests contain no real domain vocabulary or business template IDs except
compatibility fixtures that are deleted with their migration seam.

### Add-on-owned tests

Each bundle owns:

- trigger and non-trigger utterances
- extraction and multi-turn deduplication
- graph nodes, edges, and provenance
- offer threshold and non-offer cases
- stored, missing-required, and missing-optional pending output
- template validation and field mapping
- safety refusals and prohibited advice
- exact preview and confirmation behavior
- version/catalog consistency
- exact golden graph JSON, projection order, offer reason, preview payload,
  pending assessment, and rendered text

### Regression and integration tests

- Diet fixtures preserve initial/follow-up recognition, user-only history,
  latest day count, vegetarian/vegan exclusions, every supported allergen,
  repetition, under/over day count, refusal detection, all safety cases, exact
  evaluation/retry result, one-retry limit, and zero graph/tool access.
- Insurance + hospital exact fixtures still yield two linked journeys with
  identical IDs, attributes, predicates, ordering, previews, and text.
- Property-only exact graph and pending fixtures remain structurally equal.
- Car tests repeat the same vehicle across turns, compare multiple candidates,
  separate explicit purchase decisions, and cover every positive/negative
  offer boundary and required/optional pending field.
- University tests repeat institutions/programs, distinguish identical program
  names across institutions, change intake cycles, and cover every
  positive/negative offer boundary and required/optional pending field.
- Disabled/revoked add-ons receive zero calls and retain no ephemeral facts;
  user-confirmed destination data remains accessible through generic LifeTrack
  UI until explicit deletion.
- Pinned add-ons answer pending without requiring the word “track”.
- Every graph add-on runs extraction → projection → pending → preview →
  confirmed save with no model, throwing model, no network, and zero
  model/network calls.
- Confirmation threat-matrix tests cover legacy `confirmed: true` rejection,
  nested mutation, tool/resource/add-on/source/permission changes, canonical
  key ordering, fake-clock expiry boundary, replay, concurrent redemption,
  rejection/unrelated-message clearing, separate write permissions, definite
  failure, and uncertain-write reconciliation.
- Widget tests cover generic preview/error semantics, keyboard/screen-reader
  labels, permission denial, retry, and confirmation expiry.
- Barrier-controlled lifecycle races disable, revoke, quarantine, uninstall,
  and upgrade during `accepts`, extraction, projection, pending, confirmation,
  and destination write. Late results return `addon_invocation_cancelled`,
  invalidate tokens, and commit no new state or effect.
- Automated disable/uninstall/delete tests prove ephemeral clearing,
  preservation of user-confirmed destination data, source-revision revocation,
  derived-data discovery, and explicit deletion without executing the add-on.

Manual host verification covers install/enable, pin, extraction, linked-memory
display, permission, preview, rejection, confirmation, saved LifeTrack, pending
query, disable, and deletion for each behavior family.

## 14. Acceptance criteria

The program is complete when:

1. A synthetic add-on supports each behavior without framework source changes.
2. Diet has no special case in chat orchestration or presentation.
3. Insurance, hospital, and property have no business switch in framework or
   host services and retain their existing behavior.
4. Car and university land without modifying framework or chat-host source.
5. Domain templates and keyword maps are absent from `core_data`.
6. Disabled add-ons cannot inspect, persist, project, or invoke tools.
7. Malformed manifests and undeclared capabilities fail closed.
8. Confirmation authorizes one immutable payload and one destination.
9. Graph workflows function offline and without a model.
10. Add-on tests own vocabulary, fields, offer policy, pending policy, safety,
    and templates.
11. No new dependency, package, network source, or executable download is
    introduced without a separate council-approved decision.
12. Architecture gates fail if generic framework/host paths contain registered
    business IDs, template IDs, domain keyword maps, or imports from add-on
    implementations.
13. Disable/revoke produces zero adapter/tool calls and clears ephemeral state;
    uninstall preserves user-confirmed destination data; explicit deletion
    removes source-linked derived data.
14. Add-on LifeTrack writes cannot be enabled until encrypted destination
    migration and idempotency tests pass; unavailable key/storage support fails
    closed as read-only.

## 15. Rollback

Each migration increment preserves a compatibility adapter until its
replacement passes characterization tests. Rollback disables the new registry
path and restores the compatibility adapter without rewriting persisted graph
data.

No migration deletes old templates or routing code until the corresponding
add-on owns the behavior and its regression suite passes.

The encrypted LifeTrack migration retains an immutable plaintext backup until
the encrypted copy passes transaction, hash, restart, and key-recovery checks.
Before any encrypted-store write, rollback may restore that backup. After the
first encrypted-store write, binary downgrade is not supported because it
would expose or lose newer data; rollback is a forward fix using the encrypted
repository. Release metadata blocks installation of a binary that cannot read
the current storage version.

