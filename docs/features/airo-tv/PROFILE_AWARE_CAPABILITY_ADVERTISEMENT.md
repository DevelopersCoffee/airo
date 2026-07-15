# Airo TV Profile-Aware Capability Advertisement

ATV-062 defines the reusable platform publication model that tells controllers,
routers, handoff flows, and diagnostics which Airo TV capabilities are safe to
use for the active product profile, compiled build, and runtime device.

The contract lives in `packages/product_capabilities` because profile-aware
capability publication depends on product profiles, composition manifests,
module lifecycle manifests, runtime feature flags, and device requirements.
Transport adapters such as connected-node protocol advertisements can consume
this model without rebuilding profile rules in app code.

## Ownership

- Framework owns `ProductCapabilityAdvertisement`, unsupported reason codes, and
  public serialization.
- Media owns runtime media/device safety signals such as codec availability,
  decoder count, memory, and storage requirements.
- Security owns redaction and unsupported reason reporting without local paths,
  provider payloads, account data, raw credential material, or device logs.
- Release and DevEx own build-composition checks that prevent runtime flags from
  exposing modules absent from the compiled profile.
- Airo TV app code consumes the platform advertisement and should not construct
  profile-specific capability claims inside screens.

## Advertisement Fields

`ProductCapabilityAdvertisement` includes:

- `schemaVersion`: schema version shared with product capability contracts.
- `profileId`: active product profile.
- `supportLevel`: certified, compatible, experimental, or unsupported.
- `releaseChannel`: release channel for the profile.
- `compiledModules`: modules present in the compiled product build.
- `runtimeSafeCapabilities`: capabilities safe to advertise at runtime.
- `guarantees`: profile guarantees such as BYOC-only behavior and permission
  minimization.
- `enabledFeatureFlags`: runtime feature flags active for the composition.
- `unsupportedReasons`: stable explanations for unavailable capabilities or
  unsafe publication.
- `compositionAccepted`: whether product composition validation passed.
- `deviceSupported`: whether runtime device requirements passed.

## Unsupported Reasons

`ProductCapabilityUnsupportedReasonCode` reports:

- `profile_capability_absent`: the product profile does not support the
  capability.
- `composition_invalid`: the composition validator rejected the profile, build,
  lifecycle, fallback, or runtime flag state.
- `device_requirement_blocked`: the runtime device snapshot failed a capability
  requirement such as API level, memory, storage, decoder count, codec, DPAD, or
  secure storage.
- `module_unavailable`: the capability requires a module absent from the active
  profile or compiled build.
- `lifecycle_invalid`: the capability requires a module whose lifecycle
  manifest failed profile validation.

Unsupported reasons may include stable capability IDs, module IDs, device
blocker IDs, composition validation codes, and lifecycle validation codes.

## Publication Policy

`ProductCapabilityAdvertisementPolicy.publish()` evaluates:

1. `ProductCompositionManifest.validate()`
2. `ProductProfileManifest.evaluateDevice()`
3. profile capability support
4. compiled module presence
5. lifecycle validation for the module backing each capability

Runtime-safe capabilities are published only when the device is supported, the
profile manifest is valid, the capability is present in the profile, the backing
module is included and compiled, and the module lifecycle is valid for the
profile.

## Default Airo TV Advertisements

The package ships helpers for:

- `AiroTvCapabilityAdvertisements.fullTv(deviceSnapshot)`
- `AiroTvCapabilityAdvertisements.liteReceiver(deviceSnapshot)`

Full TV can publish Full EPG and analytics when the composition and runtime
device pass. Lite Receiver publishes compact receiver capabilities and reports
stable unsupported reasons for heavy features such as Full EPG, local AI,
recording, downloads, and multiview.

## Airo TV Consumption Rule

Airo TV should use the platform advertisement before exposing remote-control
commands, handoff options, guide/search sections, diagnostics panels, or
controller UX. If a capability is absent from `runtimeSafeCapabilities`, app
code should use the unsupported reason instead of screen-local conditionals.

## Public Serialization

`toPublicMap()` exposes stable IDs, booleans, and validation codes. It does not
include local filesystem paths, provider payloads, store-console account data,
raw credential material, or device logs.
