# Legacy Product Target Consolidation Feature Packet

## Feature Packet

**Primary owner agent:** Airo TV Flutter Architect
**Review agents:** Media Intelligence Architect, Platform Architect, Chief QA Officer, Chief Release/DevOps Officer, Chief Documentation Officer
**Layer:** Mixed — product launch configuration and release tooling; no shared IPTV/media implementation changes
**Sprint:** Product-target consolidation
**Parent roadmap:** Airo TV v2 release qualification

### Critical Agent Gate

**Problem:** The redundant music/IPTV launcher opens the same Airo login shell as the full app and has no distinct product surface. The standalone debug launcher has no unique behavior outside the Airo TV product path. Keeping either launcher creates redundant package IDs, Firebase clients, release profiles, scripts, documentation, and qualification requirements.

**User / actor:** Release engineers and users installing Airo products.

**Framework or application layer:** Mixed. `feature_iptv`, platform packages, and adapters stay shared framework/domain code; only product entrypoints and release/build wiring change.

**Owning agent:** Airo TV Flutter Architect.

**Reviewing agents:** Media Intelligence Architect (IPTV behavior parity), Platform Architect (device/package wiring), Chief QA Officer (deterministic validation), Chief Release/DevOps Officer (matrix/preflights), Chief Documentation Officer (product documentation).

**Impacted modules/files:** `app/` entrypoints and Android variant mapping; build-profile/release-matrix/Firebase preflight tooling; target-specific scripts; product/release documentation and focused tests.

**Base branch/worktree:** Yes — `codex/remove-legacy-product-targets` is based directly on fetched `origin/main` at `d46dbade`.

**Open questions:** None. Pixel 9 is supported by Airo TV: `configureTvSystemChrome` leaves orientation unrestricted unless the detected form factor is a TV. The standalone debug launcher is removed in this change because parity is established below.

**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Airo TV Flutter Architect / Media Intelligence Architect
**Consumer agent:** Release and DevOps tooling
**Interface/API:** Kept entrypoints and release profiles
**Input shape:** `APP_VARIANT=full` or `APP_VARIANT=tv`; Airo TV uses `APP_PLATFORM=androidTv`.
**Output shape:** Only `io.airo.app` / `Airo` and `io.airo.app.tv` / `Airo TV` are product Android package targets.
**State changes:** Remove legacy product package/client/profile identifiers; no user media, playlist, guide, history, or account state is migrated or deleted.
**Errors:** A removed legacy profile is rejected as unknown by the release/profile tools.
**Permissions:** No new permissions or native APIs.
**Privacy/redaction:** No data collection or handling change.
**Persistence:** Existing IPTV settings remain owned by shared providers and are consumed by Airo TV.
**Versioning/migration:** Product target removal only; existing retired-package installs are not upgraded in place because Android package IDs differ. Distribution documentation must not advertise them.
**Tests required:** Build-profile contract, `core_release` matrix/Firebase/preflight tests, Airo TV startup orientation and debug-source tests, and debug APK builds for full and TV targets.

### Deterministic Use Cases

#### UC-001: Full Airo product remains buildable

**Actor:** Release engineer
**Preconditions:** Checkout contains the consolidated product configuration.
**Trigger:** Build `app/lib/main.dart` with `APP_VARIANT=full`.
**Happy path:** Android package label and ID resolve to Airo / `io.airo.app`.
**Failure paths:** A removed IPTV or Streaming variant cannot be selected from a supported release profile.
**Data created/updated/deleted:** Build artifacts only.
**Privacy expectations:** No user data.

#### UC-002: Airo TV remains the IPTV product on phone and TV

**Actor:** Airo TV user
**Preconditions:** Airo TV starts with shared IPTV providers.
**Trigger:** Launch `app/lib/main_tv.dart` on a phone or a TV.
**Happy path:** Phone/tablet orientation remains unrestricted and uses the compact IPTV route; physical TV stays landscape and remote-first. Playlist source, XMLTV guide source, playback, Cast sender, macOS layout, TV remote layout, and diagnostics remain supplied by shared `feature_iptv` and platform packages.
**Failure paths:** Firebase or optional media-session initialization failure does not prevent Airo TV from starting.
**Data created/updated/deleted:** Existing playlist/guide preferences only; no migration.
**Privacy expectations:** Existing source and Firebase behavior is unchanged.

### Automation Flow

#### AUTO-001: Product target contract

**Given:** The release matrix, build profile manifest, Android mapping, Firebase preflight, and target scripts.
**When:** Focused profile and `core_release` tests run.
**Then:** Only full Airo and Airo TV are accepted Android product targets; legacy IPTV/Streaming package/client/profile expectations are absent.
**Fixtures:** Existing release matrix and Firebase fixture sources, reduced to kept targets.
**Mocks/stubs:** Existing test fixtures only.
**Assertions:** No legacy target ID/entrypoint/pubspec/script remains in active product/build/release wiring; full and TV debug builds succeed.
**Cleanup:** Delete generated build artifacts only through Flutter's normal build output lifecycle.

### Implementation Boundaries

- **Framework files:** Release matrix, profile validation, Firebase/preflight tooling.
- **Application files:** App entrypoints, Android variant mapping, product docs.
- **Tests:** Existing focused release and Airo TV tests.
- **Docs:** Product/release matrix, Firebase and publishing guidance; historical records may retain dated references.
- **Verification environment:** Host-only local validation and local Android APK builds; no emulator and no remote CI.

## Parity Evidence

| Legacy behavior | Airo TV owner | Evidence |
| --- | --- | --- |
| Playlist source and debug playlist seeding | `feature_iptv` + `main_tv.dart` | `seedTvDebugDefaultPlaylist` |
| XMLTV guide source | `feature_iptv` + `main_tv.dart` | `scheduleTvXmltvSourceRefresh` |
| Playback and Cast sender | `feature_iptv` + platform player | `realIptvCastControllerOverride` |
| Phone/tablet compact layout | Airo TV router | `tv_router.dart` falls back to `IPTVScreen` |
| macOS and physical-TV layouts | Airo TV app/router | shared Airo TV shell and device-form-factor routing |
| TV remote layout | Airo TV + `feature_iptv` | TV router, remote-control packages, and existing tests |
| Diagnostics and optional media session | Airo TV startup | `main_tv.dart` startup/error handling and TV media session integration |

The former Streaming launcher only registered `IptvFeatureModule` and
`MusicFeatureModule` before running the normal `AiroApp`; it introduces no
unique product behavior to migrate.
