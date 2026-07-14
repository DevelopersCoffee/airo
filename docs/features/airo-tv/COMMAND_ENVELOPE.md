# Airo TV Command Envelope

This contract defines the v2.0.0.1 platform boundary for connected-device
commands used by Airo TV, companion controllers, playback sessions, AI
delegation, local transports, and future cloud coordination.

Implementation contract:

- Package: `packages/core_commands`
- Schema: `kAiroCommandSchemaVersion`
- Protocol version: `kAiroCommandProtocolVersion`
- Primary envelope: `AiroCommandEnvelope`
- Validator: `AiroCommandValidationPolicy`

## Envelope Fields

A command envelope carries:

- command ID;
- session ID;
- sender node ID;
- target node ID;
- command kind;
- command action;
- required pairing scope;
- issue and expiry timestamps;
- idempotency key;
- privacy-checked payload keys.

The envelope is transport-neutral. LAN, cloud, WebSocket, fake, and future
generated-protocol transports must carry the same authority and expiry fields.

## Command Kinds

The platform model includes command kinds for:

- playback;
- navigation;
- text input handles;
- AI delegation handles;
- device operations.

Text and AI commands should carry handles or references approved by the
platform contract, not raw user-entered text or voice transcripts.

## Validation

`AiroCommandValidationPolicy` rejects:

- schema mismatch;
- protocol too old or too new;
- expired envelopes;
- target mismatch;
- missing authority scope;
- duplicate idempotency key;
- unsafe payload fields or values.

Validation results are deterministic and machine-readable through
`AiroCommandValidationCode`.

## Result Contract

`AiroCommandResult` reports accepted, rejected, unsupported, completed, or
failed status. String output redacts payload values so logs and diagnostics can
identify command shape without exposing media references, provider credentials,
local paths, local IP addresses, user text, analytics payloads, or diagnostics.

## Consumer Rule

Airo TV, companion remote controls, playback sessions, AI delegation, and cloud
coordination should consume `core_commands`. Product code may render progress,
copy, and recovery flows, but command authority, expiry, idempotency, and
payload privacy belong to the platform contract.
