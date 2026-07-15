# Airo TV Analytics Privacy Filter Tests

ATV-071 defines the platform privacy-filter test suite for Airo TV analytics.
The reusable fixtures live in `packages/core_analytics` because analytics
privacy validation must run before provider upload, local diagnostics retention,
schema acceptance, or feature-module instrumentation.

## Ownership

- Security owns prohibited field and value classes.
- QA owns deterministic fixture coverage and expected violation codes.
- Framework owns reusable fixture models, public serialization, and the
  platform privacy filter.
- Airo TV app code consumes the filter and fixtures instead of implementing
  feature-local redaction checks.

## Fixture Contract

`AiroAnalyticsPrivacyFilterTestCase` defines:

- stable case ID
- analytics field name
- internal sample value
- sample class
- expected privacy code, when the case should be rejected

`AiroAnalyticsPrivacyFilterTestSuite.toPublicMap()` deliberately omits sample
values. Public output exposes only stable case IDs, fields, sample classes,
expected privacy codes, and whether rejection is expected.

## Standard Airo TV Suite

`AiroTvAnalyticsPrivacyFilterSuites.standard()` covers:

- approved category and bucket values
- URL-like values
- local filesystem paths
- local/private IP values
- credential-like values
- auth header field names
- raw search query fields
- raw title, program, and channel fields
- raw source URL fields

## Validation Rule

Each fixture is converted to an `AiroAnalyticsEvent` and evaluated through
`AiroAnalyticsPrivacyFilter.standard`. Rejected cases must produce the expected
`AiroAnalyticsPrivacyCode`; approved cases must produce no violations.

## Airo TV Consumption Rule

Feature modules may submit approved bucket/category analytics values such as
`source_type` or `startup_bucket`. They must never submit raw media labels,
source URLs, local addresses, local paths, auth headers, raw search text, voice
transcripts, provider payloads, viewing history, or credential material.

## Public Serialization

The suite public map must not expose raw media URLs, local filesystem paths,
local IP addresses, credential-like values, channel names, program titles, raw
queries, provider payloads, diagnostics dumps, viewing history, or
store-console account data.
