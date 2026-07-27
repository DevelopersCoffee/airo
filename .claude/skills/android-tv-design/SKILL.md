---
name: android-tv-design
description: Use when building or reviewing leanback TV UI — Android TV, Google TV, or Fire TV apps — including D-pad navigation, focus states, TV screen layouts/grids, TV component design (buttons, cards, carousels, nav drawers, tabs, lists), TV color/typography, or TV app icons and banners.
---

# Android TV / 10-Foot Design

Reference: developer.android.com/design/ui/tv (Material 3 for TV). Applies to any leanback (10-foot) interface — Android TV, Google TV, or a Fire TV app adapting these conventions.

## Overview

TV is viewed from ~3m (10 feet), navigated only by D-pad (no touch), and is a shared/communal device. These three constraints drive every design decision: large glanceable content, instant/distinct focus feedback on every interactive element, and privacy-aware defaults for personal info.

## When to use

- Designing or coding a new TV screen, row, or grid.
- Reviewing TV UI for D-pad reachability, focus indicators, or overscan-safety.
- Picking/sizing a TV component (button, card, carousel, nav drawer, list, tabs).
- Producing TV app icons/banners for AndroidManifest.xml.
- Not for mobile/web/touch UI — TV has no touch, no on-screen back button, and fixed 16:9.

## Core rules (apply to every screen)

1. **D-pad reachability** — every focusable element reachable via up/down/left/right, no dead ends. Vertical axis = categories/rows, horizontal axis = items within a row, unless there's a clear reason to deviate.
2. **Instant focus feedback** — every focusable element needs a visible state change (scale/glow/outline/color) the moment it gains focus. See `reference/foundations.md#focus-system`.
3. **No on-screen back button, no exit gating** — remote's hardware back handles it; back always lands on the previous destination, chain ends at Home. Only exception: a Cancel button on destructive/purchase/confirm-only screens.
4. **Overscan-safe margins** — keep primary content inside ~48dp (sides) / ~27dp (top/bottom) on a 960x540 canvas; backgrounds may bleed full-screen.
5. **Panels ≤ 2** — single-pane for content-forward screens, two-pane for hierarchical/task screens. More causes cognitive overload.
6. **Dark theme by default** — cinematic feel, lower TV power draw. Design/test color in sRGB + Standard picture mode.
7. **10ft legibility** — large text, high contrast, sentence-case labels, no dense paragraphs.

## Quick reference

| Need | Go to |
|---|---|
| Navigation rules, focus states/indicators, color system, typography scale, app icon/banner specs | `reference/foundations.md` |
| Design canvas, grid, overscan margins, layout patterns/panels/templates, card-column widths | `reference/layout.md` |
| Component specs: buttons, cards, immersive list, nav drawer, featured carousel, lists, tabs | `reference/components.md` |

Key numbers to remember: canvas 960x540 (1px=1dp, MDPI), 16:9, 12-column grid (52dp cols / 20dp gutters), overscan margin ~48dp/~27dp, focus scale 1.05–1.1x.

## Common mistakes

| Mistake | Fix |
|---|---|
| Rendering a visible back button on screen | Remove it — remote back button already handles this |
| Gating back/exit behind a confirmation dialog | Only gate destructive/purchase/confirm screens, with a Cancel button |
| No visible focus state on a card/button | Add scale, glow, outline, or color shift — pick from `reference/foundations.md` |
| 3+ panels on one screen | Consolidate to single- or two-pane, group related content |
| Vivid/DCI-P3-tuned colors as the design baseline | Design/test in sRGB + Standard picture mode first |
| Icon-only in some nav items, text-only in others | Use one consistent style across all nav items |
| Long, multi-word body text on a Compact/Wide card | Trim to a few words or switch to Content Details template |
