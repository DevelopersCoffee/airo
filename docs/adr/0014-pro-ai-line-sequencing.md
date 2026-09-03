# ADR 0014: Planned Aika Stream Pro AI sequencing

- Status: Accepted design sequence
- Date: 2026-07-27
- Claim state: Planned
- Decision owners: Product Manager, Chief Architect

## Context

#908 requests a design-only sequence for nine advanced outcomes. v0.0.5 must
not implement them or present them as available. The sequence must build on
versioned local data, entitlement, privacy, and media-execution boundaries.

## Decision

### Proposed v0.0.6 research and bounded validation

1. Media Concierge: read-only, explainable candidate selection.
2. AI Scheduler: suggestion-only with human-confirmed writes.
3. AI Timeline: sourced indexing over authorized metadata/captions.
4. Sports Command Center: fixture/carriage surface behind explicit gates.

These validate graph/profile inputs and gate lifecycle while avoiding
autonomous editing of media or playback.

### Proposed v0.0.7 research and bounded validation

1. Personal TV Channel, after recommendation and rights policies stabilize.
2. AI Director, after multi-feed device qualification and confidence policy.
3. AI Highlights, after lawful event/index and derived-media rules.
4. AI Co-Watcher, after citation, spoiler, and interruption evaluation.
5. AI Accessibility enhancements, after accessibility council review.

This is dependency order, not a delivery-date commitment. Any item remains
Planned or moves to Deferred when its prerequisite evidence is absent.

## Gate architecture

Before implementation, `core_entitlements` must add reviewed stable IDs named
in the three design briefs. The current `ProModuleRegistry` is initialization
only, so Cloud and Security owners must first add a reviewed lifecycle
controller that subscribes to entitlement changes, initializes on grant,
disposes idempotently on revoke, orders grant/revoke races, and fences late
writes. UI, workers, persistence, and network calls use that same generation.

`AiroWorkerExecutor` is not currently cancellable. Before any Pro background
job ships, the worker contract must add cancellable/cooperative job handles.
Every job captures an entitlement generation and rechecks it before a network
request, persistent write, or result publication. Revocation deletes all
transient and persisted Pro-derived data while preserving authorized source
material and CE-owned state.

Core media execution remains behind ADR 0012’s validated `IntentCommand`
adapter. CE playback, search, guide, captions, accessibility, manual reminders,
and local organization never depend on these modules.

## Prerequisites

- #881/#882 rule ranking and Media Graph contracts;
- #903 physical multi-feed qualification for Director/Sports;
- #905/#906 versioned profile and conversation-memory contracts;
- ADR 0012's upstream `IntentCommand` schema reconciliation and deterministic
  drift gate before any AI feature can consume the command boundary;
- a versioned Scheduler confirmation/write contract covering explicit consent,
  idempotency, conflict/retry, revocation, and rollback for calendar and
  notification changes;
- entitlement lifecycle and cancellable worker contracts described above;
- rights/provenance review for metadata, captions, fixtures, and highlights;
- privacy deletion, child-profile, accessibility, and device-budget evidence.

## Consequences

The plan favors read-only, explainable assistance first. Autonomous playback,
derived media, and conversational experiences follow only after stronger
rights, confidence, and safety evidence. No item becomes Available without a
public artifact and release qualification.
