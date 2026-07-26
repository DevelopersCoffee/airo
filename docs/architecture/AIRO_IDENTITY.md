# Airo Identity

`core_auth` exposes provider-neutral `AiroIdentity` and
`AiroIdentityProvider` contracts. The coordinator defaults to a stable,
device-local anonymous principal. It never opens a login wall or falls back
silently when an explicitly requested provider is unavailable.

The initial providers are:

- anonymous, using an opaque device-scoped subject with no network call;
- QR pairing, delegating signed-claim verification to the pairing owner;
- Google, receiving a sanitized claim through callbacks.

Google and Firebase SDK types remain in
`app/lib/core/auth/google_auth_service.dart` and its Airo adapter. Core
packages receive only `AiroExternalIdentityClaim`; access tokens, pairing
secrets, and SDK credentials are not retained in identity principals or
printed by their `toString`.

Apple, LAN-only, and enterprise provider kinds are reserved by the stable
enum for later adapters. Cloud sync transports consume `AiroIdentity`; they
must not import a provider SDK or trigger authentication unless a
cross-device feature explicitly requests it.
