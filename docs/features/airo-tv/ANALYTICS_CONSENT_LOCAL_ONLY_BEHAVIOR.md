# Analytics Consent and Local-Only Behavior

## Ownership

ATV-072 is a platform contract. `packages/core_analytics` owns consent state,
local-only enforcement, provider upload blocking, local queue cleanup, reset
generation state, and public transition serialization.

Airo TV application code consumes these platform results when rendering settings
or diagnostics. It must not implement independent queue deletion, upload
blocking, or consent-purpose rules.

## Consent Modes

- `AiroAnalyticsConsentState.disabled()` keeps operational events allowed and
  disables optional product, playback quality, diagnostics, crash, and
  personalized analytics.
- `AiroAnalyticsConsentState.localOnly()` allows operational and diagnostics
  events to remain local while blocking product, playback quality, crash, and
  personalized events from provider upload.
- `AiroAnalyticsConsentState.allEnabled()` allows all supported analytics
  purposes subject to schema and privacy filters.

## Transition Results

`AiroAnalyticsService.updateConsent` returns
`AiroAnalyticsConsentTransitionResult` with stable codes:

- `accepted`: consent changed without cleanup or local-only restrictions.
- `optional_queue_cleared`: queued events that are no longer permitted were
  removed.
- `local_only_external_upload_blocked`: local-only mode is active and external
  product analytics upload is blocked.
- `collection_disabled`: collection is disabled, so future events are dropped
  before provider upload.
- `analytics_identity_reset`: the service has advanced its reset generation.

The public map exposes only consent booleans, transition codes, removed event
count, and reset generation. It does not include event names, event params,
provider payloads, media URLs, local paths, local IPs, viewing history, or
store-console account data.

## Deterministic Flows

1. Withdrawing optional analytics removes queued product, playback quality,
   crash, and personalized records while preserving still-permitted operational
   or diagnostic records.
2. Entering local-only mode blocks provider upload for non-operational and
   non-diagnostic events before the provider adapter is called.
3. Disabling collection clears local diagnostics and causes future track calls
   to return `dropped_by_collection_disabled`.
4. Resetting analytics clears retained local diagnostics and increments a reset
   generation marker.
5. Provider-backed services apply consent transitions before upload so vendor
   adapters cannot receive events that the platform rejected.

## Deferred Work

Account-linked deletion propagation, provider-specific deletion APIs, regional
defaults, and child-profile defaults are out of scope for ATV-072 and should be
tracked as separate platform or UX issues.
