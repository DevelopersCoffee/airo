# Command Result, Expiry, Dedup, and Conflict Rules

Status: v2 platform contract for ATV-041.

## Ownership

Command lifecycle semantics are platform/framework behavior. Airo TV, companion
controllers, LAN transports, cloud orchestration, session recovery, media
controls, and QA automation consume the contract to avoid executing the same
command twice and to reject stale or conflicting command intent deterministically.

The contract lives in `packages/core_commands`. Adjacent packages retain their
ownership: `core_sessions` owns receiver-authoritative session revisions and
snapshots, `core_pairing` owns trusted-device scopes, and cloud orchestration
only routes commands after consuming command lifecycle decisions.

## Non-Goals

This issue does not implement:

- network transport
- backend storage
- playback execution
- session state ownership
- app UI
- media proxying

## Contract Shape

`AiroCommandEnvelope` carries the versioned command id, session id, sender,
target, action, scope, issue/expiry timestamps, idempotency key, optional
expected revision, delivery path, and redacted payload.

`AiroCommandLifecycleRecord` stores the command lifecycle state for dedup and
result recovery: command id, session id, idempotency key, sender, target, action,
status, revision, delivery path, update time, and optional result code.

`AiroCommandLifecyclePolicy` returns deterministic decisions:

- execute
- duplicate
- reject
- no-op

Decision codes cover expiry, target mismatch, missing scope, unsafe payloads,
duplicate command ids, duplicate idempotency keys, stale expected revisions,
same-revision conflicts, receiver unavailability, unsupported actions, and
unavailable lifecycle stores.

`AiroCommandLifecycleStore` is the provider boundary. `AiroNoOpCommandLifecycleStore`
never stores state. `AiroFakeCommandLifecycleStore` stores accepted records,
deduplicates LAN/cloud repeats, and records terminal results for host-side
tests.

## Result States

Command results are typed as accepted, in progress, completed, rejected,
expired, failed, unsupported, conflict, auth required, receiver unavailable, and
duplicate. Product code should render these statuses but not reinterpret them
with app-local lifecycle rules.

## Conflict Rules

- Same command id or idempotency key across LAN/cloud delivery is a duplicate
  and must not execute twice.
- Expired commands are rejected before execution.
- Expected revision lower than the current session revision is stale.
- A command for the same session and revision from a different sender is a
  conflict unless it is already identified as a duplicate.
- Missing scope maps to an auth-required command result.
- Receiver-unavailable and unsupported-action failures are typed separately so
  recovery and UX can choose different paths.

## Privacy Rules

Public maps, lifecycle records, decisions, and string output expose stable ids,
statuses, revision, delivery path, timestamps, payload keys, and result codes.
They must not expose raw payload values, media URLs, local file paths, local
addresses, credentials, playlist data, media titles, voice text, search text, or
diagnostic dumps.

## Automation

- Unit tests use fixed clocks, deterministic command ids, revisions, and
  lifecycle records.
- Policy tests cover accepted commands, LAN/cloud duplicates, expiry, target
  mismatch, missing scope, stale revision, same-revision conflict, unsupported
  actions, receiver unavailable, and redacted diagnostics.
- Store tests cover fake/no-op behavior without network or backend dependencies.
