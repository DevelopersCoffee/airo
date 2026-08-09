# Spec: Split view — cast one channel, watch another locally (#1047)

## Objective

Today, once a Chromecast device is connected, `IptvScreen._playChannel`
(`packages/feature_iptv/lib/presentation/screens/iptv_screen.dart:426-443`)
routes every channel selection to the cast target, and
`_syncLocalPlaybackWithCast` (same file, lines 760-774 and 1330-1342)
explicitly pauses local playback for the duration of the cast session. This
is deliberate cast-replaces-local behavior, not an accidental gap.

#1047 asks for the opposite in one specific case: cast channel A to the TV,
keep browsing/watching a *different* channel B locally on the phone/tablet.

**User:** someone with a Chromecast-connected TV who wants the TV playing one
channel (e.g. a game) while browsing or watching something else on their
phone.

**Success:** a user can select a channel for a connected cast target, then
independently pick a different channel to play in the local player, without
either playback stream interrupting the other, and without exceeding what
the device can actually decode concurrently.

## Scope

In scope:
- Decoupling channel selection so "cast target's channel" and "local
  player's channel" are independent pieces of state.
- Removing the unconditional pause in `_syncLocalPlaybackWithCast` for this
  case (local playback should only pause if the user explicitly wants that,
  not because a cast session exists).
- A resource-guard check before allowing a second concurrent local stream
  while casting — reusing whatever comes out of the #829 admission-control
  follow-up (see Dependencies below). If that isn't ready yet, this feature
  should not ship without *some* bound, even a conservative static one.

Out of scope for this spec:
- Mirror mode (#1048) — genuinely different problem (bidirectional sync
  between two players showing the *same* channel, not two independent
  channels).
- Any UI visual design (layout of the split view, phone).
- AirPlay or DLNA — this spec covers the existing `AiroCastController`
  (Chromecast) integration only; other cast protocols are a separate
  question if/when they're added.

## Dependencies (blocking, not yet resolved)

1. **#829's admission-control gap.** There is currently no API anywhere in
   `platform_player`/`platform_media` that answers "can this device sustain
   one more concurrent decoder." Casting already occupies the cast
   receiver's decoder; adding an independent local stream is a second
   concurrent local decoder for *this* device (encoding to the cast target
   is remote — the network stream to the TV — but the local stream still
   costs a local decoder + network fetch). Shipping #1047 without an
   admission-control answer risks the same silent quality degradation #829's
   Non-Goals warn about, just via a different combination (cast + local
   instead of N local tiles).
2. **Product sign-off.** Is "cast A + watch B" valuable enough to justify
   the concurrent-decoder cost and added UI complexity (now two "now
   playing" surfaces to manage, including e.g. audio routing — should local
   playback be muted by default so the user isn't hearing two streams'
   audio at once)? Not an engineering call.

## Design (once dependencies clear)

### State
Split `IptvCastState`'s implicit "the app has one now-playing channel" model
into two independent pieces:
- `castState.playingChannel` (already exists via `activeDevice`'s session).
- `localPlayer` channel — currently implicit in
  `iptvStreamingServiceProvider`'s state; needs no new model, just needs to
  stop being paused by `_syncLocalPlaybackWithCast`.

### Changes
1. `_playChannel`: only route to cast when the user explicitly taps
   "cast this channel" (e.g. from a cast-specific action), not for every
   channel tap while a cast session is active. Plain channel taps should
   always target the local player.
2. `_syncLocalPlaybackWithCast`: remove the unconditional
   `streaming.pause()` on `isCasting` becoming true. Local pause should be a
   user action (existing pause button), not a side effect of casting
   starting.
3. Before allowing a channel to start locally while `isCasting` is true,
   query the admission-control API from the #829 follow-up. If it says no
   (or the API doesn't exist yet — fail closed), show the existing "can't
   play more streams right now" pattern already established for multiview
   tile capacity (`AiroMultiviewAddResult.capacityReached`,
   `packages/platform_player/lib/src/services/airo_multiview_pool.dart:61-63`)
   rather than degrading silently.
4. Audio: default local playback to muted while a cast session is active,
   with an explicit user toggle to unmute (mirrors the existing per-tile
   audio-focus pattern in multiview — only one loud source at a time by
   default).

### Testing
- Widget test: selecting a channel while `activeDevice != null` no longer
  calls `castChannelToActiveDevice` (updated exclusivity assertion,
  inverting today's `_playChannel` test if one exists — check
  `iptv_screen_test.dart` for the current cast-routing assertion first).
- Widget test: `isCasting` flipping true no longer calls
  `streaming.pause()` unconditionally.
- Integration-style test: admission-control rejection while casting shows
  the capacity-reached UI instead of starting a second stream.

## Explicitly not decided here

Whether the admission-control API happens as a new predictive
capability-check (querying `AiroRuntimeDeviceProfile`) or a conservative
static cap (e.g. "never allow local playback while casting on
low/mid-tier devices") is the #829 follow-up's call, not this spec's. This
spec assumes *some* answer exists before implementation starts.
