# Self-Hosted Event Gateway Option

Issue: ATV-081
Package: `core_analytics`
Layer: Platform framework, consumed by backend adapters and Airo TV analytics
configuration

## Purpose

The self-hosted event gateway option defines the reusable contract Airo TV can
use if analytics ingestion moves away from a vendor SDK. The contract covers
schema validation, privacy validation, regional residency, rate limits,
retention policy support, deletion support, and public gateway diagnostics. It
does not implement an HTTP server, request signing, credential material, or cloud
deployment.

## Ownership

- Backend owns real gateway deployment, authentication, request signing, storage
  adapters, and rate-limit enforcement.
- Privacy owns regional residency, local-only blocking, deletion support, and
  retention support.
- Analytics owns schema registry integration, event eligibility, and aggregate
  gateway diagnostics.
- Security owns public diagnostics boundaries and exclusion of endpoint URLs,
  API keys, credentials, local-network data, provider payloads, and raw
  diagnostics.
- Framework owns `core_analytics` models, gateway decisions, validation codes,
  and deterministic tests.

## Gateway Policy

`AiroAnalyticsSelfHostedGatewayPolicy` includes:

- stable gateway id;
- provider kind, which must be `self_hosted`;
- analytics schema registry;
- analytics retention policy;
- allowed gateway regions;
- per-minute rate limit;
- retention-policy support flag;
- deletion-request support flag.

`AiroTvAnalyticsSelfHostedGateways.standard()` uses the Airo TV schema registry,
standard retention/data-access policy, United States, European Union, and India
regional buckets, and a bounded 120-event-per-minute default.

## Evaluation

`evaluate()` returns `AiroAnalyticsGatewayDecision` after checking:

1. provider kind is self-hosted;
2. collection is enabled;
3. runtime consent is not local-only;
4. target region is allowed;
5. rate-limit state has capacity;
6. event schema and privacy validation pass;
7. retention policy supports the event retention class;
8. deletion requests are supported.

Decision codes are stable:

- `accepted`
- `collection_disabled`
- `local_only_upload_blocked`
- `schema_rejected`
- `privacy_rejected`
- `region_not_allowed`
- `rate_limited`
- `retention_unsupported`
- `deletion_unsupported`
- `provider_kind_invalid`

## Public Serialization

Gateway public maps expose stable gateway id, provider kind, allowed region ids,
capacity, registered schema count, event name, owner, purpose, retention class,
rate-limit counters, schema codes, and decision codes only. They must not expose
endpoint URLs, API keys, request signatures, media titles, URLs, local paths,
local IP addresses, credentials, provider payloads, store-console accounts,
viewing history, crash stacks, or diagnostics dumps.

## Automation

- Unit tests accept a registered, privacy-safe event.
- Unit tests reject unknown schemas and privacy violations before upload.
- Unit tests enforce local-only blocking, collection disablement, regional
  controls, and rate limits.
- Unit tests require self-hosted provider kind, retention support, and deletion
  support.
- Public-map tests verify stable metadata without endpoints, credential material, provider
  payloads, local-network data, or diagnostics dumps.

## Deferred Work

HTTP ingestion, request signing, auth keys, storage schemas, regional cloud
deployment, backend deletion/export jobs, dashboard wiring, production rate
limits, and Airo TV runtime adapter wiring remain separate issues. This issue
defines the platform contract those features must consume.
