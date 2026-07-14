# Airo TV Profile Data Ownership Matrix

ATV-066 defines the reusable platform matrix for deciding which product profile
owns, stores, syncs, preserves, or delegates each media data domain.

The contract lives in `packages/core_media_data` because playlist indexes, EPG
data, favorites, progress, AI embeddings, stream health, artwork, thumbnails,
and credential references are shared data concerns. Airo TV app code should
consume these rules and keep only product workflow decisions.

## Ownership

- Data owns storage scope, sync mode, upgrade strategy, downgrade strategy, and
  cache budget rules.
- Security owns encryption requirements and preservation rules for unsupported
  profile data.
- Media owns the domain list and which datasets are heavy or delegatable.
- QA owns matrix fixtures for Full TV, Lite Receiver, Embedded Receiver,
  upgrade, downgrade, and cloud-preservation paths.
- Airo TV app code must not hard-code data ownership in screens or widgets.

## Data Domains

`AiroDataDomain` covers:

- playlist index
- EPG
- favorites
- progress
- AI embeddings
- stream health
- artwork
- thumbnails
- credential references

## Rule Fields

`AiroProfileDataOwnershipRule` includes:

- `domain`: data domain being governed.
- `ownerProfile`: profile or helper node responsible for the domain.
- `storageScope`: unsupported, local device, profile-scoped, encrypted vault,
  delegated read-only, or cloud-preserved.
- `syncMode`: none, local-only, optional encrypted, delegated read-only, or
  cloud-preserved.
- `upgradeStrategy`: how Lite/Embedded data becomes Full TV-capable.
- `downgradeStrategy`: how Full TV data remains safe when moving to Lite or
  Embedded profiles.
- `preserveWhenUnsupported`: whether unsupported profile state must be retained.
- `encryptedAtRest`: whether persisted state requires encryption.
- `maxCacheMb`: deterministic cache budget.

## Validation

`AiroProfileDataOwnershipPolicy` returns stable validation codes for:

- missing domain rules
- duplicate domain rules
- invalid cache budgets
- unsafe credential-reference storage
- unsupported sync modes
- unsupported data that is not preserved
- Lite or Embedded profiles locally owning heavy data
- missing upgrade strategies
- unsafe downgrade strategies
- cloud-preserved state owned by the constrained profile itself

Accepted matrices return only `accepted`.

## Default Airo TV Matrices

The package ships defaults for:

- `AiroTvProfileDataOwnershipMatrices.fullTv()`
- `AiroTvProfileDataOwnershipMatrices.liteReceiver()`
- `AiroTvProfileDataOwnershipMatrices.embeddedReceiver()`

Full TV may own larger profile-scoped datasets. Lite Receiver keeps small local
favorites/progress/profile data, delegates EPG, stream health, artwork, and
thumbnail work, and preserves unsupported AI embedding state. Embedded Receiver
uses stricter cache budgets and delegated read-only heavy data. Credential
references always use encrypted vault storage.

## Airo TV Consumption Rule

Airo TV should evaluate the matrix before reading, writing, syncing, hiding, or
deleting profile data. Downgrades from Full TV to Lite/Embedded must preserve
unsupported profile state instead of deleting it. Upgrades from Lite/Embedded to
Full TV must use the declared rehydrate/adopt strategy.

## Public Serialization

`toPublicMap()` exposes stable profile IDs, domain IDs, ownership, storage,
sync, migration, preservation, encryption, and cache-budget metadata. It does
not include local filesystem paths, provider payloads, store-console account
data, raw credential material, media URLs, or device logs.
