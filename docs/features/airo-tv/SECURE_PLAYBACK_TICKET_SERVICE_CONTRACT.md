# Secure Playback Ticket Service Contract

Status: v2 platform contract for ATV-042.

## Ownership

Playback-ticket service behavior is platform/framework security and media
behavior. Airo TV, companion controllers, restricted receivers, media routing,
cloud orchestration, and QA automation consume the contract to grant receiver
playback without exposing provider credentials or raw media references.

The contract lives in `packages/core_pairing`, which already owns trusted-device
relationships, scoped permissions, key descriptors, playback source handles, and
ticket validation.

## Non-Goals

This issue does not implement:

- provider credential resolution
- backend storage
- network transport
- media proxying
- DRM/license flow
- playback execution
- app UI

## Contract Shape

`AiroPlaybackTicketIssueRequest` describes a request to issue a receiver-bound
and session-bound ticket with a redacted source handle, requested scopes,
issuer device, and a short validity window.

`AiroPlaybackTicketRedeemRequest` describes receiver redemption for a specific
ticket id, receiver, session, scope, and fixed timestamp.

`AiroPlaybackTicketServicePolicy` validates issuer access, issuer trust level,
key state, receiver binding, source-handle safety, scope, and ticket lifetime.
It also maps ticket validation outcomes into service decisions.

`AiroPlaybackTicketService` is the provider boundary.
`AiroNoOpPlaybackTicketService` never stores or redeems anything.
`AiroFakePlaybackTicketService` stores tickets in memory, redeems each ticket
once, and supports deterministic revocation for host-side tests.

## Security Rules

- Tickets are receiver-bound and session-bound.
- Tickets are short-lived and single-use.
- Tickets are revocable.
- Issue requests require a trusted device with the playback-ticket issue scope.
- Issuer keys must be present, supported, active, and not due for rotation when
  the policy requires rotation.
- Source handles are redacted stable references, not URLs, local paths, local
  addresses, provider payloads, credentials, media titles, or viewing history.
- Public diagnostics expose stable ids and status codes only.

## Automation

- Unit tests use fixed clocks, deterministic trusted-device records, and
  redacted source handles.
- Policy tests cover accepted issue, issue denial, issuer key failures,
  one-time redemption, receiver/session/scope/timing/revocation failures, and
  redacted diagnostics.
- Service tests cover fake/no-op behavior without backend, network, provider,
  storage, or app UI dependencies.
