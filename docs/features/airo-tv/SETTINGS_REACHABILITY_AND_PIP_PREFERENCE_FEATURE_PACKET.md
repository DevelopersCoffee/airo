# Airo TV Settings Reachability and PiP Preference Feature Packet

## Critical Agent Gate

**Problem:** Pixel 9 runs the Airo TV build through the compact IPTV layout. The
TV Settings route exists, but compact layout bypasses the TV sidebar and the
mobile IPTV drawer omits Settings, so users cannot reach theme, playback,
playlist, or EPG guide settings. Playback Settings also has only aspect-ratio
controls; the historical PiP settings hook exists but no public PiP preference
is rendered.

**User / actor:** Airo TV users on Pixel 9 and other compact phone/tablet
layouts.

**Framework or application layer:** Application UI and IPTV playback preference
state. No native PiP channel changes.

**Owning agent:** Airo TV Flutter Architect.

**Reviewing agents:** Media Intelligence Architect, Playback Architect, TV
Experience Architect, Chief UX Officer, Chief QA Officer.

**Impacted modules/files:** `app/lib/core/app/tv_router.dart`,
`app/lib/features/settings/presentation/*`,
`packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart`,
`packages/feature_iptv/lib/application/player_backgrounding_coordinator.dart`,
focused tests.

**Open questions:** None. The compact Airo TV product must expose Settings from
the drawer because it has no Profile tab.

**Decision:** Ready.

## Cross-Agent Contract

**Provider agent:** Playback Architect / `feature_iptv` preference state.

**Consumer agent:** Airo TV Flutter Architect / Settings UI and backgrounding
coordinator.

**Interface/API:** `pictureInPicturePreferenceProvider`, default `true`,
persisted in shared preferences.

**Input shape:** Explicit user toggle in Playback Settings.

**Output shape:** Boolean preference controlling automatic PiP on app
backgrounding. Explicit player PiP remains available from the player control
surface.

**State changes:** Local shared-preferences key only.

**Errors:** Preference persistence failures must not crash the Settings screen.

**Permissions:** No new permissions. Existing native PiP channel remains the
only PiP execution path.

**Privacy/redaction:** No URLs, playlist contents, or channel names are logged.

**Persistence:** SharedPreferences boolean.

**Versioning/migration:** Additive preference with default enabled to preserve
current behavior.

**Tests required:** Drawer Settings callback, compact TV router Settings
reachability, SettingsHub/PlaybackSettings PiP toggle, coordinator behavior
when PiP preference is disabled.

## Deterministic Use Cases

### UC-001: Pixel 9 opens Settings from Airo TV drawer

**Actor:** Pixel 9 Airo TV user.

**Preconditions:** Airo TV is in compact portrait layout.

**Trigger:** User opens the hamburger menu and taps Settings.

**Happy path:** The Settings hub opens with Appearance, Playback Settings,
Playlist Source, and EPG Guide Source.

**Failure paths:** If the drawer is dismissed, no settings are changed.

**Data created/updated/deleted:** None.

### UC-002: User toggles automatic PiP

**Actor:** Airo TV user.

**Preconditions:** Playback Settings is open.

**Trigger:** User toggles Picture-in-picture.

**Happy path:** Preference is persisted and the backgrounding coordinator stops
arming automatic PiP when disabled.

**Failure paths:** Explicit player PiP button still uses the native PiP channel.

**Data created/updated/deleted:** SharedPreferences boolean.

## Automation Flow

### AUTO-001: Compact Settings reachability

**Given:** Compact Airo TV router or compact IPTV screen.

**When:** The user opens the drawer and taps Settings.

**Then:** SettingsHubScreen is visible.

### AUTO-002: PiP preference

**Given:** Playback Settings is rendered with shared preferences.

**When:** The user toggles Picture-in-picture off.

**Then:** The preference is false, persisted, and backgrounding falls back to
audio-only instead of requesting PiP.
