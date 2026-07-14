# Device Identity Registration Contract

Status: v2 platform contract for ATV-038.

## Ownership

Device identity and registration are platform/framework behavior. Airo TV,
companion apps, local discovery, cloud orchestration, presence, command routing,
and QA automation consume the contract to reason about registered devices,
revocation, duplicate handling, reset state, scoped grants, and key lifecycle.

The contract lives in `packages/core_device_identity`. Adjacent packages retain
their ownership: `core_protocol` owns connected-node advertisement identity, and
`core_pairing` owns trusted-device relationships, key descriptors, trust levels,
and scoped permissions.

## Non-Goals

This issue does not implement:

- cloud provider selection
- persistent backend storage
- secure hardware key generation
- credential issuance
- entitlement checks
- presence leases
- command execution
- media proxying
- app UI

## Contract Shape

`AiroDeviceStableValue` validates privacy-safe stable identifiers and rejects
URLs, local paths, private addresses, credential-like values, and malformed ids.

`AiroDeviceRegistrationRequest` describes an attempted registration with
request, registration, account, and device ids; a `core_protocol`
`AiroNodeIdentity`; a `core_pairing` key descriptor; requested scopes; channel;
issue/expiry timestamps; trust level; and reset generation.

`AiroRegisteredDeviceRecord` describes the registered platform identity:
account, device, node identity, key descriptor, trust level, scopes, state,
registration time, optional last-seen time, revocation time, duplicate reference,
and reset generation.

`AiroDeviceRegistrationPolicy` returns deterministic decisions:

- register
- merge existing
- deny
- no-op

Decision codes cover schema/protocol mismatch, unsafe stable ids, unsupported
roles, missing required scopes, missing or unsupported keys, key lifecycle
failures, expired requests, duplicate node/key fingerprints, revoked devices,
account mismatch, reset requirements, and unavailable registries.

`AiroDeviceIdentityRegistry` is the provider boundary. `AiroNoOpDeviceIdentityRegistry`
never opens a provider connection. `AiroFakeDeviceIdentityRegistry` evaluates,
stores accepted records in memory, supports deterministic revocation, and is
intended for host-side tests.

## Security Rules

- Registration records must expose stable ids and state only; diagnostics must
  not expose raw network addresses, credentials, local paths, media URLs,
  backend payloads, sensitive account data, or viewing history.
- Device records are not authority by themselves. Command, playback, presence,
  and cloud orchestration layers must still evaluate their own trust/scope and
  freshness requirements.
- Duplicate node identity or duplicate key fingerprint across different device
  ids is a deny result until a later merge contract explicitly resolves it.
- Revoked and reset-required devices cannot be silently reactivated.
- Repeated registration of the same active device merges existing state instead
  of creating a second identity.

## Automation

- Unit tests use fixed clocks, stable ids, and deterministic key descriptors.
- Policy tests cover valid registration, idempotent merge, duplicate denial,
  revoked/reset denial, key lifecycle failures, unsafe identifiers, and expired
  requests.
- Adapter tests cover fake/no-op registries without network or persistence side
  effects.
