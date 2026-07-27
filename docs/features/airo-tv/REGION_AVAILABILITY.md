# Region availability contract

Airo TV uses region information only to make stream availability hints and
automatic selection safer. It is not an entitlement or rights decision, and a
user can still manually try a channel.

## Resolution order

`RegionResolver` checks these signals in order:

1. Android SIM country ISO, read without phone identity or location data;
2. application/device locale country;
3. a still-fresh cached network-derived country;
4. an explicitly opted-in network resolver.

The production v0.0.5 composition enables only SIM and locale. It does not call
an IP geolocation service. The reusable network boundary requires explicit
opt-in and enforces a 30-day cache. Neither raw IP addresses nor SIM
identifiers are stored.

## Availability behavior

A channel is marked `likelyBlocked` when its retained stream source is
explicitly restricted or its declared country conflicts with the resolved
country. Missing country information remains `unknown`; `WW`, `INT`, and
`GLOBAL` are treated as globally available.

Likely blocked channels remain visible, move below available/unknown channels,
and show “Not available in your region” with matching semantics. The
`firstRegionAvailableChannel` policy excludes them from automatic selection.
An HTTP 403 is reported as a non-retryable region-likely failure rather than a
device failure or a credentials instruction.
