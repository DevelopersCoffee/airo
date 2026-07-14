# Core Commands

Versioned command envelope contracts for Airo connected devices.

This package is platform/framework code. Airo TV, companion apps, local
transports, cloud coordination, playback sessions, and QA automation consume
this contract instead of defining feature-specific remote-control payloads.

## Scope

- Versioned command envelopes for playback, navigation, text input,
  AI delegation, and device commands.
- Deterministic validation for schema, protocol, expiry, receiver, authority,
  duplicate idempotency, and payload privacy.
- Typed command results with redacted payload output.
- No-op and fake dispatchers for host-only tests.

This package does not open sockets, persist sessions, execute playback,
render remote-control UI, generate Protobuf schemas, or coordinate cloud
delivery.
