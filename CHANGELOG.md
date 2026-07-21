# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for public release tags.

## [Airo TV v0.0.4] - 2026-07-22

### Added

- Local, deterministic search across imported channels and available guide data, including live TV search results.
- Smart-playlist rules and persistent canonical channel identities to keep personal lists resilient across re-imports.
- A bring-your-own XMLTV source flow, guide timeline improvements, favorites, captions, VOD resume/seek, and provider add-flows for Xtream, Stalker, and Jellyfin.
- Aggregate M3U import counters for parsed, skipped, malformed, and elapsed values, processed through the existing Rust/worker parser boundary.

### Changed

- Airo TV uses a virtualized, paged playlist path for large user-provided playlists and a unified browse experience across TV and compact layouts.
- Playback diagnostics and bounded retries now explain unavailable streams more clearly while keeping playlist credentials out of diagnostics.

### Fixed

- A channel is added to Recently Watched only after playback starts.
- Favorites are discoverable from browse cards and the player, and the Guide's source action leads to a working XMLTV setup flow.
- System picture-in-picture renders a video-only surface and restores the full interface when it closes.

### Known limitations

- Airo TV remains BYOC: it does not bundle playlists, channels, subscriptions, or media content.
- Android TV/Google TV artifact verification is recorded with the release; Fire TV remains compatible/experimental pending dedicated device evidence.
- Phone-hosted media streaming and its real-device receiver matrix remain under qualification.
- macOS artifacts are unsigned and not notarized; they are release evidence, not a notarized macOS distribution.

## [Airo TV v0.0.4-rc.3] - 2026-07-19

### Added

- Favorite marking: long-press any browse card to add/remove a favorite, with snackbar feedback (#935).
- "Recently Watched" browse rail, recency-ordered, hidden until there is watch history (#934).
- "Entertainment" and "Music" browse rails so every former category chip is represented as a card rail (#936).
- Search sheet now lists matching channels live as you type; tapping a result plays it. Keyboard submit applies the filter instead of auto-playing the single match (#928).

### Changed

- Top category chip row (All/News/Sports/Entertainment/Music) removed from the mobile IPTV screen; category browsing lives in the rails (#936).
- Mobile IPTV app bar title rebranded from "Stream" to "Airo TV" (#931).
- Phone-sized TV builds now open the mobile settings hub (theme picker, audio/playback links) instead of the clipped two-pane TV settings screen (#933).

### Fixed

- Casting regression on phones running the TV build: `realIptvCastControllerOverride()` restored in the TV entrypoint — compact layouts render the mobile IPTV screen whose cast UI silently no-oped against the unavailable-controller fallback (#926).
- EPG guide timeline always appeared to start at 11 AM in IST: the time ruler formatted UTC directly; ticks now convert to local time (#929).
- Display slept during playback: wakelock ownership moved from `VideoPlayerWidget` (disposed when the featured player scrolls off-screen or playback continues under the mini player) to a screen-scoped, debounced `WakelockPlaybackCoordinator` (#930).
- Favorite toggle silently no-oped on every second toggle of the same channel: cached `FutureProvider.family` replaced with a plain callable provider (#935).

### Known issues

- Deferred to next cycle: portrait/landscape floating player-control inconsistency, idle featured-player placeholder (should use full asset area), picture-in-picture, playlist management.
- Casting and wakelock fixes are test-verified; on-device Pixel 9 dogfood pending this RC.
- Two pre-existing `firebase_options_test.dart` failures in `test-app` remain tracked from rc.2 (the settings hub sheet-title failure was fixed in #932).

## [Airo TV v0.0.4-rc.2] - 2026-07-19

### Added

- Unified Netflix-style browse experience across phone/tablet/TV/desktop.
- CV-017 canonical channel identity matching (Drift/SQLite) plus favorite reimport review banners (mobile + TV).
- TV player gesture gating: touch-only affordances (swipe-channel, tap gestures) now hidden on TV builds.

### Changed

- Removed dead cast controller override from TV entrypoint; unused `AdaptiveIptvUI` and `ImportPipeline` deleted (zero consumers).
- `AiroRail.railHeight` now derives from `MediaCardVariant` instead of a hardcoded value.
- Airo TV pubspec bumped to `0.0.4-rc.2+5`.

### Fixed

- `sqlite3_flutter_libs` version conflict between `airo_app` and `platform_playlist` that broke `pub get` repo-wide (lint/analyze/snyk/variant-dependencies CI jobs). App no longer pins its own version; `platform_playlist` owns the constraint and its `sqlite3` core-package range was widened to admit the 3.x line `drift_dev` needs.
- Five files committed with incorrect `dart format` output, failing the CI format-check step.
- `feature_iptv` EPG compact-view test (`renders compact current EPG from platform repository`) failed at the default test viewport because the hero+rails layout left the EPG-aware channel grid/list no room to lazily build any items — not a rendering bug, just insufficient test viewport height. Fixed by giving that test a taller surface.

### Known issues

- Three pre-existing `test-app` failures, unmasked by the sqlite3 dependency fix above (this job was `skipped` on every recent CI run because earlier jobs failed first, so these were never actually exercised until now): `firebase_options_test.dart` (`marks real Firebase app ids as configured`, `uses the registered Android TV Firebase app id`) and `settings_hub_screen_test.dart` (`tapping Playlist Source opens the playlist source sheet`). Not caused by this release's changes — tracked for follow-up.

## [Airo TV v0.0.4-rc.1] - 2026-07-19

### Added

- Structured playback diagnostics taxonomy with bounded retry state machine and in-player diagnostic surface (CV-001).
- Provider health tracker wired to Xtream/Stalker/Jellyfin adapters, with add-flow UI in provider management (CV-012, CV-032).
- Local IPTV search index over channels + EPG, live-provider wiring, and TV search results panel (CV-006).
- Persisted caption preference (CV-008) and external-subtitle track catalog projection (CV-016).
- VOD seek bar with drag-to-seek (CV-016).
- Hidden-groups favorites storage and wiring into local search (CV-021).
- Smart playlist rule model + evaluator (CV-017 slice 1).
- Phone-hosted LAN media streaming debug entry point for storage-limited receivers (CV-033).
- Airo TV design-system revamp: spacing rhythm, typography hierarchy, theme picker.
- Release device-qualification workflow and release-artifact smoke tests.

### Changed

- `feature_iptv` playback now routed through `AiroPlaybackEngine` (CV-016/CV-031).
- TV source management screen polish and cleanup (CV-022-nit).
- Airo TV pubspec bumped to `0.0.4-rc.1+4`.

### Fixed

- Phone-media LAN server no longer torn down while the receiver is paused.

## [Airo TV v0.0.2] - 2026-07-14

### Added

- Professional Airo TV release-note template.
- SHA256 checksum publishing for Airo TV release assets.
- Privacy policy, threat model, roadmap, architecture overview, feature matrix, and media asset checklist.
- README trust section for Airo and Airo TV.

### Changed

- Airo TV release assets use clean user-facing names.
- Airo TV release notes now follow a mature open-source format.
- Airo TV version updated to `0.0.2+2`.

### Fixed

- Broken or misleading Airo TV download links that pointed to generic release assets.

## [Airo TV v0.0.1] - 2026-07-14

### Added

- Initial Airo TV release from the v2 release line.
- Android TV package `io.airo.app.tv`.
- IPTV playlist import, search, playback, Cast controls, and Play Store readiness notes.

[Airo TV v0.0.4-rc.1]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.3...airo-tv-v0.0.4-rc.1
[Airo TV v0.0.4]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.3...airo-tv-v0.0.4
[Airo TV v0.0.2]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.1...airo-tv-v0.0.2
[Airo TV v0.0.1]: https://github.com/DevelopersCoffee/airo/releases/tag/airo-tv-v0.0.1
