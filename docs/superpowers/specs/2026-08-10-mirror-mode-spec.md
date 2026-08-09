# Spec: Mirror mode — same channel on phone and TV (#1048)

## Objective

#1047's spec (`2026-08-10-split-view-cast-and-watch-spec.md`) covers "cast
channel A, watch channel B locally" — two independent channels. #1048 is a
different problem: the *same* channel playing simultaneously on the phone
and the cast target, staying in sync (play/pause/seek/volume) as the user
controls either side.

**User:** someone casting a channel to the TV who wants to keep controlling
playback from their phone (e.g. pause from the couch) without the two
screens drifting out of sync.

**Success:** pausing on either device pauses both within a perceptible
delay; seeking on either device moves both; there is one authoritative
state, not two independently-drifting ones.

## Relationship to #1047

Both need the same foundational piece: local playback must be able to run
independently of `_syncLocalPlaybackWithCast`'s current unconditional
pause-on-cast behavior (`packages/feature_iptv/lib/presentation/screens/iptv_screen.dart:760-774`,
1330-1342). #1047 needs that pause removed so two *different* channels can
both play. #1048 needs it replaced with something that keeps the *same*
channel synchronized rather than either playing independently or one side
being paused. Implement #1047's decoupling first — #1048 builds on it, it
doesn't duplicate it.

## Scope

In scope:
- Bidirectional playback-state sync for one channel across exactly two
  targets (phone + one cast device). N-target sync is out of scope.
- Conflict resolution when both sides act near-simultaneously (e.g. user
  pauses on phone the instant the TV starts buffering).

Out of scope:
- More than two sync targets.
- Syncing across two *different* local devices not connected via the
  existing `AiroCastController` (e.g. two phones) — this spec assumes one
  side is always the existing Chromecast integration.

## Open questions (blocking — need a decision before implementation)

Unlike #1047, this isn't just "remove an unconditional pause" — it needs a
sync protocol and an ownership rule that don't exist yet, and both are
product/design decisions, not just engineering:

1. **Authority.** When phone and TV disagree (phone says paused, TV says
   playing — e.g. because the TV buffered and auto-paused independently),
   which one wins? A "last write wins" clock-based rule is the simplest
   engineering answer but can fight the user (e.g. TV auto-pauses on
   buffer, then immediately gets overridden by a stale "playing" state from
   the phone). Needs an explicit rule, not an implicit one.
2. **Transport.** `AiroCastController`'s existing session already carries
   play/pause/seek commands one-directional (phone → TV, via
   `iptv_cast_providers.dart`). Mirror mode needs the reverse direction too
   (TV state changes reflected back to the phone's local player) — does the
   Chromecast session protocol support that natively (cast receiver → sender
   state callbacks), or does this need a new channel? Needs a spike against
   the actual `flutter_chrome_cast` (`packages/platform_player/third_party/flutter_chrome_cast/`)
   API surface before committing to a design — this spec does not answer
   it because it requires reading that third-party package's actual
   capabilities, not assuming them.
3. **Resource cost.** Same admission-control dependency as #1047 (#829
   follow-up) — a second local decoder running the same stream still costs
   a decoder and network fetch, even if perfectly synced.
4. **Drift tolerance.** How far out of sync is acceptable before
   correcting (a hard re-seek is jarring; too loose and "mirror" doesn't
   feel real)? Needs a product-defined tolerance, not an engineering
   default.

## Recommended next step

Not a design doc — a short technical spike against
`flutter_chrome_cast`'s actual receiver-state-callback API (open question
2) to learn what's possible before writing the sync design, since the
transport answer shapes everything else here (authority model, drift
correction all depend on what state updates are actually available and how
fast). Once that spike answers question 2, this spec should be revised with
a concrete protocol design before implementation starts.
