# Core Analytics

Vendor-neutral analytics contracts and privacy filters for Airo.

This package owns shared analytics event types, consent gates, no-op/local
diagnostics providers, and prohibited-field validation. Feature modules should
depend on this package or an adapter built on it rather than importing vendor
analytics SDKs directly.

## Scope

- Typed analytics event envelope.
- Analytics schema registry with stable event names, owners, purposes, allowed
  fields, prohibited fields, retention classes, dashboard requirements, and
  validation codes.
- Service configuration for provider kind, product profile, collection
  enablement, queue budgets, provider isolation, non-blocking behavior, and
  resettable installation IDs.
- Product-edition analytics profiles for Full TV, Standard TV, Lite Receiver,
  Embedded Receiver, mobile companion, desktop companion, and local-only
  configuration derivation.
- Retention and data-access policy for raw retention windows, deletion plans,
  least-privilege access decisions, and public audit-safe serialization.
- Dashboard metric and operational alert catalogs for executive, playback,
  legacy-device, ecosystem, subscription, and regression reporting surfaces.
- Consent and local-only collection gates.
- Consent transition results for queue cleanup, local-only external upload
  blocking, collection disablement, and reset generation state.
- Bounded queue policy with priority eviction, redacted queue snapshots,
  playback-aware upload gating, and provider backoff state.
- Prohibited field and value validation.
- Reusable privacy filter fixture suites for URL-like values, credential-like
  values, auth header fields, local paths, local IPs, raw queries, raw titles,
  and approved bucket/category values.
- No-op provider for builds without external analytics.
- Bounded local diagnostics provider for host tests and development builds.
- Provider-backed adapter boundary that catches provider failures and falls
  back to deterministic no-op behavior.
- Timed event helper that emits bucketed durations instead of raw timings.
- Default Airo TV v2.0.0.1 event schemas for playback startup, buffering,
  failover, quality samples, completion, pairing, handoff, legacy decoder
  fallback, device discovery, command route latency, delegation, companion
  availability, and subscription conversion.
- Playback quality telemetry fixtures that validate bucketed startup,
  buffering, failover, bitrate, resolution, and completion fields.
- Device ecosystem telemetry fixtures that validate pairing, handoff,
  discovery, command latency, delegation, and companion availability fields.
- Crash reporting contracts with redaction policy, no-op/local/provider-backed
  adapters, and public maps that omit raw stack, native, media, network, and
  credential material.
- Performance instrumentation schema for UI, playback, import, search,
  protocol, command, memory, storage, network, and pairing samples.
- No-op and fake performance instrumentation sinks for deterministic tests.

This package does not include Firebase, Crashlytics, or another provider SDK.
It also does not define dashboards, upload schedules, device profilers, frame
observers, or app-specific performance UI.
