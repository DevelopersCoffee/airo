# Airo TV Profile Navigation Manifests

ATV-065 defines reusable platform navigation manifests for Airo TV product
profiles. The goal is to prevent Full, Lite, and Embedded profiles from exposing
empty routes or sections backed by unavailable modules.

The contract lives in `packages/product_capabilities` because navigation
availability depends on product profiles, modules, capabilities, and product
composition. Airo TV app code should consume accepted navigation manifests and
keep only screen layout, focus behavior, and copy.

## Ownership

- UI owns navigation section intent, display keys, route IDs, and render tiers.
- Media owns module and capability requirements for playback, guide, search,
  favorites, recent, and diagnostics sections.
- Framework owns validation against profile and composition manifests.
- QA owns cross-profile fixtures proving unavailable sections cannot render.
- Airo TV app code must not create profile-specific route shortcuts in screens.

## Manifest Fields

`ProductNavigationManifest` includes:

- `schemaVersion`: schema version shared with product capability contracts.
- `profileId`: target product profile.
- `sections`: ordered `ProductNavigationSection` values.

`ProductNavigationSection` includes:

- `entry`: stable navigation entry such as Home, Live, Guide, Search, Settings,
  or Diagnostics.
- `routeId`: stable route ID consumed by app routing.
- `displayKey`: stable text key consumed by product UI.
- `renderTier`: rich, standard, or lightweight.
- optional `requiredModule`.
- optional `requiredCapability`.

## Validation

`ProductNavigationManifestPolicy` returns stable validation codes for:

- profile mismatch
- missing route ID
- missing display key
- duplicate route ID
- navigation entry unsupported by the active profile
- required module unavailable in the active profile
- required capability unavailable in the active profile
- required module absent from the compiled product composition
- render tier unsupported by the active profile

Accepted manifests return only `accepted`.

## Default Airo TV Manifests

The package ships default manifests for:

- `AiroTvNavigationManifests.fullTv()`
- `AiroTvNavigationManifests.liteReceiver()`
- `AiroTvNavigationManifests.embeddedReceiver()`

Full TV may use rich and standard sections, including Guide. Lite Receiver uses
lightweight sections only and excludes Guide/Profile-management routes.
Embedded Receiver stays minimal with Home, Live, and Settings.

## Airo TV Consumption Rule

Airo TV should validate a navigation manifest against the active
`ProductProfileManifest` and, when available, `ProductCompositionManifest`
before rendering sections or registering routes. Rejected navigation sections
should be omitted or replaced by an unavailable state rather than rendered as
empty screens.

## Public Serialization

`toPublicMap()` exposes stable profile IDs, route IDs, display keys, render
tier IDs, module IDs, and capability IDs. It does not include local filesystem
paths, provider payload markers, store-console account data, raw credential
material, or device logs.
