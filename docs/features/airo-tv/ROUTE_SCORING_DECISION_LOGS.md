# Airo TV Route Scoring And Decision Logs

This contract defines the v2.0.0.1 platform boundary for deterministic,
explainable, privacy-safe media route scoring.

Implementation contract:

- Package: `packages/core_media_routing`
- Schema: `kAiroMediaRouteScoringSchemaVersion`
- Score policy: `AiroMediaRouteScoringPolicy`
- Decision log: `AiroMediaRouteDecisionLog`
- Release-line base: `origin/v2`

## Score Inputs

Route scoring uses normalized platform-provided signals:

- route priority;
- health;
- bandwidth;
- latency;
- battery;
- thermal state;
- reliability;
- user preference;
- phone-proxy penalty;
- blocker penalty.

The score policy is deterministic. Eligible routes are ranked by total score
and ties are resolved by stable candidate id ordering.

## Decision Logs

Decision logs include:

- request id;
- generation time;
- selected candidate id;
- route kind;
- eligibility;
- total score;
- blocker codes;
- reason codes.

Logs are safe for local QA output and future diagnostics because they do not
include raw source values, access handles, provider auth material, playlist
contents, local paths, local IP addresses, device hostnames, or credential-like
diagnostics.

## Consumer Rule

Airo TV screens, route inspectors, playback adapters, and QA automation should
consume `AiroMediaRouteScoringPolicy` output. Product code should not implement
separate route ranking, phone-proxy penalty, tie-breaking, or raw diagnostic
formatting.

## Out Of Scope

This issue does not emit analytics events, collect benchmark traces, probe real
networks, implement route health events, own playback session state, or execute
media playback.
