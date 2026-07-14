# Core Device Identity

Device identity and registration contracts for Airo V2.

This package is platform/framework code. Airo TV, companion apps, local
discovery, cloud orchestration, presence, command routing, and QA automation use
these contracts to reason about registered devices without coupling to an app UI,
backend store, vendor SDK, or transport.

## Scope

- Stable device/account/registration identifiers.
- Registration requests with node identity, role/profile/platform metadata,
  scoped grants, key descriptors, issue/expiry timestamps, and reset generation.
- Registered device records with trust, lifecycle, revocation, duplicate, reset,
  and key-rotation states.
- Deterministic registration decisions for valid, duplicate, revoked,
  expired, unsafe, unsupported, and unavailable cases.
- Fake and no-op registries for host-side tests.

This package does not generate cryptographic keys, store records, open sockets,
choose a cloud provider, issue credentials, run entitlement checks, render UI, or
proxy media.
