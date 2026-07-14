# Device Ecosystem Metrics Model

## Ownership

ATV-075 is a platform analytics contract. `packages/core_analytics` owns the
registered pairing, handoff, discovery, command-route, delegation, and companion
availability event schemas, validation fixtures, retention metadata, redaction,
and public serialization.

Airo TV, companion apps, and device ecosystem modules may emit these typed
events at workflow points. They must not define app-local analytics maps, raw
device identifiers, local-network addresses, hostnames, prompt text, transcripts,
contact data, or provider payload fields.

## Registered Events

`AiroTvAnalyticsSchemas.registry()` includes these device ecosystem schemas:

- `pairing_completed`
- `handoff_completed`
- `device_discovery_summary`
- `command_route_latency`
- `delegation_task_completed`
- `companion_availability_summary`

These schemas use `AiroAnalyticsPurpose.operational` and
`AiroAnalyticsRetentionClass.operational30Days`.

## Safe Fields

Device ecosystem telemetry uses stable categories and buckets:

- `source_profile`
- `target_profile`
- `route_type`
- `result_category`
- `discovery_method`
- `availability_category`
- `device_count_bucket`
- `command_category`
- `latency_bucket`
- `task_category`
- `companion_profile`
- `route_health_bucket`
- `queue_depth_bucket`
- `command_latency_bucket`

Raw device IDs, device names, hostnames, SSIDs, MAC addresses, local IPs, media
titles, stream URLs, prompts, transcripts, provider payloads, contact data, and
email addresses are rejected by schema or privacy validation.

## Fixtures

`AiroTvDeviceEcosystemTelemetrySuites.standard()` defines deterministic cases
for:

1. safe pairing completion
2. safe handoff completion with latency bucket
3. safe device discovery summary
4. safe command route latency
5. safe delegation completion
6. safe companion availability summary
7. rejected local-network address fields
8. rejected raw command latency values
9. rejected prompt-like delegation fields

The fixture public map exposes event names, owners, purposes, field names,
expected validation codes, and pass/fail outcomes only. It does not expose raw
field values.

## Airo TV Consumption Rule

Airo TV should translate pairing, handoff, command, delegation, and companion
runtime observations into the platform category or bucket vocabulary before
constructing `AiroAnalyticsEvent`. The schema registry remains the authority for
whether an event can be retained locally or sent through a provider adapter.

## Deferred Work

Production dashboard layout, live pairing transport hooks, device-lab
aggregation, and persisted cross-session ecosystem summaries are out of scope
for ATV-075 and should be tracked separately.
