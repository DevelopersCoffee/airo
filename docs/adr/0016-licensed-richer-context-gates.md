# ADR 0016: Licensed richer-context provider gates

- Status: Accepted for internal prototype
- Date: 2026-07-27
- Claim state: Internal prototype; no provider approved
- Decision owners: Product Manager, Chief Open Source Officer, Chief Security Officer

## Context

Programme posters/synopses and sports fixtures can improve guide discovery, but
their APIs and underlying data have separate commercial, attribution,
redistribution, artwork, and event-rights constraints. An entitlement alone
does not constitute user consent or a data license. Airo's open-core policy
also places metadata enrichment and sports implementations in the private Pro
overlay.

## Decision

Use a provider-neutral public contract and a two-key request gate:

1. the matching stable `ProFeature` entitlement is enabled; and
2. the user has explicitly enabled the named provider after seeing its
   disclosure and attribution.

The adapter's license review must additionally be `approved`. The default is
`pending`, which behaves as denied. Missing adapter, denied entitlement,
missing/mismatched consent, or non-approved license returns no content and
must not invoke a network method.

Public CE contains typed requests/results, attribution, consent, and the gate
coordinator. It contains no production provider endpoint, credential, or SDK.
Real adapters are additive packages in the private `airo-pro` overlay. Tests
use recording fake adapters. Internal prototype surfaces render injected
results only; they are not advertised or released in v0.0.5.

Sports requests are accepted only for channels already classified as sports.
The public event model contains fixtures/results state, never odds or betting
fields. Provider queries may contain visible programme/event matching inputs,
but not playlist URLs, device IDs, account IDs, location, or viewing history.

Any non-empty result carries immutable provider attribution. Consent,
entitlement, or license revocation prevents subsequent calls; a production
overlay must also delete provider-derived cache according to its agreement.

## Alternatives considered

### Enable a free API behind entitlement only

Rejected. Free access does not establish commercial/app-store publication
rights, and entitlement is not informed third-party data consent.

### Put provider code and keys in the public feature package

Rejected. It violates the open-core package swap boundary, increases key
exposure, and couples CE guide/playback to a revocable third party.

### Scrape provider websites

Rejected. It is outside provider API terms, brittle, and inconsistent with
Airo's store-safety posture.

### Ship TVmaze CC BY-SA data now

Rejected until counsel resolves how ShareAlike applies to cached/enriched
records and combined application surfaces.

## Consequences

- No real provider network request ships from CE.
- Product can test detail/fixture composition deterministically with fake data.
- Provider activation is a deliberate overlay + release decision with a dated
  license record, disclosure, attribution, and security review.
- CE guide/playback remains functional when every richer-context gate is off.
- The provider evaluation in
  `docs/research/LICENSED_METADATA_PROVIDER_EVALUATION.md` is the current
  decision evidence and must be rechecked before activation.
