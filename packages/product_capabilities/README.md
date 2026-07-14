# Product Capabilities

Shared product-profile and runtime-capability contracts for Airo V2 products.

This package is platform/framework code. Airo TV and future product surfaces
consume these models to decide which modules, navigation entries, permissions,
and capabilities are available for a product profile.

## Scope

- Stable product profile identifiers.
- Product module, navigation, permission, guarantee, release-channel, and
  capability declarations.
- Runtime device capability snapshots.
- Deterministic requirement evaluation with machine-readable blocker codes.
- Deterministic product manifest validation for module overlap, unsupported
  navigation, unsupported capabilities, permission minimization, budgets, and
  release-channel compatibility.

This package does not render UI, import vendor SDKs, or start playback.
