# Playback Quality Telemetry Model

## Ownership

ATV-074 is a platform analytics contract. `packages/core_analytics` owns the
registered playback-quality event schemas, field kinds, validation fixtures,
privacy filtering, retention metadata, and public serialization.

Airo TV playback code may emit these typed events at product workflow points,
but it must not invent ad hoc event names, raw timing fields, media identifiers,
stream URLs, local paths, IP addresses, or provider payload fields.

## Registered Events

`AiroTvAnalyticsSchemas.registry()` includes these playback-quality schemas:

- `playback_startup_completed`
- `playback_buffering_summary`
- `playback_failover_completed`
- `playback_quality_sample`
- `playback_completion_summary`

All playback-quality schemas use `AiroAnalyticsPurpose.playbackQuality`,
`AiroAnalyticsRetentionClass.product90Days`, and required dashboard metadata.

## Safe Fields

Playback quality telemetry uses stable categories and buckets:

- `source_type`
- `startup_bucket`
- `stall_count_bucket`
- `stall_duration_bucket`
- `failover_reason`
- `route_type`
- `bitrate_bucket`
- `resolution_bucket`
- `completion_bucket`
- `exit_reason`
- `decoder_type`

Raw timings, raw bitrate numbers, channel names, titles, stream URLs, playlist
URLs, local paths, local IPs, raw queries, voice text, viewing history, and
provider payloads are rejected by schema or privacy validation.

## Fixtures

`AiroTvPlaybackQualityTelemetrySuites.standard()` defines deterministic cases
for:

1. bucketed startup telemetry
2. bucketed buffering telemetry
3. categorized failover telemetry
4. bucketed bitrate and resolution telemetry
5. bucketed completion telemetry
6. rejected raw bitrate values
7. rejected URL-like source values
8. rejected missing required completion fields

The fixture public map exposes event names, owners, purposes, field names,
expected validation codes, and pass/fail outcomes only. It does not expose raw
field values.

## Airo TV Consumption Rule

Airo TV should convert playback runtime measurements into the platform bucket
or category vocabulary before constructing `AiroAnalyticsEvent`. The platform
registry remains the authority for whether an event can be retained locally or
sent through a provider adapter.

## Deferred Work

Production dashboard names, native player hook wiring, provider-specific
quality dimensions, and persisted session aggregation are out of scope for
ATV-074 and should be tracked separately.
