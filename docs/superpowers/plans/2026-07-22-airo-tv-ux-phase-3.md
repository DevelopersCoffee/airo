# Airo TV UX Phase 3 — Remote Overlay Plan

> Issue #1039. Base: `origin/main` at `d46dbade`.

1. Write failing pure-unit tests for random selection from the filtered list,
   including empty and single-item inputs; implement the deterministic helper.
2. Reuse the player's existing auto-hiding compact and expanded control layers
   for volume, mute, and channel navigation. Do not mount a second full-screen
   overlay over those controls.
3. Write remote-input tests using existing TV focus/key patterns and map
   hardware channel up/down to established filtered-list navigation.
4. Add one focusable random action to both existing player control layouts.
   Hardware volume and mute remain platform/OS-owned because `TvInputKey`
   does not expose those keys.
5. Run focused tests per slice, full feature-package tests/analyzer, review,
   and device dogfood before opening the PR.
