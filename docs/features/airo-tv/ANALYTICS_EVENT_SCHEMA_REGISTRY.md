# Airo TV Analytics Event Schema Registry

ATV-070 defines the platform schema registry for Airo TV analytics events.
Feature modules submit `AiroAnalyticsEvent` instances that are validated against
registered schemas before local retention or provider upload.

The reusable registry lives in `packages/core_analytics` because that package
owns analytics events, consent, privacy filtering, service lifecycle, provider
boundaries, no-op/local diagnostics adapters, and performance instrumentation.

## Ownership

- Framework owns the event envelope, schema registry, validation codes, and
  public serialization.
- Data owns field kinds, allowed field lists, retention classes, and dashboard
  requirement metadata.
- Product owns event names, owners, and business purpose.
- Security and Privacy owns prohibited field handling and privacy validation.
- QA owns schema coverage and negative validation fixtures.

## Event Envelope

`AiroAnalyticsEvent` carries:

- stable snake_case event name
- owner
- purpose
- priority
- schema version
- parameter map

The schema registry verifies that the event name is registered, owner and
purpose match, schema version matches, required fields are present, extra fields
are rejected, field values match declared field kinds, and privacy validation
passes.

## Field Kinds

`AiroAnalyticsFieldKind` supports:

- stable ID
- category
- bucket
- count
- decimal
- boolean

Category, bucket, and stable-ID values must use stable snake_case strings.

## Registry Metadata

`AiroAnalyticsEventSchema` includes:

- event name
- owner
- purpose
- allowed fields
- prohibited fields
- retention class
- dashboard requirement
- test coverage requirement
- schema version

`AiroAnalyticsRetentionClass` currently covers operational 30-day, product
90-day, diagnostics 30-day, crash 90-day, and aggregate-only classes.

## Default Airo TV Schemas

`AiroTvAnalyticsSchemas.registry()` includes initial v2.0.0.1 schemas for:

- `playback_startup_completed`
- `playback_buffering_summary`
- `playback_failover_completed`
- `playback_quality_sample`
- `playback_completion_summary`
- `pairing_completed`
- `handoff_completed`
- `device_discovery_summary`
- `command_route_latency`
- `delegation_task_completed`
- `companion_availability_summary`
- `legacy_decoder_fallback`
- `subscription_conversion`

These schemas use approved category and bucket fields such as `source_type`,
`startup_bucket`, `stall_count_bucket`, `stall_duration_bucket`,
`failover_reason`, `route_type`, `bitrate_bucket`, `resolution_bucket`,
`completion_bucket`, `exit_reason`, `decoder_type`, `source_profile`,
`target_profile`, `result_category`, `discovery_method`,
`availability_category`, `device_count_bucket`, `command_category`,
`latency_bucket`, `task_category`, `companion_profile`,
`route_health_bucket`, `queue_depth_bucket`, `device_tier`, `fallback_count`,
`entry_surface`, `plan_bucket`, and `success`.

`AiroTvPlaybackQualityTelemetrySuites.standard()` provides deterministic
accepted and rejected fixture cases for playback-quality telemetry without
exposing raw field values in public maps.

`AiroTvDeviceEcosystemTelemetrySuites.standard()` provides deterministic
accepted and rejected fixture cases for pairing, handoff, discovery, command
latency, delegation, and companion availability telemetry without exposing raw
field values in public maps.

## Airo TV Consumption Rule

Airo TV and feature modules must use registered schemas rather than arbitrary
analytics maps. Unknown events, unexpected fields, missing required fields,
wrong field kinds, owner/purpose mismatches, and privacy violations are rejected
before any provider adapter receives the event.

## Public Serialization

`toPublicMap()` exposes stable schema IDs, owners, purposes, field names, field
kinds, retention classes, retention days, dashboard requirements, and validation
codes. It does not expose provider payloads, raw media URLs, local paths, local
IP addresses, credential material, viewing history, diagnostics dumps, or
store-console account data.
