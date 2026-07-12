# IPTV Play Store V2 Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent, Mobile UI Agent
**Layer:** Mixed
**Sprint:** V2 Play Store readiness
**Parent roadmap:** IPTV Google Play compliance

## Critical Agent Gate

**Problem:** The IPTV experience must qualify as a generic, bring-your-own-content media player for Google Play review and must not ship, auto-fetch, or hint at first-party channel lineups.
**User / actor:** Android mobile or TV user who owns or is authorized to use an M3U playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent for playlist loading contracts, Security and Privacy Agent for network and content posture, QA Automation Agent for deterministic checks, Release and DevEx Agent for Android release readiness, Mobile UI Agent for BYOC entry UX.
**Impacted modules/files:** `packages/platform_channels`, `packages/platform_playlist_import`, `packages/feature_iptv`, `app/android`, app pubspec variants, release documentation.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes. V2 work belongs on the modular base branch `origin/v2`, not `origin/main`.
**Open questions:** Final Google Play app access credentials and store screenshots remain a release-console task.
**Decision:** Ready.

## Agent Reference

Implementation agents must use the existing BYOC playlist path:
`M3UParserService.fetchPlaylist`, `setPlaylistUrl`, `getPlaylistUrl`, and
`clearPlaylist`. Do not introduce a second IPTV source registry, default
playlist provider, bundled JSON fallback, remote first-party lineup, or
reviewer-specific branch. The existing `ChannelDataService` is intentionally
legacy-empty for Play Store V2 and should only clear old first-party caches.

## Cross-Agent Contract

**Provider agent:** Framework Agent.
**Consumer agent:** Media Agent.
**Interface/API:** `M3UParserService.fetchPlaylist`, `setPlaylistUrl`, `getPlaylistUrl`, `clearPlaylist`.
**Input shape:** User-entered HTTP(S) URL string.
**Output shape:** Parsed `List<IPTVChannel>` or an empty list when no user source is configured.
**State changes:** Stores only the user playlist URL and parsed playlist cache in `SharedPreferences`.
**Errors:** Empty or non-HTTP(S) playlist URLs are rejected before fetch; network failures can fall back only to a user-derived cache.
**Permissions:** Internet only for IPTV playback and playlist fetch. No broad storage permission.
**Privacy/redaction:** Playlist URL is user data; no bundled source, no first-party remote source, no reviewer-specific branching.
**Persistence:** User URL, playlist cache, cache timestamp, and recently watched history are local app data.
**Versioning/migration:** Legacy bundled/remote channel caches are ignored by the v2 data path.
**Tests required:** Parser URL validation/persistence, no-content default, feature UI empty state, Android config/package asset scan, and standalone package boundary tests for `feature_iptv` plus IPTV platform packages.

## Deterministic Use Cases

### UC-001: Fresh install has no channels
**Actor:** Google Play reviewer or first-time user.
**Preconditions:** No playlist URL saved.
**Trigger:** Open Stream.
**Happy path:** App shows a media-player setup state asking for a playlist URL and does not display live channels.
**Alternate paths:** User can open the playlist source sheet from the app bar.
**Failure paths:** None; no remote playlist is fetched automatically.
**Data created/updated/deleted:** None.
**Privacy expectations:** No content source is bundled, fetched, or inferred.

### UC-002: User adds authorized playlist
**Actor:** User with rights to access a playlist.
**Preconditions:** User has an HTTP(S) M3U URL.
**Trigger:** Enter URL and save.
**Happy path:** URL is stored locally, playlist is fetched, channels are parsed, and playback can start.
**Alternate paths:** Refresh reloads the user source.
**Failure paths:** Invalid URL is rejected; network failure leaves the existing user-derived cache if available.
**Data created/updated/deleted:** Playlist URL and parsed cache are updated locally.
**Privacy expectations:** No playlist URL is sent to any service except the user-specified host.

## Automation Flow

### AUTO-001: BYOC startup
**Given:** Mock shared preferences without a playlist URL.
**When:** IPTV providers load channels.
**Then:** `iptvChannelsProvider` resolves to an empty list.
**Fixtures:** Empty preferences.
**Mocks/stubs:** No network call required.
**Assertions:** Empty channel list and no exception.
**Cleanup:** Reset mock preferences.

### AUTO-002: Playlist URL validation
**Given:** Mock shared preferences.
**When:** `setPlaylistUrl` receives an empty URL, `file://` URL, or valid HTTPS URL.
**Then:** Invalid URLs throw `ArgumentError`; HTTPS URL is persisted and cache is cleared.
**Fixtures:** URL strings.
**Mocks/stubs:** No network call required.
**Assertions:** Stored URL matches expected value.
**Cleanup:** Reset mock preferences.

### AUTO-003: Packaged content scan
**Given:** App pubspec variants and Android network security config.
**When:** Static verification runs.
**Then:** IPTV channel JSON assets and hardcoded provider allowlists are absent from packaged app config.
**Fixtures:** Repository files.
**Mocks/stubs:** Host-only shell checks.
**Assertions:** No `assets/iptv_channels*.json` entries and no first-party IPTV source URLs in runtime Dart/Android config.
**Cleanup:** None.

### AUTO-004: Platform package boundary check
**Given:** `platform_channels`, `platform_playlist_import`, `platform_player`, `platform_media`, `platform_streams`, `platform_history`, and `feature_iptv`.
**When:** `flutter test` runs inside each package.
**Then:** The packages compile and validate BYOC behavior without depending on bundled channels or app-only `core/` / `shared/` imports.
**Fixtures:** Package tests and local framework abstractions.
**Mocks/stubs:** Mock shared preferences and package-local adapter defaults.
**Assertions:** Platform package tests and standalone `feature_iptv` tests pass.
**Cleanup:** None.

### AUTO-005: Runtime adapter override
**Given:** `feature_iptv` defaults to package-local adapters for navigation, Cast, TV input, voice search, and placeholder UI.
**When:** A consuming app needs platform-specific behavior.
**Then:** The app overrides Riverpod providers such as `airoCastControllerProvider`, `iptvNavigationTabProvider`, `voiceSearchServiceProvider`, and TV mode providers at runtime without changing framework package code.
**Fixtures:** Fake Cast controller tests.
**Mocks/stubs:** `FakeAiroCastController` and `UnavailableAiroCastController`.
**Assertions:** Consumers can switch implementations by provider override while the package remains standalone.
**Cleanup:** None.

## Implementation Boundaries

- Framework files: `packages/platform_channels`, `packages/platform_playlist_import`, `packages/platform_player`, `packages/platform_media`, `packages/platform_streams`, `packages/platform_history`.
- Application files: `packages/feature_iptv`, app pubspec variants.
- Tests: platform package Flutter tests, standalone `feature_iptv` Flutter tests, package analysis, and host-only static scans.
- Docs: this feature packet plus release note updates if needed.
- Verification environment: host-only Flutter/package tests. Android device build remains release validation.
