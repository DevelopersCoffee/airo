# Airo Mind — Roadmap and Requirement Coverage

Status: **Planning.** Companion to `2026-07-27-airo-mind-runtime-design.md`.
Date: 2026-07-27
Owner: Product Manager (Airo Engineering Council)

This document exists so that nothing from the original requirement set is
silently dropped. Every requirement is either scheduled, explicitly deferred
with a trigger, or explicitly refused with a reason.

---

## 1. Release shape

| Release | Milestone | Ships | Proves |
|---|---|---|---|
| **v1 — Runtime** | 19 | The seven primitives + a Notes capability, single device | The runtime holds no domain knowledge and a real capability can drive it |
| **v2 — Capability Platform** | 20 | Authoring SDK, first-party domain capabilities, capsules, AI-assisted authoring | A domain can be added without touching the runtime |
| **v3 — Ecosystem** | 21 | Community authoring, marketplace, Tier 3, extra transports, monetization | Other people can extend it safely |

Nothing in v2 starts before v1 Phase 6 ships. Nothing in v3 starts before v2
proves a third party can author a working capability without runtime changes.

## 2. Requirement coverage

Traced from the original brief. **Scheduled** means an epic exists.
**Deferred** carries the trigger that unblocks it. **Refused** carries the reason.

### Runtime and storage

| Requirement | Disposition |
|---|---|
| Immutable signed operation log as sole source of truth | Scheduled — v1 Phase 2 (#1194) |
| Encrypted knowledge graph | Scheduled — v1 Phase 3 (#1195), as a projection, not storage |
| Entity database, timeline, documents, workflow state | Scheduled — v1 Phase 3, all projections |
| Embeddings, LLM cache | Scheduled — v1 Phase 9 (#1202); purged on destroy |
| Every device stores everything; no device is "the server" | Scheduled — v1 Phase 7 (#1200) |
| Deterministic merge, rebuilt from operations | Scheduled — v1 Phases 2, 7 |
| Version vectors; exchange only missing operations | Scheduled — v1 Phase 7 |
| Cryptographic identity, per-device keys, signed operations | Scheduled — v1 Phase 1 (#1193) |
| Device database / sync payload / document encryption | Scheduled — v1 Phase 1, plus at-rest (#1241) |
| Large files: metadata in graph, blob transferred on request | Deferred to v2 — trigger: Phase 7 sync ships. v1 has no blob transport. |

### Capabilities and packs

| Requirement | Disposition |
|---|---|
| Tier 1 declarative packs | Scheduled — v1 Phase 4 (#1196) |
| Graph / Workflow / View / Automation DSLs | Scheduled — v1 Phase 4 (#1225) |
| Archetypes, core ontology, safety classes, schema fingerprint, migrations | Scheduled — v1 Phase 4 |
| Context templates; contexts outlive the capability | Scheduled — v1 Phase 5 (#1197) |
| Tier 2 sandboxed expression language | **v2** — no network, no file access, no threads, no native APIs, no reflection, no unbounded loops |
| Tier 3 first-party native capabilities | **v3** — gated on a signing and review pipeline that does not exist yet |
| Domain capabilities: Hospital, Property, Startup, Tax, Wedding | **v2**, first-party only. See §4 for the health constraint. |
| AI app builder — "I want an app to manage my parents' medicines" | **v2**, and it emits a *draft capability for review*, never a live one |
| Capability marketplace | **v3** |
| Community authoring, moderation, provenance, review workflow | **v3** |
| MCP bridge for capability tools | **v3** — deferred, not refused. Trigger: Tier 2 sandbox ships and a permission model exists. |

### Sync and transport

| Requirement | Disposition |
|---|---|
| mDNS `_airomind._tcp` discovery, LAN transport | Scheduled — v1 Phase 7 |
| Mutual authentication, encrypted session, background sync | Scheduled — v1 Phase 7 |
| Bluetooth LE, Wi-Fi Direct, USB, NAS, self-hosted relay, user cloud storage | **v3** — the sync engine is transport-agnostic by design; each additional transport is incremental, none is on the v1 or v2 critical path |

### Data ownership

| Requirement | Disposition |
|---|---|
| Personal Knowledge Capsule — portable encrypted archive | **v2**. v1 ships Recovery Package (access, no data); capsule is the data-carrying sibling. |
| Move to a new phone; offline backup; USB or NAS storage | Scheduled — v1 Phase 1 (#1211, #1234) via Recovery Package |
| Self-hosting | **v3**, as a transport (relay), not as a server dependency |
| Product survives the company disappearing | Structural, not a feature. Guaranteed by open formats + local storage + capsule. Verified by a v2 acceptance test: restore a capsule with the app offline and unsigned. |

### Sharing

| Requirement | Disposition |
|---|---|
| Capsule export with explicit selection, one-way | **v2** |
| Key delegation to another person, time-limited, revocable | **Refused.** Once a key reaches a device the user does not control, revocation is unenforceable — they already hold plaintext. Shipping "revocable" would be a false security claim. If human-to-human sharing is wanted later it is a different product with a different threat model, not a v-next feature. |
| Collaborative editing | **Refused** for the same reason. |
| Caregiver notifications (from the parents-medicine example) | **Refused in this form.** Requires a second person's device inside the trust boundary. Achievable later only as capsule export or as a genuine multi-user product. |

### Commercial

| Requirement | Disposition |
|---|---|
| Free local core | **v3** decision point; no billing work before then |
| Paid encrypted sync tier | **Refused as specified.** Sync in this architecture is peer-to-peer with no server, so there is no hosting cost to recover and nothing to withhold. Charging for it would mean deliberately crippling the free tier. |
| Marketplace take-rate | **v3**, contingent on the marketplace existing |
| Commercial / enterprise licensing | **v3** |
| Domain packs as paid add-ons | **v3** |

Entitlement plumbing already exists (`core_entitlements`, the airo-pro overlay).
No new billing infrastructure is in scope before v3.

## 3. What v1 deliberately does not ship

Marketplace · community capabilities · Tier 2 and Tier 3 · domain capabilities ·
MCP · AI app builder · human-to-human sharing · capsules · non-LAN transports ·
blob transfer · the physical repository restructure to `runtime/` + `capabilities/`.

None of these is a prerequisite for v1. Each is listed above with a home.

## 4. Regulatory boundaries — binding on every capability

These are not advisory. A capability that crosses one of these lines changes
Airo's regulatory classification, and the runtime cannot detect that for us.

### Health

Any capability touching physiological data stays inside the general-wellness
boundary. Permitted: long-term trends, personal baselines, aggregated
visualizations, lifestyle correlations, and support for living well with a
condition. Prohibited: diagnostic or disease-specific language, clinical
thresholds, medical alerts or alarms, and anything that could cause a user to
delay care or alter a prescribed dose.

Notification copy is the usual failure point. "Outside your usual range,
consider talking to a healthcare professional" is permitted. "Abnormal" or any
named condition is not.

**Concrete consequence for v2:** a Hospital Recovery capability may track
appointments, documents, expenses, and stages. A medicine tracker may record
what was taken and when. It **may not** compute or recommend a dose, and dose
fields carry the `medical` safety class, which forbids auto-merge and AI
resolution outright (design spec §5.4).

### Recording

Any capability capturing audio inherits two-party consent law. Eleven US states
require all-party consent; interstate calls default to the most restrictive
jurisdiction. Displaying a bot or an indicator is not legally sufficient
consent. No audio-capture capability ships without a consent design reviewed by
counsel — that is a gate, not a checklist item.

### GDPR

The household exemption does not apply to professional use. Any capability
marketed for work makes the user a data controller. This is a documentation and
copy obligation, not an engineering one, but it belongs to whoever writes the
capability's store listing.

## 5. Product claims — exact permitted wording

Following the chief-security-officer review of Phase 1 (PR #1239), two claims
must be qualified everywhere they appear: README, store listings, onboarding,
and the destroy confirmation dialog.

**Erasure.** Permitted: *"Destroyed content cannot be recovered. The fact that
an item existed, its type, and when it was created may remain."*
Not permitted: any unqualified "erasure is real", "permanently deleted", or
"leaves no trace".

Erasure durability is additionally bounded by the freshness of the revocation
ledger a restoring device can obtain. A device restoring from a stale backup
with no access to the operation log cannot know about destructions performed
elsewhere. This is a permanent property of a serverless architecture, not a bug
to be fixed later, and the copy must not imply otherwise.

**Capsule export.** Permitted: *"You choose what to include. Once exported, it
is theirs — it cannot be recalled."* Not permitted: "revocable", "time
limited", or "you stay in control".

A destroy confirmation must state that previously exported capsules and
Recovery Packages are outside the destroy's reach.

## 6. Open decisions

| Decision | Needed by | Why it cannot wait |
|---|---|---|
| BIP39 passphrase on the Recovery Package | v1 Phase 1 | The package format freezes now. Adding a passphrase later breaks every package already in the field. Recommendation: reserve `kdf_params`, `passphrase_used`, and a salt in the v1 format, authenticated as AAD, even if the feature ships disabled. |
| Header-protection key slot in the Vault hierarchy | v1 Phase 1 | Phase 1 freezes the key hierarchy. Adding a slot in Phase 2 means migrating every vault in the field. |
| Snapshots authoritative or cache-only | v1 Phase 3 | Decide with measurements from a realistic log, not in the abstract (#1221) |
| Automation idempotency across devices | v1 Phase 8 | Two devices replaying one trigger must not produce two reminders (#1201) |
| Whether `core_native` splits | v1 Phase 6 | It ships on TV for playlist and EPG; Mind is Never Ship on TV. If build-graph exclusion is not achievable, the package splits. Chief Architect call. |

## 7. Sequencing

```
v1  Phase 1 Vault ─┬─ Phase 2 Log ─┬─ Phase 3 Projections ─┐
                   │               └─ Phase 4 Capability ──┤
                   │                        └─ Phase 5 Context ─┤
                   └────────────────────────────────────────────┴─ Phase 6 Notes ── SHIP
                                                                        │
                                                        Phase 7 Sync ───┤
                                                                        ├─ Phase 8 Workflow
                                                                        └─ Phase 9 AI
v2  Authoring SDK ── Tier 2 ── Domain capabilities ── Capsules ── AI authoring
v3  Marketplace ── Community ── Tier 3 ── Transports ── Monetization
```

No dates. Phase 1 has not started, its plan is under revision following the
security review, and estimating a nine-phase runtime from zero shipped phases
would be fiction. Dates become meaningful after Phase 1 closes and gives a real
velocity signal.
