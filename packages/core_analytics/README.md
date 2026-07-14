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
- Consent and local-only collection gates.
- Prohibited field and value validation.
- No-op provider for builds without external analytics.
- Bounded local diagnostics provider for host tests and development builds.
- Provider-backed adapter boundary that catches provider failures and falls
  back to deterministic no-op behavior.
- Timed event helper that emits bucketed durations instead of raw timings.
- Default Airo TV v2.0.0.1 event schemas for playback startup, pairing,
  handoff, legacy decoder fallback, and subscription conversion.
- Performance instrumentation schema for UI, playback, import, search,
  protocol, command, memory, storage, network, and pairing samples.
- No-op and fake performance instrumentation sinks for deterministic tests.

This package does not include Firebase, Crashlytics, or another provider SDK.
It also does not define dashboards, upload schedules, device profilers, frame
observers, or app-specific performance UI.
