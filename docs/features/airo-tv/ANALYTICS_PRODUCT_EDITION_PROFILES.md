# Analytics Product Edition Profiles

Issue: ATV-077
Package: `core_analytics`
Layer: Platform framework, consumed by Airo TV app and release code

## Purpose

Analytics product-edition profiles define which analytics purposes, event
families, event names, queue budgets, crash budgets, local retention windows,
provider posture, and local-only rules each product surface may use. Airo TV app
code selects a platform profile and submits typed events; it must not hard-code
event allowlists, upload posture, or reduced telemetry shortcuts in screens.

## Ownership

- Framework owns `AiroAnalyticsProductEditionProfile`, validation codes,
  default Airo TV profile fixtures, service-configuration derivation, and public
  serialization.
- Security and Privacy owns local-only restrictions, allowed-purpose reduction,
  external-upload blocking, consent intersection, and public-map redaction.
- QA owns profile validation tests for Full TV, Standard TV, Lite Receiver,
  Embedded Receiver, mobile companion, desktop companion, and malformed
  profiles.
- Airo TV app code owns runtime profile selection, settings UI copy, and
  user-visible workflow decisions that consume the selected platform profile.

## Profile Contract

`AiroAnalyticsProductEditionProfile` includes:

- `productProfile`: stable product profile id such as `full_tv` or
  `lite_receiver`.
- `allowedPurposes`: allowed analytics purposes after profile limits are
  applied.
- `eventFamilies`: stable product-edition event families.
- `eventNames`: analytics event names the product profile may submit.
- `providerKind`: no-op, local diagnostics, vendor adapter, or self-hosted.
- `maxQueueEvents`: bounded queue size for locally retained events.
- `maxCrashReports`: bounded local crash-diagnostics retention.
- `localRetentionDays`: maximum local retention window.
- `externalUploadAllowed`: whether provider upload can be attempted after
  consent and provider gates.
- `localOnly`: whether the profile must stay local-only regardless of requested
  runtime consent.

Public maps expose stable ids, event-family names, event names, booleans, and
numeric budgets only. They must not include media titles, URLs, local paths,
local IP addresses, credentials, device logs, store-console accounts, provider
payloads, or raw diagnostics.

## Default Airo TV Profiles

- Full TV: complete event set; operational, product, playback-quality,
  diagnostics, crash, and personalized purposes; vendor-adapter upload allowed
  when consent and provider gates allow it.
- Standard TV: Full TV without personalized analytics.
- Lite Receiver: reduced queue/crash budgets; operational, playback-quality,
  diagnostics, and crash purposes; no product-growth or personalized events.
- Embedded Receiver: local-only; operational and diagnostics only; local
  diagnostics provider; no external upload even if runtime consent asks for all
  analytics.
- Mobile Companion: companion/device ecosystem, delegation, diagnostics, crash,
  and product-growth events; no TV playback-quality event family.
- Desktop Companion: companion/device ecosystem, delegation, diagnostics,
  crash, and product-growth events; no TV playback-quality event family.

## Validation

`AiroAnalyticsProductEditionProfile.validate()` returns deterministic codes for:

- missing operational purpose;
- unsupported purposes in local-only profiles;
- event families whose purpose is not allowed by the profile;
- invalid queue, crash, or retention budgets;
- external upload enabled in local-only mode;
- external upload enabled without a provider.

`toServiceConfiguration()` intersects requested runtime consent with the profile
limits. Local-only profiles always produce local-only consent and block external
upload.

## Automation

- Unit tests assert Full TV validates and allows playback and product events.
- Unit tests assert Lite Receiver excludes personalized/product-growth events
  and uses smaller budgets than Full TV.
- Unit tests assert Embedded Receiver forces local-only configuration even when
  requested consent enables all analytics.
- Unit tests assert companion profiles allow device ecosystem events but exclude
  TV playback-quality events.
- Unit tests reject unsafe profile definitions with stable validation codes.
- Public-map tests verify stable output and absence of raw media, network,
  credential, provider, and local diagnostic material.

## Deferred Work

Runtime profile selection, settings UI, vendor dashboard mapping, remote-config
integration, and server-side gateway enforcement remain separate issues. This
issue defines the reusable platform contract that those features consume.
