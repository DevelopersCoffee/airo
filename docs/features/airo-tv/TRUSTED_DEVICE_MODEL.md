# Airo TV Trusted Device Model

This contract defines the v2.0.0.1 platform boundary for trusted-device
relationships used by Airo TV, companion controllers, command routing, playback
tickets, and future device-picker flows.

Implementation contract:

- Package: `packages/core_pairing`
- Schema: `kAiroPairingSchemaVersion`
- Primary record: `AiroTrustedDeviceRecord`
- Policy evaluator: `AiroTrustedDeviceSecurityPolicy`

## Trust Record

A trusted-device record identifies one controller-to-receiver relationship. The
record carries:

- relationship ID;
- controller and receiver device IDs;
- controller and receiver roles;
- granted pairing scopes;
- validity window;
- revocation metadata;
- trust level;
- public key descriptor metadata.

The record must not carry raw key material, provider credentials, playlist
contents, media URLs, local file paths, local IP addresses, viewing history,
analytics payloads, or diagnostic contents.

## Trust Levels

The platform model defines these trust levels:

- `restricted`: playback-ticket and basic receiver flows only;
- `paired`: scoped pairing authority for routine controls;
- `trusted`: full trusted-device authority for delegated private operations;
- `owner`: owner-managed authority reserved for future account/device
  administration.

Product code should ask a platform policy whether a relationship satisfies a
required trust level. Airo TV screens should not hard-code role-specific trust
shortcuts.

## Key Descriptor

`AiroTrustedDeviceKeyDescriptor` stores public key metadata only:

- key ID;
- algorithm;
- public key fingerprint;
- creation time;
- validity window;
- revocation time.

The descriptor is enough for platform policy and storage layers to reason about
key freshness and rotation without committing this issue to native keystore,
secure storage, signing, or transport implementation.

## Security Policy

`AiroTrustedDeviceSecurityPolicy` evaluates:

- required pairing scope;
- minimum trust level;
- allowed key algorithms;
- key presence;
- not-yet-valid, expired, revoked, and rotation-due key states;
- relationship expiry and revocation through the existing access evaluator.

Results are deterministic and machine-readable through
`AiroTrustedDeviceSecurityCode`.

## Consumer Rule

Airo TV, command, playback, pairing UI, device picker, and cloud coordination
must consume the platform policy result. Product code may decide copy,
navigation, and user recovery flows, but the authority decision belongs to
`core_pairing`.
