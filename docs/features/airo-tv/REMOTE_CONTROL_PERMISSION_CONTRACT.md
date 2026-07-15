# Airo TV Remote Control Permission Contract

This contract defines the v2.0.0.1 platform boundary for remote-control
authorization, local-only mode, approval-required mode, profile restrictions,
and deterministic command gating.

Implementation contract:

- Package: `packages/core_remote_control`
- Schema: `kAiroRemoteControlSchemaVersion`
- Primary policy: `AiroRemoteControlPermissionPolicy`
- Request model: `AiroRemoteControlRequest`
- Decision model: `AiroRemoteControlDecision`

## Ownership Boundary

Remote-control authorization is platform/framework behavior. Airo TV app code
may render local-only settings, approval prompts, profile copy, and recovery
flows, but it must consume platform decision codes rather than duplicating
authorization rules in feature code.

The policy composes existing platform contracts:

- `core_pairing` for trusted-device scopes, revocation, trust level, and key
  state;
- `core_commands` for command expiry, target, scope, idempotency, and payload
  privacy validation;
- `core_protocol` for receiver lifecycle and remote-control capability checks;
- `core_sessions` for optional playback-session membership permissions.

## Modes

`AiroRemoteControlMode` is the durable platform setting:

- `disabled`: deny all remote-control commands.
- `localOnly`: deny cloud/recovery routes, allow same-network paired commands.
- `sameAccountRemote`: allow same-account remote routes after trust, receiver,
  command, profile, and session checks pass.
- `approvalRequired`: require an unexpired approval grant for remote routes
  after the other checks pass.

Same-network control must not depend on cloud availability.

## Deterministic Decisions

`AiroRemoteControlDecision` returns a stable action and machine-readable codes:

- `allow` for dispatchable commands;
- `requireApproval` when approval UI is needed before a remote route can
  proceed;
- `deny` for failed authorization;
- `noOp` when a source/adapter is intentionally unavailable.

Public maps include only stable IDs, route/mode/action codes, and command
metadata. They do not include payload values, key fingerprints, media handles,
local paths, local IPs, approval notes, or private provider data.

## Required Use Cases

- Local-only mode blocks cloud/recovery remote routes while allowing
  same-network paired control.
- Same-account remote mode accepts a trusted controller with valid key,
  receiver capability, command scope, and session membership when present.
- Approval-required mode returns `approval_required` until an approved,
  unexpired grant exists.
- Child/restricted profile policy blocks cloud routes and elevated actions.
- Revoked, expired, insufficient-trust, or key-invalid devices are denied.
- Missing receiver remote-control capability or unavailable receiver lifecycle
  denies command dispatch.
- Missing, expired, revoked, or permission-missing session membership is denied
  when a session snapshot is supplied.
- Fake and no-op permission sources are available for deterministic host-side
  automation.
