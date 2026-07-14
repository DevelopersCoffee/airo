# Core UI

Design-system contracts, theme primitives, adaptive mode policy, and shared widgets
for Airo products.

This package is platform/framework code. Airo TV, mobile companion, tablet,
desktop, IPTV, and future profile-specific surfaces consume these contracts
instead of defining separate input-mode, density, typography, focus, and
accessibility behavior in product screens.

## Scope

- Theme definitions and design primitives.
- Shared UI widgets.
- Adaptive UI mode inputs and resolver policy.
- Stable interaction, density, typography, focus, artwork, motion, navigation,
  and target-size outputs.

This package does not implement runtime platform detection, rewrite product
screens, define product navigation manifests, run device certification, or ship
golden-test assets.
