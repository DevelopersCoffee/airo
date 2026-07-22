# Airo TV Player Control Surface Parity Feature Packet

## Critical Agent Gate

**Problem:** The compact Airo TV phone/player path lacks visible controls that users expect from the previous TV Explorer-style surface: subtitle Off/track control, visible phone volume and channel controls, DVR rewind, explicit PiP, quality selection, and removal or implementation of no-op action buttons.

**User / actor:** Airo TV users on Pixel 9, phones/tablets, macOS, and TV devices browsing IPTV channels.

**Framework or application layer:** Mixed. `platform_player` and `platform_media` own playback state/track selection contracts. `feature_iptv` owns Airo TV product UI and IPTV workflow wiring.

**Owning agent:** Media Intelligence Architect.

**Reviewing agents:** Playback Architect, Flutter Architect, TV Experience Architect, Chief UX Officer, Chief QA Officer, Chief Performance Officer.

**Impacted modules/files:** `packages/platform_player`, `packages/platform_media`, `packages/feature_iptv`, focused widget/service tests.

**Base branch/worktree:** Existing worktree `codex/remove-legacy-product-targets`, originally based on `origin/main` for the active Airo TV consolidation slice.

**Open questions:** None blocking. Share is implemented as a clipboard copy because `feature_iptv` does not own a share dependency; Like/Ways-to-watch are removed until backed by a real contract.

**Decision:** Ready.

## Cross-Agent Contract

**Provider agent:** Playback Architect / Platform Architect.

**Consumer agent:** Media Intelligence Architect / Flutter Architect.

**Interface/API:** `AiroPlaybackEngine.clearTrackSelection(kind)` and `VideoPlayerStreamingService.clearTrackSelection(kind)`.

**Input shape:** `AiroPlaybackTrackKind` identifying subtitle/audio/video track selection to clear.

**Output shape:** Updated playback/streaming state where `selectedTrackIds` no longer contains the requested kind.

**State changes:** Only selected track metadata changes. Playback should continue.

**Errors:** Unsupported engines return typed unsupported state; the streaming service treats unsupported/failed clear as a no-op for callers.

**Permissions:** Explicit PiP uses the existing native PiP channel. Clipboard share uses Flutter clipboard only after a user tap.

**Privacy/redaction:** Share copies a user-visible channel title and stream URL. No hidden credentials are logged.

**Persistence:** No new persistence.

**Versioning/migration:** Additive method on internal playback engine contract; all implementations in repo are updated in the same slice.

**Tests required:** Platform player fake engine, platform media streaming service, Airo TV player widget controls, channel info bar no-op removal/copy share.

## Deterministic Use Cases

### UC-001: Captions Off

**Actor:** Phone Airo TV user.

**Preconditions:** Current stream exposes subtitle tracks.

**Trigger:** User opens subtitle controls and taps Off.

**Happy path:** Subtitle selection is cleared and playback continues.

**Failure paths:** If the engine cannot clear a track, the UI does not crash.

**Data created/updated/deleted:** In-memory selected track id removed.

**Privacy expectations:** No subtitle URL or stream URL is logged.

### UC-002: Visible Phone Controls

**Actor:** Pixel 9 Airo TV user.

**Preconditions:** A channel is playing in the compact shell.

**Trigger:** User taps visible volume up/down, channel up/down, rewind, PiP, quality, or subtitle controls.

**Happy path:** Buttons call existing service/native actions and disabled states are visible when a stream lacks DVR or options.

**Failure paths:** Unsupported PiP or missing quality/track options shows no crash and no dead button.

**Data created/updated/deleted:** Playback state only.

**Privacy expectations:** No hidden network/model/tool behavior.

### UC-003: No Dead Action Buttons

**Actor:** Airo TV browser user.

**Preconditions:** A channel is selected.

**Trigger:** User sees the channel info bar.

**Happy path:** Favorite still works, Share copies channel details, and unsupported Like/Ways-to-watch buttons are absent.

**Failure paths:** Clipboard failure shows a bounded snackbar error.

**Data created/updated/deleted:** Clipboard text only after user tap.

**Privacy expectations:** User-visible channel details only.

## Automation Flow

### AUTO-001: Player Control Widget Tests

**Given:** `VideoPlayerWidget` with a fake playback engine and a playing channel.

**When:** Tests tap subtitle Off, quality option, volume/channel controls, rewind, and PiP button.

**Then:** Service/engine state updates or injected callbacks record the expected action.

**Fixtures:** Fake playback engine, mock shared preferences, small IPTV channel list.

**Mocks/stubs:** Fake engine and method-channel PiP mock where needed.

**Assertions:** No no-op buttons remain; real controls invoke real contracts.

**Cleanup:** Stop/dispose streaming service before test exit.

### AUTO-002: Physical Pixel 9 Smoke

**Given:** Pixel 9 connected over ADB.

**When:** Build and install Airo TV, open compact portrait player, play a test channel.

**Then:** New controls are visible and tappable; unsupported options are disabled rather than dead.

**Fixtures:** User-provided playlist/guide already on the device.

**Mocks/stubs:** None.

**Assertions:** Screenshot/manual result recorded in final report.

**Cleanup:** Leave installed debug app intact unless user asks otherwise.

## Implementation Boundaries

- Framework files: `packages/platform_player`, `packages/platform_media`.
- Application files: `packages/feature_iptv`.
- Tests: Focused playback engine, streaming service, widget, and info-bar tests.
- Docs: This feature packet.
- Verification environment: Host Flutter tests first, then Pixel 9 physical device build/run.
