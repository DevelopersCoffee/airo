# Airo TV Cross-Profile Compatibility Test Suite

ATV-068 defines the platform manifest for cross-profile compatibility coverage
across Full TV, Lite Receiver, Embedded Receiver, companion controllers, home
nodes, and protocol versions.

The reusable suite lives in `packages/product_capabilities` because profile
composition, capability advertisements, navigation availability, release gates,
and product profile contracts are owned there. The suite references behaviors
implemented by `core_protocol`, `core_sessions`, media routing, pairing, and
delegation contracts, but it does not execute transports or render app UI.

## Ownership

- QA owns scenario coverage, automation tags, required assertions, and release
  gate severity.
- Framework owns stable models, validation codes, and public serialization.
- Media owns handoff, playback-handle, receiver-only, and unsupported-transfer
  assertions.
- Security and Privacy owns redaction, credential safety, local-network safety,
  and trusted-relationship assertions.
- Release owns whether the suite is required before v2.0.0.1 support claims.

## Scenario Kinds

`ProductCompatibilityScenarioKind` covers:

- handoff
- receiver-only playback
- protocol compatibility
- companion unavailable
- unsupported transfer
- delegation failure
- sync continuity

## Required Assertions

Scenarios can require stable assertions for:

- capability advertisement
- composition acceptance
- unavailable-feature navigation absence
- handoff preflight
- source playback preservation
- session identity preservation
- progress and favorites preservation
- protocol compatibility
- trusted relationship
- authorized playback handle
- companion fallback
- delegation unsupported reason
- privacy redaction
- no raw media exposure
- no credential exposure

## Validation

`ProductCrossProfileCompatibilityPolicy` validates:

- scenarios exist and have unique IDs
- source and target profiles are distinct
- required assertions and automation tags are declared
- protocol versions are valid
- handoff and unsupported-transfer scenarios include preflight, capability, and
  source-playback-preservation assertions
- protocol mismatch scenarios include protocol compatibility assertions
- failure outcomes preserve source playback before handoff stops anything
- shared account and session identity are preserved when required
- companion-unavailable flows declare companion fallback
- all scenarios include privacy, raw-media, and credential redaction assertions

Accepted suites return only `accepted`.

## Default Airo TV Suite

`AiroTvCrossProfileCompatibilitySuites.releaseV2_0_0_1()` includes:

- mobile controller to Lite Receiver handoff
- mobile controller to receiver-only playback
- Full TV to Lite Receiver handoff
- old receiver with new controller protocol
- old controller with new receiver protocol
- Lite Receiver with companion unavailable
- unsupported Full TV feature transfer to Lite Receiver
- trusted delegation failure

## Airo TV Consumption Rule

Airo TV and release automation should evaluate this suite before claiming
cross-profile compatibility. Actual host tests, integration tests, device-lab
runs, protocol fixtures, and evidence storage bind to this manifest, but app
code should not hard-code cross-profile behavior in screens or widgets.

## Public Serialization

`toPublicMap()` exposes stable suite IDs, scenario IDs, participants, required
assertions, automation tags, expected outcomes, severity, protocol versions, and
availability flags. It does not expose raw media URLs, provider payloads,
credentials, local paths, local IP addresses, viewing history, diagnostics
dumps, or store-console account data.
