# Logo Burst Connection Policy

Issue: #787
Date: 2026-07-15

## Decision

Do not add a custom HTTP/2 image fetch adapter for Airo TV logo loading in the
current v2 slice.

Airo TV channel cards render logos through Flutter image providers
(`AiroNetworkImage` / `NetworkImage`), not through the playlist `Dio` client.
Adding an HTTP/2 adapter to the playlist fetch path would not change logo
fetching behavior. Moving logo loading to a custom platform fetcher would be a
larger rendering/cache contract and should be driven by benchmark evidence.

Current policy:

- Keep logo loading on Flutter image providers.
- Bound pre-cache bursts before they reach the image pipeline.
- Deduplicate pre-cache requests by logo URL in the TV grid.
- Cap candidates per host to avoid one playlist host dominating sockets.
- Revisit HTTP/2 only if benchmark evidence shows the bounded Flutter image
  path is still network-limited on target devices.

## Platform Contract

`AiroLogoBurstPolicy` lives in `packages/platform_channels` because it operates
on reusable `IPTVChannel` metadata and can be consumed by any Airo surface that
renders dense channel/logo lists.

The policy selects pre-cache candidates by:

- focus window around the active grid index
- max candidates per burst
- max candidates per normalized host
- duplicate logo URL suppression
- valid HTTP(S) logo URL filtering

Feature code may request candidates from the platform policy. It must not add
screen-local per-host connection pools, HTTP/2 adapters, or bespoke image
fetchers.

## Validation

Focused local validation for this slice:

- `packages/platform_channels/test/logo_burst_policy_test.dart`
- analyzer for `platform_channels` policy/tests
- analyzer for the Airo TV grid consumer

## Follow-Ups

- #773 remains the physical-device/image-cache evidence issue for logo decode
  and memory budgets.
- #778 should add benchmark harness coverage for cold grid fill and logo burst
  behavior with large playlists.
