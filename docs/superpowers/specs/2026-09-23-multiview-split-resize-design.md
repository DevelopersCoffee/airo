# Spec: MultiView two-pane magnetic split

## Objective

Two-pane MultiView always splits 50/50. In fullscreen split the user wants
both streams playing, but to grow the one they are watching and shrink the
other without dropping it.

**User:** someone on Aika Stream (phone, tablet, or Android TV) with two
channels in split view who wants more picture on one stream and a still-
watchable strip on the other.

**Success:** a single seam handle resizes the two panes. Touch drag follows
the finger and snaps to 30 / 50 / 70 on release. D-pad on the focused handle
jumps those same three stops. Both videos keep decoding. Audio still follows
the featured tile, not the larger pane.

## Scope

In scope:

- `MultiviewLayoutKind.splitHorizontal` (side-by-side) and
  `splitVertical` (stacked) only.
- Discrete first-pane shares **30, 50, 70**. There is no free-size persist.
- Touch: live drag preview, snap on pointer-up to the nearest stop.
- Clamp: neither pane may go below 30% during drag or after snap.
- TV: handle is in the D-pad path; Left/Right (horizontal) or Up/Down
  (vertical) steps 30 → 50 → 70. At the 30% end, a press toward the small
  pane moves focus onto that tile instead of a no-op.
- Reset to 50 when the resolved layout is no longer two-pane (third
  channel, mosaic change, last tile closed), including if a drag is in
  progress.
- Ratio is session-local. It is not written to disk and does not survive
  process death.

Out of scope:

- Triple, quad, and spotlight mosaics.
- Cast MultiView protocol (`multiview.set_layout` and friends). Phone-as-
  remote does not resize a TV split in this change.
- Reopening or swapping decoders when the ratio changes.
- Changing which tile is audible based on which pane is larger.
- Persist across app restarts.
- Extra on-screen 30 / 50 / 70 chips. The stops are the snap points and
  D-pad steps, not a second control.

## Current behavior

`MultiviewStage` (`packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart`)
renders two-pane layouts as equal `Expanded` children. `MultiviewState`
stores sessions, featured id, capacity, and preferred mosaic — no split
ratio. Tile `TvFocusable` on-focus already promotes (audio). Select on a
non-featured tile swaps with featured.

## Design

### Stops

`MultiviewSplitRatio` is an enum with three values: `thirty`, `fifty`,
`seventy`. Each is the first pane's share (left in `splitHorizontal`, top
in `splitVertical`). Flex mapping:

| Stop    | First pane | Second pane |
|---------|------------|-------------|
| thirty  | 3          | 7           |
| fifty   | 1          | 1           |
| seventy | 7          | 3           |

Default is `fifty`. Tie on snap (exactly halfway between two stops) prefers
`fifty`.

### State

Add `splitRatio` to `MultiviewState`, default `fifty`.
`MultiviewController.setSplitRatio` is the only writer besides resets.

Reset to `fifty` inside `setLayout` when the new preferred mosaic is not
two-pane, and inside `_syncFromPool` when `resolveMultiviewLayout` for the
new session count is not `splitHorizontal` or `splitVertical`. Closing
MultiView drops the state with the controller; the next session starts at
50.

Do not send ratio over Cast. Do not add a field to
`MultiviewLayoutKind`.

### Stage

When the resolved kind is two-pane, insert a handle between the two cells.

- **Painted ratio:** if a pointer drag is active, use the live fraction
  (clamped to `[0.30, 0.70]`). Otherwise use the enum.
- **Handle:** thin visible seam, larger touch hit target (at least 24dp).
  Focused state is a glow/outline, same language as other `TvFocusable`
  chrome. Semantic label: "Resize split".
- **Touch:** horizontal drag on side-by-side, vertical drag on stacked.
  Preview updates every move. On pointer-up, snap to nearest stop and call
  `setSplitRatio`. Cancel (pointer cancel, layout change) discards the
  preview and keeps or resets per the reset rules.
- **TV:** handle is a `TvFocusable` between the two tiles (left → handle →
  right, or top → handle → bottom). It must not `autofocus`. It must not
  call `onPromote`. Select / OK on the handle is a no-op (does not swap or
  dismiss). Arrow along the split axis steps the enum. At an extreme stop
  (thirty or seventy), a further arrow toward the already-small pane moves
  focus onto that tile instead of wrapping. Arrow off the handle onto a
  tile uses normal traversal.
- **Players:** both `buildView()` surfaces stay mounted. Flex change only.

Audio: featured tile still owns volume. Resizing does not promote.

### Focus theft

The handle must not take primary focus on stage open. Traversal is opt-in:
the user arrows onto it from a tile. This is the same class of bug as the
fullscreen Back node stealing D-pad from the transport bar on Bravia.

## Error handling

- Invalid or unknown stored ratio (should not happen with an enum) →
  `fifty`.
- Drag while session count changes to 1 or ≥3 → drop preview, reset
  `fifty`, hide handle.
- Handle focused when mosaic switches off two-pane → handle unmounts;
  focus returns to the remaining featured tile.

## Tests

1. `MultiviewController.setSplitRatio` accepts only the three stops;
   default is fifty.
2. Adding a third session or `setLayout` to triple/quad/spotlight resets
   to fifty.
3. Leaving two-pane then returning to two-pane starts at fifty (not the
   previous 70).
4. `MultiviewStage` two-pane: handle is present; flex 3/7 vs 1/1 vs 7/3
   matches the stop. Triple/quad/spotlight: no handle.
5. Widget drag on a 640×360 split: release near 30% commits thirty; release
   near center commits fifty.
6. Focused handle: Right from fifty → seventy; further Right toward the
   now-small right pane moves focus to that tile (does not wrap to thirty).
7. Select on the handle does not call `onSwap` / `onPromote`.
8. Handle is not focused after the initial pump (no autofocus).

No physical-device decoder test for this change: players are not reopened.

## Non-goals reminder

Do not bump Play `versionCode` in this spec. Shipping on Play is a later
cut after the feature lands.
