# Channel Info Favorite Action Feature Packet

## Feature Packet

**Primary owner agent:** Media Intelligence Architect
**Review agents:** Airo TV Flutter Architect, Chief UX Officer, Chief QA Officer
**Layer:** Application presentation using the existing local favorites contract.
**Sprint:** Airo TV phone discovery follow-up
**Parent roadmap:** Airo TV v2 release qualification

### Critical Agent Gate

**Problem:** The favorite heart in the compact Airo TV channel information bar
is tappable but has an empty callback. It gives no state change, visual
feedback, or path into the existing Favorites screen.

**User / actor:** Airo TV user watching a selected live channel.

**Framework or application layer:** Application UI only. The existing
`platform_favorites` local storage and `feature_iptv` favorite providers are
unchanged.

**Owning agent:** Media Intelligence Architect (`feature_iptv`).

**Reviewing agents:** Airo TV Flutter Architect (Riverpod/widget structure),
Chief UX Officer (clear interactive state), Chief QA Officer (regression).

**Impacted modules/files:** `ChannelInfoBar`, focused widget test, and this
feature packet.

**Base branch/worktree:** Yes — the current task worktree is based on fetched
`origin/main` at `5b61c8bb`.

**Open questions:** None. The expected behavior is the same local-only toggle
already used by the dedicated TV and Favorites surfaces.

**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** `feature_iptv` favorite providers backed by
`platform_favorites`.
**Consumer agent:** Compact `ChannelInfoBar`.
**Interface/API:** `isChannelFavoriteProvider(channelId)` and
`channelFavoriteTogglerProvider(channelId)`.
**Input shape:** Selected `IPTVChannel.id` and an explicit user tap.
**Output shape:** Persisted local favorite state and a boolean new state.
**State changes:** Toggle the selected channel id only; provider invalidation
refreshes the icon.
**Errors:** Existing preference errors leave the interaction non-destructive;
the compact UI does not claim success until the toggle completes.
**Permissions:** None.
**Privacy/redaction:** Channel ids remain in existing local preferences only.
**Persistence:** Existing `FavoriteChannelsStorage` key only.
**Versioning/migration:** None.
**Tests required:** Tap adds/removes the id, flips the filled/outlined heart,
and renders disabled when no channel is selected.

### Deterministic Use Cases

#### UC-001: Favorite the active channel

**Actor:** Airo TV user.
**Preconditions:** A selected channel is not favorited.
**Trigger:** Tap Favorite in the channel info bar.
**Happy path:** The channel id is locally saved, the heart becomes filled, and
feedback says it was added.
**Failure path:** No selected channel leaves the control disabled and writes
nothing.
**Data created/updated/deleted:** One existing favorites-list entry is added
or removed.
**Privacy expectations:** The channel id stays local.

### Automation Flow

#### AUTO-001: Compact favorite toggle regression

**Environment:** Host-only Flutter widget test.
**Given:** In-memory shared preferences and an active channel.
**When:** The user taps the heart twice.
**Then:** The first tap persists the id and fills the heart; the second removes
it and restores the outlined heart.
**Fixtures:** One deterministic `IPTVChannel`.
**Mocks/stubs:** Existing shared-preferences override only.
**Assertions:** Persisted set, icon, tooltip, and no-channel disabled state.
**Cleanup:** Widget/provider teardown disposes the test scope.

### Implementation Boundaries

- **Framework files:** None.
- **Application files:** `feature_iptv` compact channel information widget.
- **Tests:** New focused `ChannelInfoBar` widget test.
- **Docs:** This feature packet only.
- **Verification environment:** Host-only focused test, analyzer, and
  `git diff --check`; no remote CI.
