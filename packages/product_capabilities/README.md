# Product Capabilities

Shared product-profile and runtime-capability contracts for Airo V2 products.

This package is platform/framework code. Airo TV and future product surfaces
consume these models to decide which modules, navigation entries, permissions,
and capabilities are available for a product profile.

## Scope

- Stable product profile identifiers.
- Product module, navigation, permission, guarantee, release-channel, and
  capability declarations.
- Product module lifecycle manifests for dependencies, supported profiles,
  initialization cost, memory/storage budgets, background jobs, fallback modules,
  and feature flags.
- Product composition manifests that bind product profiles, compiled modules,
  lifecycle manifests, and runtime feature flags.
- Release-channel and store-listing strategy manifests for single adaptive
  app, full/lite split, targeted delivery, vendor-specific, and internal
  certification paths.
- Cross-profile compatibility suite manifests for handoff, receiver-only
  playback, protocol version pairs, companion-unavailable fallback, unsupported
  transfers, delegation failures, and sync continuity.
- Profile-aware capability advertisements that publish runtime-safe
  capabilities, compiled modules, profile guarantees, and unsupported reasons.
- Profile navigation manifests that bind routes, display keys, render tiers,
  modules, and capabilities to active product profiles.
- Runtime device capability snapshots.
- Deterministic requirement evaluation with machine-readable blocker codes.
- Deterministic product manifest validation for module overlap, unsupported
  navigation, unsupported capabilities, permission minimization, budgets, and
  release-channel compatibility.
- Deterministic lifecycle validation for profile compatibility, dependencies,
  module availability, permissions, resource budgets, background shutdown, and
  fallback safety.
- Deterministic composition validation for invalid profile manifests, absent
  compiled modules, excluded compiled modules, missing lifecycle manifests, and
  runtime flags that point at unavailable modules.
- Deterministic release listing validation for profile/channel compatibility,
  required evidence, rollout posture, crash thresholds, shared account
  entitlements, protocol compatibility, dependency isolation, targeted delivery
  evidence, legal review, and non-general-store channels.
- Deterministic cross-profile suite validation for scenario identity, source
  and target profiles, required assertions, automation tags, protocol versions,
  safe failure behavior, shared account continuity, session identity,
  companion fallback, and privacy assertions.
- Deterministic capability advertisement policy that prevents controllers,
  routers, and handoff flows from seeing capabilities blocked by profile,
  composition, lifecycle, or runtime device requirements.
- Deterministic navigation validation that prevents unavailable routes, empty
  sections, unsupported render tiers, and routes backed by absent modules from
  reaching product UI.

This package does not render UI, import vendor SDKs, or start playback.
