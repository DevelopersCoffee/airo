# Airo TV Legacy UI And Focus Performance Budget

This contract defines the v2.0.0.1 platform budget for legacy Airo TV UI,
remote focus behavior, artwork loading, and rebuild boundaries.

Implementation contract:

- Package: `packages/core_ui`
- Policy: `AiroAdaptiveUiPolicy.resolveLegacyPerformanceBudget`
- Input: `AiroAdaptiveUiInput`
- Output: `AiroLegacyUiPerformanceBudget`

## Ownership Boundary

Legacy UI performance budgets are platform/framework behavior. Airo TV app code
may consume the budget to configure focus wrappers, channel grids, poster
loading, animation durations, and selector/rebuild boundaries. It must not
hard-code focus latency, blur, parallax, artwork cache, or D-pad thresholds in
product screens.

## Budget Rules

Lite Receiver and constrained receiver profiles require:

- focus response target at or below 100ms;
- bounded focus animation at or below 80ms;
- focus restoration after playback, dialogs, and navigation returns;
- stable keys for focusable list/grid items;
- selector-scoped rebuilds instead of full-screen rebuilds during focus moves;
- long-list virtualization;
- artwork loading isolation with small cache and low prefetch count;
- disabled autoplay previews, blur-heavy effects, parallax, and shader-heavy
  effects.

Standard TV keeps a larger artwork and poster budget but still requires D-pad
focus persistence and bounded focus animation. Companion touch/pointer modes do
not require D-pad restoration budgets.

## QA Use Cases

- Rapid D-pad input while thumbnails load keeps focus stable.
- Focus restores after playback and modal/dialog dismissal.
- Artwork updates do not rebuild the whole screen.
- Accessibility reduce-motion disables focus animation.
- Public budget maps expose stable rule ids and numeric thresholds only, not
  widget tree dumps, screenshots, local paths, or device identifiers.
