# airo_license

Local-first, accountless licensing **contracts** for Airo products.

This package is safe for the public Play/OSS tree:

- No RevenueCat / `purchases_flutter`
- No Supabase
- No HTTP client
- No `core_auth`

Default wiring is `LocalLicenseClient` + `UnavailablePurchaseProvider`.
Hosted registration, purchases, pairing, and device management belong in
`airo-pro` and `airo-license-api`.

Capability ids for Aika Stream v1 match `ProFeature.stableId` in
`core_entitlements`. Aika UI continues to gate on `Entitlements.isEnabled`.
