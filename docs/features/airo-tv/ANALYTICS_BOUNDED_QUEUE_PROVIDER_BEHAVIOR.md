# Analytics Bounded Queue and Provider Behavior

## Ownership

ATV-073 is a platform contract. `packages/core_analytics` owns bounded queue
policy, priority eviction, queue snapshots, provider outage backoff, and
playback-aware upload gating.

Airo TV application code may display queue or provider state in diagnostics, but
it must not implement a parallel analytics queue, retry policy, or playback
upload gate.

## Bounded Queue

`AiroAnalyticsBoundedEventQueue` accepts typed analytics events up to its
configured capacity.

- If capacity remains, the event is accepted.
- If the queue is full and the new event has higher priority than an existing
  queued event, the lowest-priority queued event is evicted.
- If the queue is full and no lower-priority event exists, the event is dropped
  with `dropped_queue_full`.

Queue offer results use stable codes:

- `accepted`
- `evicted_lower_priority`
- `queue_full`

Queue snapshots expose max size, event count, priority counts, and stable event
metadata: event name, owner, purpose, priority, and schema version. They do not
include event params, provider payloads, media URLs, local paths, local IPs,
viewing history, or store-console account data.

## Provider Upload Gate

`AiroAnalyticsUploadGate` determines whether provider-backed analytics may call
the isolated sender.

- `eligible`: upload may proceed.
- `deferred_during_playback`: playback is active and the event is not critical.
- `provider_backoff_active`: provider outage backoff is active.

During active playback, critical events remain eligible. Lower priority events
are deferred before the provider adapter is called.

## Provider Outage Behavior

`AiroProviderBackedAnalyticsService` catches sender failures and returns
`provider_unavailable`. It records a backoff state with failure count and next
retry time. While that state is active, future events return
`provider_backoff_active` without calling the sender.

Successful provider sends reset the backoff state.

## Deterministic Flows

1. A bounded queue accepts events until capacity is reached.
2. A critical event evicts a lower-priority event when the queue is full.
3. A full queue rejects an event when no lower-priority queued event exists.
4. Queue public maps omit event params and provider payloads.
5. Provider outage creates backoff and skips repeated upload attempts.
6. Playback-active gating defers non-critical events but allows critical events.

## Deferred Work

Provider-specific retry intervals, persisted cross-process queue storage,
regional upload scheduling, and production dashboard wiring are out of scope for
ATV-073 and should be tracked separately.
