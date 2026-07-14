# Airo TV Product Composition Validator

ATV-061 defines the reusable platform validator that proves an Airo TV product
profile, compiled module set, module lifecycle manifests, and runtime feature
flags are internally consistent.

The validator lives in `packages/product_capabilities` because build-time and
runtime composition rules are shared platform contracts. Airo TV app code should
consume accepted composition results and keep only product navigation, screens,
copy, and workflow decisions.

## Ownership

- Framework owns `ProductCompositionManifest`, validation codes, and public
  serialization.
- DevEx owns deterministic output for build tooling, release checks, and CI.
- QA owns Full TV, Lite Receiver, and negative composition fixtures.
- Release owns the rule that runtime flags cannot expose modules absent from the
  compiled profile.
- Airo TV app code must not route to unavailable modules or start modules whose
  composition validation failed.

## Manifest Fields

`ProductCompositionManifest` includes:

- `schemaVersion`: schema version shared with product capability contracts.
- `profileManifest`: active `ProductProfileManifest`.
- `compiledModules`: modules present in the product build.
- `lifecycleManifests`: module lifecycle contracts available to the build.
- `enabledFeatureFlags`: runtime feature flags active for the build/profile.

## Validation Rules

`ProductCompositionPolicy` composes the profile and lifecycle validators and
adds build/runtime checks for:

- invalid product profile manifests
- duplicate lifecycle manifests for the same module
- profile-included modules missing from the compiled build
- profile-excluded modules compiled into the build
- profile-included modules missing a lifecycle manifest
- lifecycle manifests rejected by the active profile
- lifecycle manifests supplied for modules absent from the compiled build
- fallback modules absent from the compiled build
- runtime feature flags with no lifecycle owner
- runtime feature flags whose owning module is absent from the compiled build or
  inactive in the product profile

Accepted results contain only `accepted`. Rejected results expose stable
composition codes plus profile-level and module-level validation maps.

## Default Airo TV Compositions

The package ships default compositions for:

- `AiroTvProductCompositions.fullTv()`
- `AiroTvProductCompositions.liteReceiver()`

Full TV compiles the modules in the default Full TV profile and enables Full
EPG, diagnostics, and analytics flags. Lite Receiver compiles only the default
Lite Receiver modules and enables diagnostics only.

## Airo TV Consumption Rule

Airo TV should evaluate the product composition before exposing navigation,
remote-control routes, handoff flows, diagnostics panels, or background module
startup. If composition validation rejects a profile/module/flag combination,
the app should treat that module as unavailable rather than falling back to
screen-local conditionals.

## Public Serialization

`toPublicMap()` exposes stable profile, module, lifecycle, and feature-flag IDs.
Validation maps expose stable rejection codes. Public maps do not include local
filesystem paths, provider payloads, store-console account data, or raw
credential material.
