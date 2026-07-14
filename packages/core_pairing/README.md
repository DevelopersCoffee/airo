# Core Pairing

Shared pairing, trusted-device, and playback-ticket contracts for Airo V2.

This package is platform/framework code. Airo TV, future companion apps, media
services, and remote-control transports consume these contracts instead of
defining product-specific trust or playback authorization models.

## Scope

- Pairing challenge lifecycle with explicit expiry.
- Trusted-device relationships with scoped permissions and revocation.
- Receiver-bound and session-bound playback tickets.
- Redacted playback source handles that reject raw URLs, local paths, and
  credential-like values.
- Deterministic validation results with machine-readable codes.

This package does not render QR codes, open sockets, persist records, sign
payloads, or start playback.
