# Pixel 9 PiP Video-Only Layout Feature Packet

**Base verified:** `origin/main` at `752e554c86575dc171cd491b3168bb16a92ba95e` on 2026-07-22
**Layer:** Mixed — Airo TV mobile presentation, shared rail sizing, and its
Airo TV Android manifest declaration

## Critical Agent Gate

**Problem:** On a Pixel 9, Android PiP shrinks the complete Airo TV activity,
including the Airo TV app bar and its actions, instead of presenting only the
active video. The inline panel also spends vertical space on a redundant
"Featured Player" label and helper subtitle. On the same device, a channel
card can exceed its horizontal-rail viewport by one pixel, showing Flutter's
yellow/black overflow warning.
**User / actor:** A mobile Airo TV viewer who backgrounds a live channel into
PiP.
**Framework or application layer:** Mixed. Android already reports PiP state
through the existing `platform_player` contract; `feature_iptv` decides which
surface is rendered for that state, `core_ui` derives the bounded rail height
from its card geometry, and the Airo TV Android manifest declares that its
activity can enter PiP on a phone.
**Owning agent:** Flutter Architect.
**Reviewing agents:** Platform Architect, Playback Architect, Chief QA Officer,
Chief UX Officer.
**Impacted modules/files:** `feature_iptv` player screen, player widget callback
ownership, screen widget test; `core_ui` rail-card sizing and tests; `app` Airo
TV manifest; and this feature packet.
**Base branch/worktree:** yes — task worktree `codex/pixel9-pip-player-layout`
equals fetched `origin/main`.
**Open questions:** None. PiP keeps the existing `VideoPlayerWidget` controls;
it does not alter playback, entitlements, persistence, or Android platform
configuration.
**Decision:** Ready.

## Cross-Agent Contract

**Provider agent:** Playback Architect (`platform_player`), Flutter Architect
(`core_ui` rail geometry), and Platform Architect (`app` Android manifest)
**Consumer agent:** Flutter Architect (`feature_iptv`)
**Interface/API:** Existing
`AiroNativePictureInPicture.setStateChangeHandler(bool isActive)` callback.
**Input shape:** `true` when Android enters PiP and `false` when it exits.
**Output shape:** The active `IPTVScreen` renders a video-only scaffold while
the value is `true`.
**State changes:** Ephemeral screen-local presentation state only.
**Errors:** Missing or unsupported platform callbacks retain the normal browse
screen; playback remains unchanged.
**Permissions:** No new runtime permission. The Airo TV activity declares its
existing PiP capability in the Android manifest.
**Privacy/redaction:** No data is read, persisted, or transmitted.
**Persistence:** None.
**Versioning/migration:** None; the existing platform callback is unchanged.
**Tests required:** Widget tests for removal of redundant labels and for the
PiP callback hiding the app bar while retaining the player; a Pixel 9 build
smoke test confirms the Airo TV package is installed and launched; a shared
rail test verifies a real channel card fits without a layout exception.

## Deterministic Use Cases

### UC-001: Enter PiP during live playback

**Actor:** Pixel 9 viewer.
**Preconditions:** A live channel is playing in the inline mobile player.
**Trigger:** Android enters PiP after the viewer leaves the app.
**Happy path:** The screen switches to the video-only player; the Airo TV app
bar and its actions are absent from the PiP window.
**Alternate paths:** Exiting PiP restores the normal browse screen.
**Failure paths:** A host without the PiP callback continues to show the
normal browse screen without interrupting playback.
**Data created/updated/deleted:** None.
**Privacy expectations:** No viewing or channel data changes.

### UC-002: Browse with a configured playlist

**Actor:** Mobile Airo TV viewer.
**Preconditions:** At least one channel is available.
**Trigger:** Viewer opens Airo TV outside PiP.
**Happy path:** The inline player appears without the "Featured Player" title
or "Play media from your saved playlist." helper text; the channel-selection
guidance and playback controls remain available.
**Failure paths:** Loading and empty playlist states are unchanged.

### UC-003: Render a channel rail at Pixel 9 density

**Actor:** Mobile Airo TV viewer.
**Preconditions:** A browse rail contains a standard channel card with a name
and subtitle.
**Trigger:** The card is laid out inside its derived horizontal-rail viewport.
**Happy path:** The rail has enough cross-axis space for the full card, with no
yellow/black overflow indicator.
**Failure paths:** Long title/subtitle text remains ellipsized rather than
expanding the card.

## Automation Flow

### AUTO-001: Video-only PiP presentation (host-only)

**Given:** A widget test renders `IPTVScreen` with a deterministic channel and
streaming-state fixture.
**When:** The existing PiP state callback reports `true`, then `false`.
**Then:** PiP removes the app-bar title/actions and retains the player; exit
restores the normal screen. The normal screen contains neither removed panel
label, and a real channel card fits the derived rail height without a layout
exception.
**Fixtures:** Existing `IPTVScreen` channel and streaming-state provider
overrides.
**Mocks/stubs:** `AiroNativePictureInPicture.debugNotifyStateChanged`.
**Assertions:** Text and widget presence/absence only; no network or device
emulator is required.
**Cleanup:** Reset the PiP callback after each test.
