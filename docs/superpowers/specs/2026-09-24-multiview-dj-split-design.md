# Spec: MultiView DJ split (5/50/95, premium handle, equal-power mix)

## Objective

Two-pane MultiView's 30/50/70 magnetic split works, but the extremes are
timid, the full-height grey slab reads cheap, and audio still follows the
featured tile instead of the bar.

**User:** someone in two-pane split (phone, tablet, or Android TV) who
wants a DJ-style crossfader: grow one picture toward a peek strip, shrink
the other, and hear the mix move with the bar. Global / system volume
does not change.

**Success:** the seam still snaps, looks like a hairline, and is legal on
touch and ten-foot. Dragging it crossfades the two streams with constant
power. A 5% pane is a peek strip on TV and never thinner than a
glanceable strip on a phone.

## Scope

In scope:

- `splitHorizontal` and `splitVertical` only.
- Stops **five / fifty / ninetyFive**. First pane share 5 / 50 / 95 of
  the *split axis after the handle*, then clamped by the min-pane floor.
- Touch: live drag preview, snap on pointer-up. No tap-to-snap.
- TV: focused handle, Left/Right (or Up/Down if stacked) steps the three
  stops. No wrap at the extreme.
- Equal-power mix tied to the live fraction. Global volume is a
  multiplier, not a second fader.
- Premium short handle: fat hit, thin paint.
- Two-pane focus/promote does **not** reset the mix to 100/0.
- Reset mix + ratio when the mosaic leaves two-pane.

Out of scope:

- Triple, quad, spotlight.
- Cast protocol.
- Persist across process death.
- On-screen 5 / 50 / 95 chips.
- Play `versionCode` bump.

This supersedes the 30/70 clamp, full-height painted slab, and
"audio follows featured tile" rules in
`docs/superpowers/specs/2026-09-23-multiview-split-resize-design.md`
for two-pane only. Everything else in that spec stays.

## Platform fitting (do not break device rules)

Use **constraints**, not a device-name check (`LayoutBuilder` on the
stage). Compact = either axis of the split host `< 600` (same mobile
breakpoint as `docs/ui/RESPONSIVE_STANDARDS.md`).

| Surface | Hit target (cross-axis of the seam) | Paint | Min pane |
|---|---|---|---|
| Compact (phone, small window) | **48dp** full seam (Material 48 / HIG 44) | 2dp hairline + 8×28dp capsule, middle third only | **80dp** |
| Regular (tablet landscape, TV, desktop) | **24dp** full seam | same paint, 1.05 scale + 8dp glow on focus | **80dp** |

80dp on a 1920px TV is 4.2%, so the 5% stop wins. 80dp on a 360px phone
is 22%, so `five` becomes "as small as allowed", not a 18px sliver.
Never persist a fraction that would paint a pane below 80dp on the
current extent.

Other non-negotiables:

- Hit sliver is the full seam. The user does not have to hit the capsule.
- Hairline + capsule are always visible at low contrast. No hover-only.
- `autofocus: false`. Handle is not focused on open.
- Select/OK on the handle is still a no-op.
- Flutter `kTouchSlop` (~18px): a tap is not a drag. Tests use ≥24px.
- Overscan: handle sits on the center seam, not the screen edge.
- Panes stay `Expanded` / flex. No fixed pixel pane widths.
- Both `buildView()` surfaces stay mounted. No decoder reopen on mix.

## Stops

Rename `MultiviewSplitRatio.thirty` → `five`, `seventy` → `ninetyFive`.

Nominal first-pane fractions: `0.05`, `0.50`, `0.95`. Flex in
thousandths so 5% is exact: `50/950`, `1/1`, `950/50`.

```
effectiveMin(extent) = max(0.05, 80 / extent)
effectiveMax(extent) = 1 - effectiveMin(extent)
```

`five` paints `effectiveMin`, `ninetyFive` paints `effectiveMax`. Snap
and D-pad step those three **effective** positions. Tie still prefers
`fifty`. Step at an extreme returns null so focus can leave the handle.

## DJ mix

Map the live first-pane fraction `f` through the effective range to
`t ∈ [0, 1]`:

```
t = (f - effectiveMin) / (effectiveMax - effectiveMin)
firstGain  = sqrt(t) * globalVolume
secondGain = sqrt(1 - t) * globalVolume
```

`globalVolume` is the Watch / primary volume captured when MultiView
opened (already held as `_primaryVolumeHeldForMultiview`), clamped
`[0, 1]`. System volume is untouched.

Apply on every drag frame (coalesce to one `setVolume` pair per frame via
`SchedulerBinding.scheduleFrameCallback`). Apply on snap and on D-pad
step. At `five`, first is silent; at `ninetyFive`, second is silent; at
`fifty` each is ~0.707 so power stays ~1.

Two-pane `promote` (focus or tap) still updates featured chrome and OK-
swap pairing. It must **not** call pool `_routeAudio` (which forces 1/0).
OK-swap reorders panes; the mix follows **pane order** (left/top is
always `firstGain`), not channel id. After any pool add/remove/swap that
**stays** two-pane, re-apply the current mix. Leaving two-pane restores
exclusive featured routing and resets `splitRatio` to `fifty`.

Per-tile volume slider in the tile menu is hidden while two-pane (it
fights the bar). Audio-track and subtitle pickers stay.

## Handle chrome

Replace the 24dp `Colors.white24` full-bleed `ColoredBox`.

- Outer: transparent `SizedBox` of the hit size above, `HitTestBehavior.opaque`.
- Inner, centered on the long axis, limited to the middle **third**:
  2dp hairline `white` at 28% opacity, plus an 8×28dp stadium grip at
  55% opacity.
- Focused (`TvFocusable`): grip 80% opacity, 8dp white glow, scale 1.05.
  Unfocused: no glow.
- Key stays `ValueKey('multiview-split-handle')`. Label "Resize split".

## Tests

1. Enum flex is 50/950, 1/1, 950/50. Snap on a 1600px axis uses 5/50/95.
   Snap on a 360px axis uses `80/360` as `five`, not 0.05.
2. `clamp` never returns a pane below 80dp for the given extent.
3. Equal-power: `t=0` → (0, global), `t=1` → (global, 0), `t=0.5` → both
   `sqrt(0.5)*global` ±0.01.
4. Compact 360×640 host: handle cross-axis is 48. 1920×1080 host: 24.
5. Drag still snaps; tap does not. D-pad five → fifty → ninetyFive, no wrap.
6. Two-pane `promote` does not set the other tile to 0 while a mix is
   active. Adding a third session restores 1/0 on featured.
7. Tile menu has no `multiview-volume-*` slider in two-pane; slider still
   exists for triple.

No Play `versionCode` bump in this change.
