# Airo TV Release Channel and Store Listing Strategy

ATV-067 defines the platform contract for mapping Airo TV product profiles to
release channels and store-listing strategies.

The reusable contract lives in `packages/product_capabilities` because release
channels, profile IDs, permissions, module sets, device eligibility, dependency
isolation, rollout posture, and public capability metadata are shared platform
concerns. Airo TV app code should consume these manifests and keep only product
journeys, copy, navigation, and workflow decisions.

## Ownership

- Release owns channel eligibility, rollout percentage, crash threshold, and
  internal certification posture.
- Product owns listing strategy selection and profile-to-listing mapping.
- Legal owns store-policy, data-safety, content-rating, legal-review, and
  vendor/operator evidence requirements.
- Framework owns stable models, validation codes, and public serialization.
- QA owns deterministic fixtures for accepted and rejected listing strategies.

## Strategies

`ProductStoreListingStrategy` covers:

- single adaptive application
- split Full/Lite applications
- targeted delivery
- vendor-specific distribution
- internal certification

## Validation

`ProductStoreListingStrategyPolicy` validates:

- every strategy has profile/channel mappings and listing IDs
- each profile is mapped to a compatible `ProductReleaseChannel`
- required release/legal/product evidence is present
- rollout percentages are valid for publishable listings
- crash-free session thresholds are inside the accepted range
- shared account entitlements and protocol compatibility are preserved
- Lite/Embedded or targeted paths declare dependency isolation
- targeted delivery declares device-catalog and feature-delivery evidence
- general store listings include legal review
- vendor-specific and internal-certification paths do not claim broad general
  store publishability

Accepted manifests return only `accepted`.

## Default Airo TV Manifests

The package ships defaults for:

- `AiroTvReleaseListingStrategies.singleAdaptiveApplication()`
- `AiroTvReleaseListingStrategies.splitFullLiteApplications()`
- `AiroTvReleaseListingStrategies.targetedDelivery()`
- `AiroTvReleaseListingStrategies.vendorSpecificReceiver()`
- `AiroTvReleaseListingStrategies.internalCertification()`

Full TV and Standard TV map to `full_tv_stable`. Lite Receiver maps to
`lite_receiver_stable`. Embedded Receiver maps to `receiver_stable` unless the
path is vendor-specific or internal certification.

## Airo TV Consumption Rule

Airo TV must evaluate a store-listing strategy before enabling release
automation, profile-specific package decisions, or store-readiness claims.
Actual store-console submissions, listing copy, screenshots, rollout controls,
and vendor account operations remain release/legal artifacts outside this
platform contract.

## Public Serialization

`toPublicMap()` exposes stable strategy IDs, listing IDs, profile/channel
mappings, required and provided evidence IDs, rollout percentage, crash
threshold, dependency-isolation flags, shared-account flags, and general-store
publishability. It does not expose store-console account data, credentials,
provider payloads, local filesystem paths, media URLs, or release operator
notes.
