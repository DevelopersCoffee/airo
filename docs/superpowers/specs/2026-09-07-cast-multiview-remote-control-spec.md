# Spec: Cast MultiView — phone as a remote control for a TV-side grid

No GH issue yet — this scopes a user-pasted reference screenshot ("Multiview"
app: pick a layout, tap, it's on your TV; phone then shows per-stream
play/pause/mute/remove and Save/Move) against what Airo actually has today,
so a real issue can be filed with real constraints instead of a copied
feature list.

## Objective

Today, MultiView (`AiroMultiviewPool` / `MultiviewProvider` /
`MultiviewStage`) is a **local-only** grid: it renders on whichever device
runs it, driven by taps/D-pad on that same device. There is no path from
"phone picks channels" to "TV shows the grid" at all — Airo's existing Cast
integration (`AiroCastController`, `packages/platform_player/third_party/flutter_chrome_cast`)
only ever casts one channel to one receiver.

This spec is for the gap: **use a phone as a dedicated remote for a MultiView
grid actually running on the TV**, instead of only being able to build that
grid by sitting in front of the TV with its own remote.

**User:** someone with Aika Stream already running on their TV who wants to
build/rearrange/save a channel grid from their phone's couch, and control
each tile (pause, mute, remove) from the phone once the TV is showing it —
matching the reference screenshots' "Effortless Control" / "Tap, and it's on
your TV" promise.

**Success:** phone shows "TV Connected" once paired, tapping a layout on
the phone makes the TV's MultiView grid match it, and per-tile phone
controls (focus/mute, pause, remove) update the TV live.

## Reality check against the current codebase (why this isn't a quick add)

- **Airo has no Cast *receiver* of any kind today.** `flutter_chrome_cast`
  (bundled third-party) is sender-only — `AiroCastController` casts a
  channel URL to a generic Chromecast/Google-Cast-enabled TV's *built-in*
  receiver (media playback), the same way any app does. There is no code
  anywhere that makes an Airo app *receive* a cast session.
  `platform_receiver_modes` is unrelated — "receiver" there means a
  low-end/legacy *device tier* (see its `ProductModule.multiview` gate in
  `legacy_receiver_mode_models.dart`), not a Cast receiver.
- **To have "TV Connected" show a grid the phone controls, Aika Stream
  itself has to become a Cast receiver**, not just consume one. Google's
  supported way for a *native Android TV app* (not a generic Chromecast
  dongle) to do this is **Cast Connect**
  (`CastReceiverContext`/`androidx.mediarouter`) — the phone (sender) casts
  to the TV, and Android routes that session into the already-running Aika
  Stream app instead of a hosted web receiver page. This needs new native
  Kotlin work in `app/android` (a receiver service, manifest
  `<meta-data>` entries, a `CastReceiverOptions` registration) that doesn't
  exist today.
- **Cast Connect is Android TV / Google TV only.** It does not cover Fire TV
  (not part of that ecosystem) or a literal Chromecast dongle (those would
  need a *hosted CAF Web Receiver* — a separate web app, DRM/hosting
  overhead, a different project entirely). This spec is Android TV/Google TV
  only; Fire TV keeps local-only MultiView (D-pad, as today).
- **The multiview *engine* itself doesn't need to change.** `AiroMultiviewPool`,
  `MultiviewProvider.toggle/promote/swap`, and `MultiviewStage`'s rendering
  are already exactly what a receiver-side implementation would drive —
  the work is wiring *remote* commands into the same
  `multiviewProvider.notifier` calls the local UI already makes, not
  building a second multiview implementation.

## Scope (v1)

In scope:
- A **new "Cast" section on the phone**, separate from normal channel
  browsing — reachable from the existing Cast entry points
  (`_showWaysToWatch`/cast device picker), not replacing them. Google Cast
  discovery already exists (`AiroCastController.startDiscovery`); this adds
  a distinct UI surface once a Cast Connect–capable receiver (an Aika
  Stream Android TV/Google TV device) is selected, instead of the existing
  single-channel cast flow.
- Building a grid on the phone: pick up to the receiver's own MultiView
  capacity (`multiviewDecoderBudgetProvider` on *that* TV, reported back
  over the Cast channel — a phone must not assume its own decoder budget)
  channels into slots, using the existing channel search/favorites the
  phone app already has.
- **Named saved layouts**, stored locally on the phone (channel ids +
  arrangement only — no cloud sync in v1; see Explicitly not decided).
  "Launch" applies a saved layout to the currently connected receiver in
  one action.
- **Live per-tile remote controls** once applied: pause/resume, mute/focus
  (promote), remove — each a thin wrapper sending one command over the new
  namespace, mirrored back as an ack so the phone UI reflects the TV's
  actual state, not an optimistic guess.
- **Receiver side** (Aika Stream, Android TV/Google TV only): a
  `CastReceiverContext` registration that, on receiving a MultiView command,
  calls the exact same `multiviewProvider.notifier` methods the local UI
  calls (`toggle`, `promote`, `swap`) — no parallel receiver-only multiview
  code path.

Out of scope for this spec:
- Fire TV or literal Chromecast-dongle receivers (needs a hosted Web
  Receiver — different project, see above).
- The reference screenshots' full "8/14 layout" mosaic library (spotlight,
  primary-left+3, etc.) — Airo's `MultiviewStage` currently supports
  1/2/3/(4+ grid) only. Expanding the layout set is a separate, local-only
  UI change to `MultiviewStage` that this spec doesn't require; v1 remote
  control targets whatever arrangement the tile count already produces.
- Guide/EPG-driven channel discovery inside the Cast section (the
  screenshots show a program guide; Airo's existing channel search covers
  channel selection, no EPG integration implied here).
- Multiple simultaneous phones controlling the same TV session (v1 is one
  sender per receiver session, matching Cast's own model).

## Dependencies (blocking, not yet resolved)

1. **Cast Connect registration** — needs the Android TV/Google TV
   `CastReceiverOptions` set up in `app/android` for the `tv` variant only
   (`APP_VARIANT=tv`), and Cast Developer Console app registration for a
   receiver (not just a sender) application ID. This is an infra/account
   step, not just code.
2. **New wire protocol.** A custom Cast message namespace carrying
   MultiviewCommand messages (add/remove channel at slot, promote, swap,
   query current grid state) and MultiviewState acks. Needs a concrete
   schema (JSON shape, versioning) before either side is implemented —
   this spec deliberately does not fix that shape (see below).
3. **Product sign-off**, same as the split-view/mirror-mode specs before
   it: is a dedicated phone remote-control section worth the native Cast
   Connect investment, or does "walk over and use the TV remote" cover this
   well enough given MultiView already has D-pad long-press (#1966/#1967)?
   Not an engineering call.

## Design (once dependencies clear)

### Protocol shape (sketch, not final)
```
// Sender -> Receiver
{"type": "multiview.set_slot", "slotId": "b", "channelId": "yrf-music"}
{"type": "multiview.remove_slot", "slotId": "b"}
{"type": "multiview.promote", "slotId": "b"}
{"type": "multiview.swap", "firstSlotId": "a", "secondSlotId": "b"}
{"type": "multiview.query_state"}

// Receiver -> Sender
{"type": "multiview.state", "capacity": 4, "sessions": [
  {"slotId": "a", "channelId": "aajtak-hd", "channelName": "Aaj Tak HD", "featured": true},
  {"slotId": "b", "channelId": "yrf-music", "channelName": "YRF Music", "featured": false}
]}
```
`slotId` (not raw channel id) as the addressable unit matters: it lets the
phone reference "the tile at position B" before knowing what's in it yet
(building a layout from scratch), and lets swap/promote be phrased the same
way the local UI already does (`MultiviewController.promote(channelId)` —
the receiver adapts slot-addressed remote commands to the existing
channel-id-addressed local API).

### Receiver-side wiring
A new `CastMultiviewReceiverBridge` (or similar) in `feature_iptv`,
constructed only when `APP_VARIANT=tv` and Cast Connect is active, subscribes
to incoming namespace messages and calls
`ref.read(multiviewProvider.notifier)` the same way `AiroTvShell._toggleMultiview`
does today — translating `multiview.set_slot` into
`sessionFactory`-backed `pool.add`, etc. It also pushes `multiview.state`
whenever `MultiviewState` changes (the provider already exposes this via its
`StateNotifier` stream), so phone UI reflects reality including
capacity-reached rejections.

### Phone-side "Cast" section
A new screen (not a dialog/sheet like the existing cast picker) reachable
once a Cast Connect receiver is selected: layout builder (search existing
channel providers, assign to slot), Saved Layouts list (local storage,
same shape as `favoriteChannelsStorageProvider`'s pattern), and a live
control list once connected (subscribes to `multiview.state` acks).

### Testing
- Unit: protocol encode/decode round-trip for every message type.
- Widget: receiver bridge translates each command type into the correct
  `multiviewProvider.notifier` call, using the same fake-session pattern
  `multiview_provider_test.dart` already has.
- Widget: phone Cast section reflects `multiview.state` acks, including a
  capacity-reached rejection surfacing the same "This device supports up to
  N multiview streams" pattern the local grid uses.
- Physical device: an actual Android TV/Google TV device — Cast Connect's
  session handoff cannot be verified with fakes/widget tests, matching the
  precedent set by MultiviewStage's own physical-qualification note in
  `docs/features/airo-tv/MULTIVIEW_V1.md`.

## Explicitly not decided here

- Whether saved layouts eventually sync across the user's devices (cloud)
  or stay phone-local forever — v1 assumes local-only; revisit only if
  requested.
- Exact Cast Connect app-ID/registration ownership (who holds the Cast
  Developer Console account) — an account/ops question, not architecture.
- Whether a *second* phone can join the same TV session as a passive
  viewer of `multiview.state` without sending commands — out of scope
  until asked for.
