# Airo TV Module Lifecycle Manifest Schema

ATV-060 defines the reusable platform contract that describes whether a product
module can be started for a given Airo TV product profile.

The schema lives in `packages/product_capabilities` so Airo TV app code can
consume a stable platform boundary instead of hard-coding reusable lifecycle,
budget, permission, dependency, fallback, or feature-flag rules.

## Ownership

- Framework owns `ProductModuleLifecycleManifest`, stable IDs, lifecycle
  budgets, and validation codes.
- DevEx owns deterministic validation output for tooling and release checks.
- Release owns profile/channel compatibility and feature-flag gates.
- QA owns automation that validates dependencies, budgets, permissions,
  background work, fallbacks, and supported profiles.
- Airo TV app code consumes the accepted manifests and keeps only product
  journeys, screen composition, copy, and profile-specific workflow logic.

## Manifest Fields

`ProductModuleLifecycleManifest` includes:

- `schemaVersion`: schema version shared with product capability contracts.
- `module`: stable `ProductModule` ID.
- `displayName`: human-readable module name.
- `supportedProfiles`: product profiles where the module may run.
- `dependencies`: other modules that must be included in the active profile.
- `requiredCapabilities`: capabilities the active profile must advertise.
- `androidPermissions`: permissions already allowed by the active profile.
- `budget`: initialization cost, memory budget, storage budget, and background
  job budget.
- `backgroundTasks`: declared background work such as EPG refresh or model
  warmup.
- `featureFlags`: release/build flags required by optional or heavy modules.
- `fallbackModule`: module to use when this module is unavailable.
- `allowsBackgroundExecution`: whether declared background work may run.
- `supportsGracefulShutdown`: whether the module can stop cleanly on profile,
  lifecycle, or resource changes.

## Validation

`ProductModuleLifecyclePolicy` returns stable validation codes for:

- unsupported product profile
- module unavailable in the active profile manifest
- missing dependency module
- unsupported required capability
- permission not present in the active profile manifest
- invalid lifecycle budget
- initialization cost above the profile threshold
- memory budget above the profile budget
- storage budget above the profile budget
- background-job budget above the profile budget
- background work without safe shutdown support
- fallback pointing to itself or to an unavailable module
- missing feature flag for optional or heavy modules

Accepted results contain only `accepted`.

## Default Airo TV Manifests

The package ships default lifecycle manifests for the first composition layer:

- `playback`: Full TV, Standard TV, Lite Receiver, and Embedded Receiver.
- `compactEpg`: all TV and receiver profiles with bounded EPG refresh.
- `fullEpg`: Full TV and Standard TV only, falling back to Compact EPG.
- `localAi`: Full TV only, falling back to Basic Search.

Later module issues should add lifecycle manifests for recording, downloads,
multiview, diagnostics, analytics, cloud sync, phone remote, and any vendor
adapter modules before app-layer composition starts them.

## Airo TV Consumption Rule

Airo TV should compose screens and workflows from modules whose lifecycle
manifest validates against the active `ProductProfileManifest`. App code should
not start modules directly when the platform policy reports an unsupported
profile, missing dependency, exceeded budget, permission mismatch, unsafe
background lifecycle, invalid fallback, or missing feature flag.

## Public Serialization

`toPublicMap()` exposes only stable IDs, booleans, and numeric budgets. It does
not include local filesystem paths, provider payloads, store-console account
data, or raw credential material.
