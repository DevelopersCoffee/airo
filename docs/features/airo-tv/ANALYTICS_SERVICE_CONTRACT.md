# Airo TV Analytics Service Contract

ATV-069 defines the platform analytics service contract for Airo TV v2.0.0.1.
Feature modules submit typed events to `packages/core_analytics`; they must not
call Firebase, Google Analytics, Crashlytics, or another vendor SDK directly.

## Ownership

- Framework owns the service interface, lifecycle result codes, provider
  boundary, typed events, timed events, and deterministic adapters.
- Security and Privacy owns consent gates, local-only behavior, reset/delete
  semantics, prohibited payload validation, and redaction requirements.
- QA owns no-op, local diagnostics, provider failure, consent withdrawal,
  privacy pattern, and timed-event tests.
- Airo TV app code owns settings UI, user copy, and product workflow decisions
  that consume this platform contract.

## Service Boundary

`AiroAnalyticsService` exposes:

- `initialize(configuration)`
- `track(event)`
- `startTimedEvent(...)`
- `endTimedEvent(...)`
- `updateConsent(consent)`, which returns
  `AiroAnalyticsConsentTransitionResult`
- `setCollectionEnabled(enabled)`
- `flush()`
- `reset()`

The built-in service implementations are:

- `AiroNoOpAnalyticsService`
- `AiroLocalDiagnosticsAnalyticsService`
- `AiroProviderBackedAnalyticsService`

The provider-backed service accepts a sender function that must be implemented
by an isolated adapter. If that sender fails, the service returns
`provider_unavailable` instead of throwing through playback, UI, or feature
code.

Crash reporting follows the same platform boundary. Airo TV submits
`AiroCrashReport` to `core_analytics`; redaction, consent/local-only upload
blocking, local diagnostic storage, no-op behavior, and provider failure
handling remain platform responsibilities.

Provider-backed uploads also pass through the platform upload gate. Non-critical
events are deferred while playback is active, critical events remain eligible,
and provider outages record backoff state before future uploads are skipped.

## Configuration

`AiroAnalyticsServiceConfiguration` declares:

- provider kind
- product profile
- consent state
- collection enabled/disabled
- max queue size
- whether external upload is allowed
- whether the provider SDK is isolated behind the adapter
- whether analytics is non-blocking
- whether the installation ID is resettable

The configuration validator rejects local-only external uploads, unisolated
vendor adapters, blocking analytics, invalid queue budgets, and non-resettable
installation IDs.

Product-edition analytics profiles are also platform-owned. Airo TV selects an
`AiroAnalyticsProductEditionProfile` for Full TV, Standard TV, Lite Receiver,
Embedded Receiver, mobile companion, desktop companion, or local-only mode, then
derives service configuration from that profile. The profile contract defines
allowed purposes, event families, event names, queue/crash budgets, retention,
provider posture, and local-only upload blocking.

Retention and data-access policy is platform-owned as well.
`AiroAnalyticsRetentionPolicy` defines raw retention windows, consent/privacy
deletion plans, least-privilege access roles, production-data approval gates,
and public audit-safe maps before app or provider code consumes analytics data.

Dashboard and alert catalogs remain platform-owned.
`AiroAnalyticsDashboardCatalog` defines dashboard surfaces, aggregate metric
specs, alert thresholds, severity, evaluation windows, and runbook ids without
embedding provider-specific dashboard objects in Airo TV app code.

Self-hosted event gateway policy is also a platform boundary.
`AiroAnalyticsSelfHostedGatewayPolicy` evaluates schema safety, local-only
blocking, allowed regions, rate limits, retention support, deletion support, and
provider kind before any self-hosted backend adapter receives an event.

## Queue And Provider Behavior

Local diagnostics uses a bounded platform queue. If the queue is full, a higher
priority event can evict a lower priority event; otherwise the track result
returns `dropped_queue_full`. Queue result maps expose counts, priority counts,
and event metadata only.

Provider outage handling is deterministic. Failed sender calls return
`provider_unavailable`, update backoff state, and future events return
`provider_backoff_active` while the backoff window is active. Playback-aware
upload gating returns `deferred_by_playback` for non-critical events during
active playback.

## Consent And Local-Only Behavior

Analytics starts disabled/no-op by default. Product, playback-quality,
diagnostic, crash, and personalized analytics are controlled separately.
Local-only mode allows operational and diagnostics events locally, while
preventing external analytics upload. When consent is withdrawn, optional queued
events are removed immediately from the local diagnostics service.

Consent transitions report stable codes for accepted changes, optional queue
cleanup, local-only external upload blocking, collection disablement, and reset
generation state. Airo TV settings UI can render those results, but the
underlying cleanup and blocking rules remain in `core_analytics`.

## Privacy Rules

Every event is validated before provider upload or local retention. The standard
privacy filter rejects:

- raw media/channel/program/playlist names
- stream, signed, playlist, and other URLs
- local file paths
- local IP addresses
- auth headers, cookies, and credential-like values
- raw search text and voice transcripts

Timed events record duration buckets such as `1_3s`; they do not persist raw
duration values.

## Airo TV Consumption Rule

Airo TV, feature modules, playback, pairing, handoff, and diagnostics code
should depend on `core_analytics` or a platform adapter built on it.
Experimentation and remote-config code should consume `core_experimentation`.
Product code may decide which typed event to submit, but consent, privacy
validation, collection enablement, provider failure handling, and vendor SDK
isolation stay in the platform layer.

## Public Serialization

Public maps expose stable provider/profile/result IDs, booleans, queue budgets,
and violation codes only. They do not expose raw media URLs, provider payloads,
credentials, local paths, local IP addresses, viewing history, diagnostics
dumps, or store-console account data.
