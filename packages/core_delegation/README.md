# Core Delegation

Shared delegation task framework contracts for Airo V2 products.

This package is platform/framework code. Airo TV, Lite Receiver, mobile
companion, desktop companion, home-node, and future relay adapters consume these
contracts to route work without bundling every runtime into every receiver
build.

## Scope

- Delegation task kinds, stable task IDs, deduplication keys, and timeout
  limits.
- Encrypted-payload requirement checks for sensitive delegated work.
- Trusted candidate selection with capability confirmation.
- Deterministic blockers for unavailable, untrusted, slow, duplicate, expired,
  cancelled, or invalid tasks.
- Versioned result envelopes and fallback decisions.
- No-op dispatcher for unavailable delegation paths.

This package does not discover devices, open sockets, encrypt payload bytes,
call provider SDKs, render UI, or collect analytics.
